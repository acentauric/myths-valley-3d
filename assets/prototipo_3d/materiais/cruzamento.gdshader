shader_type spatial;
render_mode cull_back;
// Remendo de cada cruzamento das ruas (geo_region_renderer._build_road_junctions):
// um disco drapeado acima das duas fitas, que cobre a emenda. Antes ele repetia a
// estrada com os sulcos em outra direção e escala, e o cruzamento lia como uma
// mancha redonda. Agora é terra batida sem direção, a mesma tinta da estrada, com a
// borda esfarelada (a mesma receita do acostamento) sobre a terra do mapa de solo.

#include "res://assets/prototipo_3d/materiais/solo.gdshaderinc"

uniform sampler2D road_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform float ladrilho = 4.0;
uniform vec2 center;
uniform float radius = 3.0;
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Duas amostras giradas da terra: some a direção que a textura tiver.
	mat2 giro = mat2(vec2(0.0, 1.0), vec2(-1.0, 0.0));
	vec3 a = texture(road_texture, world_xz / ladrilho).rgb;
	vec3 b = texture(road_texture, giro * world_xz / (ladrilho * 1.37) + vec2(0.31, 0.57)).rgb;
	ALBEDO = mix(a, b, smoothstep(0.3, 0.7, ruido(world_xz * 0.35))) * tint.rgb;
	ROUGHNESS = 0.95;
	float borda = 1.0 - distance(world_xz, center) / radius;
	ALPHA = esfarelar(clamp(borda * 2.2, 0.0, 1.0), world_xz);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
}
