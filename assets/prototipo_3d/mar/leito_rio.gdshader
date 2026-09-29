shader_type spatial;
render_mode cull_disabled;

// Uma única superfície de areia cobre o fundo e as margens do rio.
uniform sampler2D areia : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ladrilho = 5.0;
uniform vec3 tom : source_color = vec3(0.92, 0.88, 0.8);
uniform float fracao_canal = 0.55;
uniform float franja = 0.3;
varying vec2 mundo;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
	ALBEDO = cor;
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;

	// Mesmo recorte externo da praia; o centro permanece inteiramente coberto.
	float dentro_margem = clamp((1.0 - lateral) / max(1.0 - fracao_canal, 0.01), 0.0, 1.0);
	float borda = clamp(dentro_margem / max(franja, 0.001), 0.0, 1.0);
	float manchas = ruido(mundo * 0.5);
	float graos = ruido(mundo * 5.0);
	ALPHA = borda * 1.35 + (manchas - 0.5) * 0.6 + (graos - 0.5) * 0.35 - 0.18;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
