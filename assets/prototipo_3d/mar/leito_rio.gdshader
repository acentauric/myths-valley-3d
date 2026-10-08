shader_type spatial;
render_mode cull_disabled;

// Uma única superfície cobre o fundo e as margens do rio: areia na calha e, com
// `mistura_lama`, lama nas margens (a mesma lama de mangue que o terreno pinta em
// volta, pelo mapa de solo — docs/mundo/SOLO_E_FRANJAS.md). Com mistura_lama 0, que é
// o padrão, é a areia de sempre (a cena da orla usa este shader assim).
uniform sampler2D areia : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ladrilho = 5.0;
uniform vec3 tom : source_color = vec3(0.92, 0.88, 0.8);
uniform float fracao_canal = 0.55;
uniform float franja = 0.3;
uniform sampler2D lama : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ladrilho_lama = 4.0;
uniform vec3 tinta_lama : source_color = vec3(1.0);
uniform float mistura_lama = 0.0;
// Foz: a laje de areia que passa da costa para o mar se desfaz em manchas ao largo,
// por `costa_desfaz` unidades a partir de `costa_ponto` no rumo `costa_direcao`
// (0 desliga: o leito do rio e a cena da orla não usam).
uniform vec2 costa_ponto = vec2(0.0);
uniform vec2 costa_direcao = vec2(0.0, 1.0);
uniform float costa_desfaz = 0.0;
// A areia de rio é mais escura e fria que a de praia: tom da calha com a lama.
uniform vec3 tom_calha_com_lama : source_color = vec3(0.7, 0.64, 0.54);
varying vec2 mundo;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ruido(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(c), hash21(c + vec2(1.0, 0.0)), f.x), mix(hash21(c + vec2(0.0, 1.0)), hash21(c + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 cor = texture(areia, mundo / ladrilho).rgb * tom;
	float lateral = abs(UV.x - 0.5) * 2.0;
	float centro = 1.0 - smoothstep(0.0, fracao_canal, lateral);
	cor *= 1.0 - 0.075 * centro;

	// Raros grãos mais escuros, sem círculos grandes nem contraste de cascalheira.
	vec2 grade = mundo * 2.4;
	vec2 celula = floor(grade);
	vec2 local = fract(grade);
	float presente = step(0.975, hash21(celula));
	vec2 posicao = vec2(hash21(celula + vec2(13.0, 7.0)), hash21(celula + vec2(3.0, 17.0)));
	float grao = presente * centro * (1.0 - smoothstep(0.025, 0.075, distance(local, posicao)));
	cor *= 1.0 - grao * 0.12;
	float rugosidade = 0.94;
	if (mistura_lama > 0.0) {
		// Calha em areia de rio escura; da beira da água para fora, lama, com a
		// troca recortada por ruído (sem linha reta acompanhando o rio).
		vec3 calha = cor * mix(vec3(1.0), tom_calha_com_lama / tom, mistura_lama);
		vec3 barro = texture(lama, mundo / ladrilho_lama).rgb * tinta_lama;
		float fora = smoothstep(fracao_canal * 0.75, fracao_canal * 1.1, lateral + (ruido(mundo * 0.7) - 0.5) * 0.25);
		float m = fora * mistura_lama;
		cor = mix(calha, barro, m);
		rugosidade = mix(0.94, 0.6, m);
	}
	ALBEDO = cor;
	ROUGHNESS = rugosidade;
	SPECULAR = 0.18;

	// Mesmo recorte externo da praia; o centro permanece inteiramente coberto.
	float dentro_margem = clamp((1.0 - lateral) / max(1.0 - fracao_canal, 0.01), 0.0, 1.0);
	float borda = clamp(dentro_margem / max(franja, 0.001), 0.0, 1.0);
	float manchas = ruido(mundo * 0.5);
	float graos = ruido(mundo * 5.0);
	float ao_largo = costa_desfaz > 0.0 ? clamp(dot(mundo - costa_ponto, costa_direcao) / costa_desfaz, 0.0, 1.0) : 0.0;
	ALPHA = borda * 1.35 + (manchas - 0.5) * 0.6 + (graos - 0.5) * 0.35 - 0.18 - ao_largo * 1.7;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
