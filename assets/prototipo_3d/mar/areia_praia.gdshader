shader_type spatial;
// Faixa de areia da praia (geo_region_renderer._add_beach): UV.x vai de 0 (lado da
// terra) a 1 (lado do mar, já dentro d'água). Textura de areia projetada pelo mundo
// (areia_praia_v1.png: grão, ondinhas de vento, conchinhas). A areia úmida escurece aos
// poucos, com borda irregular, até sumir sob a água; do lado da terra, a areia se
// desfaz em manchas sobre a grama e a terra batida em vez de terminar numa linha.

render_mode cull_back;

uniform sampler2D textura_areia : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ladrilho = 5.0;
uniform vec3 tom : source_color = vec3(0.92, 0.88, 0.8);
uniform vec3 umida : source_color = vec3(0.62, 0.55, 0.42);
// Fração da faixa (a partir da terra) em que a areia se desfaz sobre o chão.
uniform float franja = 0.2;
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
	vec3 areia = texture(textura_areia, mundo / ladrilho).rgb * tom;
	// Umidade: começa no meio da faixa com borda recortada e escurece de vez perto da
	// água; manchas mais secas e mais molhadas quebram a linha.
	float recorte = ruido(mundo * 0.22) * 0.22 + ruido(mundo * 1.3) * 0.08;
	float molhada = smoothstep(0.38 + recorte, 0.9 + recorte * 0.5, UV.x);
	vec3 cor = mix(areia, areia * umida * 1.25, molhada);
	ALBEDO = cor;
	ROUGHNESS = mix(0.95, 0.4, molhada);
	SPECULAR = mix(0.3, 0.6, molhada);
	// Lado da terra: a areia vira manchas que se misturam à grama/terra por baixo.
	float mancha = ruido(mundo * 0.5) * 0.6 + ruido(mundo * 2.1) * 0.4;
	ALPHA = step(1.0 - clamp(UV.x / franja, 0.0, 1.0), mancha);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
