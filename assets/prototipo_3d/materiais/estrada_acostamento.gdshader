shader_type spatial;
render_mode cull_disabled;
// Acostamento das ruas (geo_region_renderer, faixas "Transição <rua>"): a fita mais
// larga, por baixo da estrada, que desenha SÓ a estrada e se esfarela para fora.
// Embaixo dela não há mais grama, e sim a terra batida do mapa de solo, então a
// borda lê sulco -> terra -> tufos de grama, como num caminho de chão de verdade,
// e não um degradê de duas imagens somadas numa faixa de 0,4 u.
// UV.x atravessa a faixa (0 e 1 nas bordas de fora); UV.y acompanha o percurso. Na
// parte do meio, o UV coincide com o da fita da estrada, sem linha entre as malhas.

#include "res://assets/prototipo_3d/materiais/solo.gdshaderinc"

uniform sampler2D road_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 road_tint : source_color = vec4(1.0);
// Fração da largura ocupada pela estrada; o resto é o acostamento, metade a cada lado.
uniform float road_fraction = 0.65;
// Onde, no acostamento (0 fora, 1 na beira da estrada), o recorte fica no meio.
uniform float meio_da_franja = 0.55;
varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float meia_franja = max((1.0 - road_fraction) * 0.5, 0.001);
	// 0 na borda de fora, 1 na beira da estrada (e acima disso no leito dela).
	float dentro = min(UV.x, 1.0 - UV.x) / meia_franja;
	vec2 uv_estrada = vec2((UV.x - meia_franja) / max(road_fraction, 0.001), UV.y / max(road_fraction, 0.001));
	vec3 estrada = texture(road_texture, uv_estrada).rgb * road_tint.rgb;
	// A beira da estrada é mais pisada no meio e mais solta na borda: escurece um
	// pouco e perde o sulco onde a franja começa.
	float solta = 1.0 - smoothstep(0.3, 1.0, dentro);
	ALBEDO = estrada * mix(1.0, 0.93, solta);
	ROUGHNESS = 0.95;
	ALPHA = esfarelar(clamp(dentro / max(meio_da_franja * 2.0, 0.001), 0.0, 1.0), mundo);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
}
