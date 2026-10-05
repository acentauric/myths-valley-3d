shader_type spatial;
render_mode cull_disabled;
// O chão do vale (geo_region_renderer, malha "Terra"). Antes era uma textura só, a
// grama/terra/mata tingida a cada 12 u: um carpete oliva igual na praça, no pasto,
// na beira do rio e no alto do Mirante. Agora são oito camadas misturadas por três
// regras (docs/mundo/SOLO_E_FRANJAS.md):
//   - o MAPA DE SOLO (mapa_de_solo.gd, uma Texture2DArray de 1 px por unidade):
//     terra das ruas, praça e trilhas; areia da costa; lama dos rios; pasto da
//     fazenda; copa das árvores (folhiço embaixo delas);
//   - o DECLIVE (normal suave da malha): barro vermelho no barranco, pedrisco na
//     encosta forte e no topo do Mirante;
//   - o RUÍDO grande, que quebra a repetição e desloca cada limiar.
// As camadas se misturam pela ALTURA guardada no alfa de cada textura: na borda, o
// tufo de grama sobe por cima da terra e a pedra por cima da lama, em vez de um
// degradê de duas imagens somadas.
// AO LONGE (perspectiva), onde a mata já sumiu por LOD, a copa vira chão pintado de
// verde-mata, e o chão sob ela se ergue um pouco: o morro não fica pelado.
// Todo uniform tem padrão neutro: sem o mapa e sem as forças, é a grama de antes.

#include "res://assets/prototipo_3d/materiais/solo.gdshaderinc"

uniform sampler2D tex_grama : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_capim : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_folhico : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_terra : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_barro : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_pedrisco : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_areia : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_lama : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
// Areia da foz central (a mesma da praia e do leito do rio, que cobrem a junta).
uniform sampler2D sand_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;

// Ladrilho de cada camada, em unidades (1 u = 4 m).
uniform float ladrilho_grama = 12.0;
uniform float ladrilho_capim = 5.0;
uniform float ladrilho_folhico = 3.5;
uniform float ladrilho_terra = 4.0;
uniform float ladrilho_barro = 5.0;
uniform float ladrilho_pedrisco = 3.0;
uniform float ladrilho_areia = 5.0;
uniform float ladrilho_lama = 4.0;
// Tinta de cada camada: acerta a média medida da textura com a paleta da
// AMBIENTACAO §7 (tools/materiais/preparar_textura_chao.py imprime as médias).
uniform vec3 tinta_grama : source_color = vec3(1.0);
uniform vec3 tinta_capim : source_color = vec3(1.0);
uniform vec3 tinta_folhico : source_color = vec3(1.0);
uniform vec3 tinta_terra : source_color = vec3(1.0);
uniform vec3 tinta_barro : source_color = vec3(1.0);
uniform vec3 tinta_pedrisco : source_color = vec3(1.0);
uniform vec3 tinta_areia : source_color = vec3(1.0);
uniform vec3 tinta_lama : source_color = vec3(1.0);

// Mapa de solo: camadas 0 terra, 1 areia, 2 lama, 3 pasto, 4 copa.
uniform bool solo_ativo = false;
uniform sampler2DArray solo : filter_linear, repeat_disable;
uniform vec2 solo_origem = vec2(0.0);
uniform vec2 solo_tamanho = vec2(1.0);
// 0 desliga barro e pedrisco do declive e do alto do morro.
uniform float forca_declive = 0.0;
// Altura (u) a partir da qual o topo do morro vira pedrisco.
uniform float altura_pedrisco = 38.0;
// Variação de brilho das manchas grandes (0,1 = ±10 %) e a segunda amostra girada
// da grama, que entra de longe para o ladrilho não virar grade.
uniform float variacao_grande = 0.0;
uniform vec2 segunda_amostra = vec2(30.0, 80.0);

// Copa ao longe: começa a pintar em copa_inicio e cobre em copa_cheia (distância da
// câmera); o renderizador as tira do LOD_MATA. O chão sob a copa sobe copa_ergue u
// a partir de ergue_inicio. Padrão: longe demais para acontecer.
uniform vec3 cor_copa : source_color = vec3(0.243, 0.42, 0.204);
uniform vec3 cor_copa_escura : source_color = vec3(0.18, 0.322, 0.161);
uniform vec3 cor_copa_clara : source_color = vec3(0.31, 0.498, 0.271);
uniform float copa_inicio = 100000.0;
uniform float copa_cheia = 100001.0;
uniform float copa_ergue = 0.0;
uniform float ergue_inicio = 220.0;
uniform float ergue_cheio = 270.0;

