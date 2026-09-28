shader_type spatial;
// Superfície do mar da baía: água clara e calma, vista contra o fundo real
// (leito_mar.gdshader). A espessura de água entre a superfície e o fundo, lida do
// buffer de profundidade, decide a cor: a luz que volta do fundo perde primeiro o
// vermelho, depois o azul (água esverdeada de baía rasa), e o resto vira a cor da
// água funda. Assim o degradê areia → jade → turquesa → azul da foto sai da
// profundidade da carta, não de uma faixa pintada.

render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D profundidade : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D ondas_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ondas_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

uniform float metros_por_unidade = 4.0;
// Absorção por metro (vermelho, verde, azul) e cor da água funda.
uniform vec3 absorcao = vec3(0.5, 0.15, 0.32);
uniform vec3 cor_funda : source_color = vec3(0.09, 0.33, 0.38);
uniform vec3 tinta_rasa : source_color = vec3(0.95, 1.0, 0.8);
uniform float ondulacao = 0.22;
uniform float refracao = 0.018;
uniform float espuma = 0.55;
// Marolas: cristas de espuma que correm para a areia na água rasa, em dois trens de
// ondas de ritmo diferente, chegando a cada trecho da praia num momento e com força
// diferentes (séries que crescem e somem).
uniform float marolas = 0.85;
uniform float ritmo_marolas = 1.3;
uniform float faixa_marolas_m = 1.4;

varying vec2 superficie_m;

void vertex() {
	superficie_m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * metros_por_unidade;
}

// Distância (unidades) do ponto da superfície até o que está atrás dele na tela.
float espessura(vec2 uv, vec3 vertice, mat4 inv_projecao) {
	float z = texture(profundidade, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 ndc = vec4(vec3(uv, z) * 2.0 - 1.0, 1.0);
#else
	vec4 ndc = vec4(uv * 2.0 - 1.0, z, 1.0);
#endif
	vec4 atras = inv_projecao * ndc;
	atras.xyz /= atras.w;
	// Algo na frente da superfície (barco, píer): sem água entre os dois.
	return atras.z < vertice.z ? distance(atras.xyz, vertice) : 0.0;
}

void fragment() {
	vec2 p = superficie_m;
	vec3 a = texture(ondas_a, p / 11.0 + TIME * vec2(0.011, 0.006)).xyz;
	vec3 b = texture(ondas_b, p / 17.0 + TIME * vec2(-0.007, 0.009)).xyz;
	NORMAL_MAP = normalize(a + b - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = ondulacao;

	float esp_m = espessura(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX) * metros_por_unidade;
	// Refração leve, maior onde há mais água; não puxa o que está acima da superfície.
	vec2 desvio = (NORMAL_MAP.xy - 0.5) * refracao * clamp(esp_m / 1.5, 0.0, 1.0);
	vec2 uv = SCREEN_UV + desvio;
	float esp_desviada = espessura(uv, VERTEX, INV_PROJECTION_MATRIX) * metros_por_unidade;
	if (esp_desviada <= 0.0) {
		uv = SCREEN_UV;
	} else {
		esp_m = esp_desviada;
	}

	vec3 fundo = textureLod(tela, uv, 0.0).rgb;
	vec3 passa = exp(-absorcao * esp_m);
	// Espuma fina e quebrada só onde a lâmina é mínima (a baía é calma).
	float ruido_espuma = texture(ruido, p / 3.0 + TIME * vec2(0.02, -0.015)).r;
	float beira = (1.0 - smoothstep(0.0, 0.28, esp_m)) * smoothstep(0.45, 0.75, ruido_espuma) * espuma;
	// Profundidade na vertical: a espessura ao longo do olhar corrigida pelo ângulo, para
	// as marolas não mudarem com a inclinação da câmera. A fase cresce com a
	// profundidade e anda com o tempo: as cristas correm do fundo para a areia.
	vec3 olhar = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	float prof_v = esp_m * clamp(abs(olhar.y), 0.08, 1.0);
	float perto_da_praia = (1.0 - smoothstep(0.15, faixa_marolas_m, prof_v)) * smoothstep(0.0, 0.04, prof_v);
	// Atraso de cada trecho da praia: ruído lento ao longo da costa (a crista não é uma
	// linha única) e outro que muda devagar com o tempo.
	float atraso_a = texture(ruido, p / 55.0).r * 9.0 + texture(ruido, p / 140.0 + TIME * 0.004).r * 6.0;
	float atraso_b = texture(ruido, p / 37.0 + 0.5).r * 11.0;
	float onda_a = smoothstep(0.86, 1.0, sin(prof_v * 7.5 - TIME * ritmo_marolas + atraso_a));
	float onda_b = smoothstep(0.9, 1.0, sin(prof_v * 4.8 - TIME * ritmo_marolas * 0.63 + atraso_b + 2.1));
	// Séries: a força das ondas cresce e some por trechos, com o tempo.
	float serie = smoothstep(0.3, 0.7, texture(ruido, p / 90.0 + vec2(TIME * 0.011, -TIME * 0.007)).r);
	float crista = max(onda_a * (0.45 + 0.55 * serie), onda_b * serie) * perto_da_praia;
	// A espuma da crista se quebra em pedaços, mais inteira quanto mais rasa a água.
	float quebra = smoothstep(0.25, 0.6, ruido_espuma + 0.25 * (1.0 - prof_v / faixa_marolas_m));
	beira = max(beira, crista * marolas * quebra);

	EMISSION = fundo * tinta_rasa * passa * (1.0 - beira);
	ALBEDO = mix(cor_funda * (1.0 - passa), vec3(0.95), beira);
	ROUGHNESS = mix(0.05, 0.6, beira);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
