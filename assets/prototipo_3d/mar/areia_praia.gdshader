shader_type spatial;
// Faixa de areia da praia (geo_region_renderer._add_beach): UV.x vai de 0 (lado da
// terra) a 1 (lado do mar, já dentro d'água). Areia seca clara com grãos e marcas de
// vento; perto da água, areia úmida mais escura e brilhante.

uniform vec3 areia_seca : source_color = vec3(0.85, 0.79, 0.64);
uniform vec3 areia_molhada : source_color = vec3(0.66, 0.59, 0.45);
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
	float borda = ruido(mundo * 0.35) * 0.18;
	float umida = smoothstep(0.5 + borda, 0.78 + borda, UV.x);
	vec3 cor = mix(areia_seca, areia_molhada, umida);
	// Manchas largas, marcas de vento e grãos.
	cor *= 0.93 + 0.1 * ruido(mundo * 0.08);
	float marcas = sin(dot(mundo, vec2(0.83, 0.55)) * 5.5 + ruido(mundo * 0.6) * 4.0);
	cor *= 1.0 - 0.035 * smoothstep(0.6, 1.0, marcas) * (1.0 - umida);
	cor *= 0.94 + 0.1 * hash21(floor(mundo * 22.0));
	ALBEDO = cor;
	ROUGHNESS = mix(0.95, 0.45, umida);
	SPECULAR = mix(0.3, 0.55, umida);
}