uniform bool mouth_sand_enabled = false;
uniform vec2 mouth_a;
uniform vec2 mouth_b;
uniform vec2 mouth_c;
uniform vec2 mouth_d;
uniform vec2 mouth_e;
uniform float mouth_sand_inner = 4.0;
uniform float mouth_sand_outer = 4.75;

varying vec3 mundo;
varying vec3 normal_mundo;

float camada_solo(vec2 xz, float indice) {
	return texture(solo, vec3((xz - solo_origem) / solo_tamanho, indice)).r;
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Só na câmera em perspectiva: mapa, minimapa e a sombra do sol (ortográficas)
	// veem o chão de verdade. A distância é a da câmera principal, para a sombra
	// das luzes de ponto concordar.
	if (solo_ativo && copa_ergue > 0.0 && PROJECTION_MATRIX[3][3] == 0.0) {
		float d = distance(mundo, MAIN_CAM_INV_VIEW_MATRIX[3].xyz);
		float longe = smoothstep(ergue_inicio, ergue_cheio, d);
		if (longe > 0.0) {
			float copa = textureLod(solo, vec3((mundo.xz - solo_origem) / solo_tamanho, 4.0), 0.0).r;
			float sobe = copa * copa_ergue * longe * (0.7 + 0.6 * ruido(mundo.xz / 9.0));
			VERTEX.y += sobe;
			mundo.y += sobe;
		}
	}
}

