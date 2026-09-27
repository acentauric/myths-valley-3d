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

	EMISSION = fundo * tinta_rasa * passa * (1.0 - beira);
	ALBEDO = mix(cor_funda * (1.0 - passa), vec3(0.95), beira);
	ROUGHNESS = mix(0.05, 0.6, beira);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
