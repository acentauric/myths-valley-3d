shader_type spatial;
// Foz do rio (geo_region_renderer._add_river_mouths): a faixa de água do rio atravessa
// a areia e se desfaz no mar. UV.y cresce ao longo do percurso (em larguras); nos
// últimos trechos a água do rio fica transparente e deixa aparecer o mar.

render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 cor_rio : source_color = vec3(0.46, 0.71, 0.71);
uniform float comprimento = 4.0;
uniform float inicio_sumir = 0.45;
varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float t = UV.y / max(comprimento, 0.001);
	// Bordas da correnteza mais transparentes, e um brilho que desce o rio.
	float margem = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
	float correnteza = 0.5 + 0.5 * sin(UV.y * 6.0 - TIME * 1.6 + sin(mundo.x * 0.7) * 0.8);
	ALBEDO = cor_rio * (0.94 + 0.08 * correnteza);
	ROUGHNESS = 0.12;
	SPECULAR = 0.5;
	ALPHA = (1.0 - smoothstep(inicio_sumir, 1.0, t)) * mix(0.55, 0.95, margem);
}