void fragment() {
	vec2 xz = mundo.xz;
	// Derivadas fora dos ifs: dentro deles o GPU não as tem, e o mipmap costura.
	vec2 ddx = dFdx(xz);
	vec2 ddy = dFdy(xz);
	float dist = distance(mundo, CAMERA_POSITION_WORLD);
	bool perspectiva = PROJECTION_MATRIX[3][3] == 0.0;

	float n_grande = ruido2(xz / 23.0);
	float n_medio = ruido(xz / 4.3);
	float n_fino = ruido(xz * 1.3);

	float s_terra = 0.0;
	float s_areia = 0.0;
	float s_lama = 0.0;
	float s_pasto = 0.0;
	float s_copa = 0.0;
	if (solo_ativo) {
		s_terra = camada_solo(xz, 0.0);
		s_areia = camada_solo(xz, 1.0);
		s_lama = camada_solo(xz, 2.0);
		s_pasto = camada_solo(xz, 3.0);
		s_copa = camada_solo(xz, 4.0);
	}
	// Declive: 1 - cos do ângulo. 11° = 0,018; 20° = 0,060; 22° = 0,073.
	float declive = 1.0 - clamp(normal_mundo.y, 0.0, 1.0);
	float tremor = (n_medio - 0.5);

	float w_terra = smoothstep(0.28, 0.72, s_terra + tremor * 0.55 + (n_fino - 0.5) * 0.18);
	float w_areia = smoothstep(0.3, 0.7, s_areia + tremor * 0.45);
	float w_lama = smoothstep(0.55, 0.85, s_lama + tremor * 0.3);
	float w_capim = smoothstep(0.42, 0.78, s_pasto * (0.45 + n_grande * 0.9) + tremor * 0.15);
	float w_folhico = smoothstep(0.32, 0.78, s_copa + tremor * 0.4) * (1.0 - w_areia);
	float w_barro = forca_declive * clamp(
		smoothstep(0.018, 0.06, declive + tremor * 0.015)
		+ s_terra * smoothstep(0.006, 0.02, declive) * 0.85, 0.0, 1.0) * (1.0 - w_areia);
	float w_pedrisco = forca_declive * clamp(
		smoothstep(0.07, 0.1, declive + tremor * 0.02)
		+ smoothstep(altura_pedrisco, altura_pedrisco + 4.0, mundo.y) * smoothstep(0.35, 0.65, n_grande + tremor * 0.3), 0.0, 1.0);
	float outros = max(max(max(w_terra, w_areia), max(w_lama, w_capim)), max(max(w_folhico, w_barro), w_pedrisco));
	float w_grama = 1.0 - outros;

	// A grama é a base: sempre lida. De perto, uma amostra; de 30 a 80 u, metade
	// vem de uma segunda amostra girada e 4x maior, que desmancha a grade.
	vec2 uv_g = xz / ladrilho_grama;
	vec4 t_grama = textureGrad(tex_grama, uv_g, ddx / ladrilho_grama, ddy / ladrilho_grama);
	float segunda = smoothstep(segunda_amostra.x, segunda_amostra.y, dist) * 0.5;
	if (segunda > 0.0) {
		mat2 giro = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
		float l2 = ladrilho_grama * 4.0;
		vec4 t2 = textureGrad(tex_grama, giro * xz / l2, giro * ddx / l2, giro * ddy / l2);
		t_grama = mix(t_grama, t2, segunda);
	}
	vec3 cor_grama = t_grama.rgb * tinta_grama;
	// Mistura pela altura: peso × (altura + 0,4), à quarta, normalizado.
	float soma = 0.0;
	vec3 cor = vec3(0.0);
	float p = pow(w_grama * (t_grama.a + 0.4), 4.0);
	cor += cor_grama * p;
	soma += p;
	if (w_capim > 0.02) {
		vec4 t = textureGrad(tex_capim, xz / ladrilho_capim, ddx / ladrilho_capim, ddy / ladrilho_capim);
		p = pow(w_capim * (t.a + 0.4), 4.0);
		cor += t.rgb * tinta_capim * p;
		soma += p;
	}
	if (w_folhico > 0.02) {
		vec4 t = textureGrad(tex_folhico, xz / ladrilho_folhico, ddx / ladrilho_folhico, ddy / ladrilho_folhico);
		p = pow(w_folhico * (t.a + 0.4), 4.0);
		cor += t.rgb * tinta_folhico * p;
		soma += p;
	}
	if (w_terra > 0.02) {
		vec4 t = textureGrad(tex_terra, xz / ladrilho_terra, ddx / ladrilho_terra, ddy / ladrilho_terra);
		p = pow(w_terra * (t.a + 0.4), 4.0);
		cor += t.rgb * tinta_terra * p;
		soma += p;
	}
	if (w_barro > 0.02) {
		vec4 t = textureGrad(tex_barro, xz / ladrilho_barro, ddx / ladrilho_barro, ddy / ladrilho_barro);
		p = pow(w_barro * (t.a + 0.4), 4.0);
		cor += t.rgb * tinta_barro * p;
		soma += p;
	}
	if (w_pedrisco > 0.02) {
		vec4 t = textureGrad(tex_pedrisco, xz / ladrilho_pedrisco, ddx / ladrilho_pedrisco, ddy / ladrilho_pedrisco);
		p = pow(w_pedrisco * (t.a + 0.4), 4.0);
		cor += t.rgb * tinta_pedrisco * p;
		soma += p;
	}
	if (w_areia > 0.02) {
		vec4 t = textureGrad(tex_areia, xz / ladrilho_areia, ddx / ladrilho_areia, ddy / ladrilho_areia);
		p = pow(w_areia * (t.a + 0.4), 4.0);
		cor += t.rgb * tinta_areia * p;
		soma += p;
	}
	float lama_lisa = 0.0;
	if (w_lama > 0.02) {
		vec4 t = textureGrad(tex_lama, xz / ladrilho_lama, ddx / ladrilho_lama, ddy / ladrilho_lama);
		p = pow(w_lama * (t.a + 0.4), 4.0);
		cor += t.rgb * tinta_lama * p;
		soma += p;
		lama_lisa = p;
	}
	cor /= max(soma, 0.00001);
	lama_lisa /= max(soma, 0.00001);
	// A cauda da lama não troca a textura: é a umidade da mata ciliar, que escurece.
	float umido = smoothstep(0.08, 0.6, s_lama) * (1.0 - lama_lisa);
	cor *= mix(1.0, 0.8, umido);
	// Manchas grandes de brilho.
	cor *= 1.0 + (n_grande - 0.5) * 2.0 * variacao_grande;

	if (mouth_sand_enabled) {
		float distance_from_mouth = min(
			min(distancia_segmento(xz, mouth_a, mouth_b), distancia_segmento(xz, mouth_b, mouth_c)),
			min(distancia_segmento(xz, mouth_c, mouth_d), distancia_segmento(xz, mouth_d, mouth_e))
		);
		float sand_amount = 1.0 - smoothstep(mouth_sand_inner, mouth_sand_outer, distance_from_mouth);
		vec3 sand = texture(sand_texture, xz / 5.0).rgb * vec3(0.92, 0.88, 0.8);
		cor = mix(cor, sand, sand_amount);
	}

	float rugosidade = mix(0.94, 0.55, lama_lisa) - umido * 0.12;
	// Copa ao longe: verde-mata em manchas de 6 a 12 u, com a sombra de cada copa.
	if (perspectiva && s_copa > 0.01) {
		float longe = smoothstep(copa_inicio, copa_cheia, dist);
		if (longe > 0.0) {
			float copas = ruido2(xz / 7.0);
			vec3 verde = mix(cor_copa_escura, cor_copa_clara, smoothstep(0.25, 0.75, copas));
			verde = mix(verde, cor_copa, 0.35);
			verde *= 0.82 + 0.3 * ruido(xz / 2.6);
			float cobre = smoothstep(0.15, 0.6, s_copa) * longe;
			cor = mix(cor, verde, cobre);
			rugosidade = mix(rugosidade, 0.85, cobre);
		}
	}
	ALBEDO = cor;
	ROUGHNESS = rugosidade;
}
