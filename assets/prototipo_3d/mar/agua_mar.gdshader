shader_type spatial;
// Superfície do mar da baía: água clara e calma, vista contra o fundo real
// (leito_mar.gdshader). A espessura de água entre a superfície e o fundo, lida do
// buffer de profundidade, decide a cor: a luz que volta do fundo perde primeiro o
// vermelho, depois o azul (água esverdeada de baía rasa), e o resto vira a cor da
// água funda. Assim o degradê areia → jade → turquesa → azul da foto sai da
// profundidade da carta, não de uma faixa pintada.
// A espuma da beira é só um filete fino e quebrado no primeiro dedo d'água, como
// numa baía sem arrebentação. shadows_disabled: as sombras duras dos coqueiros
// caíam dobradas sobre a água e o fundo ao mesmo tempo.

render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx, shadows_disabled;

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
// 0..1 vindo do autoload Mare: a enchente revolve o fundo e a água escurece.
uniform float turbidez : hint_range(0.0, 1.0) = 0.0;
uniform float ondulacao = 0.22;
uniform float refracao = 0.018;
uniform float espuma = 0.55;
// Marolas: cristas de espuma que correm para a areia na água rasa, em dois trens de
// ondas de ritmo diferente, chegando a cada trecho da praia num momento e com força
// diferentes (séries que crescem e somem). Espaçadas e suaves: baía calma.
uniform float marolas = 0.6;
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
	// Turbidez da enchente: mais absorção (vê-se menos fundo) e verde mais fechado.
	vec3 passa = exp(-absorcao * (1.0 + turbidez * 1.7) * esp_m);
	vec3 funda = mix(cor_funda, cor_funda * vec3(0.52, 0.62, 0.5), turbidez);
	// Profundidade na vertical: a espessura ao longo do olhar corrigida pelo ângulo, para
	// espuma e marolas não mudarem com a inclinação da câmera.
	vec3 olhar = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	float prof_v = esp_m * clamp(abs(olhar.y), 0.08, 1.0);
	// Filete da linha d'água: só onde a lâmina tem ~0–10 cm, quebrado em flocos por um
	// ruído fino de alta frequência — nada de banda branca contínua.
	float ruido_espuma = texture(ruido, p / 3.0 + TIME * vec2(0.02, -0.015)).r;
	float ruido_fino = texture(ruido, p / 0.9 - TIME * vec2(0.017, 0.023)).r;
	float filete = (1.0 - smoothstep(0.02, 0.1, prof_v)) * smoothstep(0.0, 0.015, prof_v);
	float flocos = smoothstep(0.58, 0.78, ruido_espuma * 0.45 + ruido_fino * 0.55);
	float beira = filete * flocos * espuma;
	// Marolas morrem antes da linha d'água (o filete assume lá) e são mais espaçadas.
	float perto_da_praia = (1.0 - smoothstep(0.3, faixa_marolas_m, prof_v)) * smoothstep(0.06, 0.25, prof_v);
	// Atraso de cada trecho da praia: ruído lento ao longo da costa (a crista não é uma
	// linha única) e outro que muda devagar com o tempo.
	float atraso_a = texture(ruido, p / 55.0).r * 9.0 + texture(ruido, p / 140.0 + TIME * 0.004).r * 6.0;
	float atraso_b = texture(ruido, p / 37.0 + 0.5).r * 11.0;
	float onda_a = smoothstep(0.9, 1.0, sin(prof_v * 4.6 - TIME * ritmo_marolas + atraso_a));
	float onda_b = smoothstep(0.93, 1.0, sin(prof_v * 2.9 - TIME * ritmo_marolas * 0.63 + atraso_b + 2.1));
	// Séries: a força das ondas cresce e some por trechos, com o tempo.
	float serie = smoothstep(0.35, 0.75, texture(ruido, p / 90.0 + vec2(TIME * 0.011, -TIME * 0.007)).r);
	float crista = max(onda_a * (0.35 + 0.65 * serie), onda_b * serie) * perto_da_praia;
	// A espuma da crista se quebra em pedaços em vez de correr inteira.
	float quebra = smoothstep(0.45, 0.75, ruido_espuma * 0.6 + ruido_fino * 0.4);
	beira = max(beira, crista * marolas * quebra);

	EMISSION = fundo * tinta_rasa * passa * (1.0 - beira);
	ALBEDO = mix(funda * (1.0 - passa), vec3(0.93), beira);
	ROUGHNESS = mix(0.05, 0.6, beira);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
