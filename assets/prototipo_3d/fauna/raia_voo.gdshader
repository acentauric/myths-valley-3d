shader_type spatial;
// O VOO DA RAIA (cardume.gd, formas "raia"): as asas sobem e descem numa onda que
// corre do focinho para a cauda — o Y da asa desloca em proporção a |x|^1,5, a
// ponta mexe mais que o corpo. Mesmo esquema do nado.gdshader: a onda é feita no
// "peixe canônico" (de cabeça no -Z, asas no X) e volta ao espaço da malha.
//
// INSTANCE_CUSTOM: x = fase (0..1), y = ritmo (perto de 0 deitada na areia, só a
// borda ondula; 1 no voo; mais na disparada), z = susto.

render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D textura_cor : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D textura_mr : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform bool tem_textura = false;
uniform bool tem_normal = false;
uniform bool tem_mr = false;
uniform vec4 cor : source_color = vec4(1.0);
uniform mat4 canonica;
uniform mat4 canonica_inv;
// Envergadura (unidades) e comprimento do corpo canônico.
uniform float envergadura = 1.0;
uniform float comprimento = 1.0;
uniform float amplitude = 0.12;
uniform float batida = 2.6;

void vertex() {
	vec3 c = (canonica * vec4(VERTEX, 1.0)).xyz;
	float fase = INSTANCE_CUSTOM.x * 6.2831853;
	float ritmo = INSTANCE_CUSTOM.y;
	float meia = max(envergadura * 0.5, 0.001);
	float x = clamp(abs(c.x) / meia, 0.0, 1.0);
	float t = clamp(c.z / max(comprimento, 0.001) + 0.5, 0.0, 1.0);
	// Deitada (ritmo ~0) só a borda ondula devagar; no voo a asa bate inteira.
	float voo = clamp(ritmo, 0.0, 1.0);
	float bater = sin(TIME * batida * max(ritmo, 0.35) + fase - t * 2.4);
	float borda = sin(TIME * 1.7 + fase + t * 9.0) * 0.25;
	float desloca = mix(borda * smoothstep(0.75, 1.0, x), bater * pow(x, 1.5), voo);
	c.y += desloca * amplitude * envergadura * (1.0 + INSTANCE_CUSTOM.z * 0.4);
	VERTEX = (canonica_inv * vec4(c, 1.0)).xyz;
}

void fragment() {
	vec4 base = tem_textura ? texture(textura_cor, UV) : vec4(1.0);
	ALBEDO = base.rgb * cor.rgb;
	if (tem_mr) {
		vec4 mr = texture(textura_mr, UV);
		ROUGHNESS = mr.g;
		METALLIC = mr.b;
	} else {
		ROUGHNESS = 0.6;
		METALLIC = 0.0;
	}
	if (tem_normal) {
		NORMAL_MAP = texture(textura_normal, UV).rgb;
	}
}
