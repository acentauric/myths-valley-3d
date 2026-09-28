shader_type spatial;
// Foz do rio (geo_region_renderer._add_river_mouths): a faixa de água doce escura
// (a mesma cor âmbar de agua_rio.gdshader) atravessa a areia e se dilui no mar.
// UV.y cresce ao longo do percurso (em larguras); nos últimos trechos a água do rio
// fica transparente, com a borda de diluição irregular, e deixa aparecer o mar.

render_mode blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

uniform vec3 cor_rio : source_color = vec3(0.16, 0.13, 0.07);
uniform float comprimento = 4.0;
uniform float inicio_sumir = 0.45;
varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float t = UV.y / max(comprimento, 0.001);
	// Bordas da correnteza mais transparentes, e um brilho que desce o rio.
	float margem = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	float correnteza = 0.5 + 0.5 * sin(UV.y * 5.0 - TIME * 1.2 + sin(mundo.x * 0.7) * 0.8);
	// Água escura de mata: a película clareia de leve onde a correnteza passa.
	ALBEDO = cor_rio * (0.9 + 0.25 * correnteza);
	ROUGHNESS = 0.18;
	SPECULAR = 0.4;
	// A diluição no mar tem borda irregular (a pluma não termina numa linha reta).
	float dilui = 1.0 - smoothstep(inicio_sumir, 1.0, t + sin(mundo.x * 1.9 + mundo.y * 1.3) * 0.04);
	ALPHA = dilui * mix(0.35, 0.8, margem);
}
