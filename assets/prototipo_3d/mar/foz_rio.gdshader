shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

uniform sampler2D ondas_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ondas_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 cor_margem : source_color = vec3(0.3, 0.27, 0.14);
uniform vec3 cor_fundo : source_color = vec3(0.13, 0.13, 0.07);
uniform vec3 cor_ceu : source_color = vec3(0.62, 0.7, 0.68);
uniform float comprimento = 4.0;
uniform float inicio_sumir = 0.45;
uniform float entrada_suave = 0.1;
uniform bool limite_na_costa = false;
uniform float correnteza = 0.12;
uniform float transparencia : hint_range(0.0, 1.0) = 0.72;
uniform float deslocamento_percurso = 0.0;
uniform float sentido_percurso = 1.0;
varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float t = UV.y / max(comprimento, 0.001);
	// Keep the same moving water through the mouth; only the sea fade changes.
	float percurso = UV.y * sentido_percurso + deslocamento_percurso;
	vec3 a = texture(ondas_a, vec2(UV.x * 0.9, percurso * 0.45) + vec2(0.0, -TIME * correnteza)).xyz;
	vec3 b = texture(ondas_b, vec2(UV.x * 1.7, percurso * 0.8) + vec2(0.03, -TIME * correnteza * 1.7)).xyz;
	NORMAL_MAP = normalize(a + b - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.14;
	float meio = smoothstep(0.0, 0.4, UV.x) * (1.0 - smoothstep(0.6, 1.0, UV.x));
	vec3 agua = mix(cor_margem, cor_fundo, meio);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(agua, cor_ceu, 0.14 + 0.5 * fresnel);
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	float fim = t + sin(mundo.x * 1.9 + mundo.y * 1.3) * 0.04;
	if (limite_na_costa) {
		fim = t;
	}
	float dilui = 1.0 - smoothstep(inicio_sumir, 1.0, fim);
	float margem = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
	float entrada = smoothstep(0.0, max(entrada_suave, 0.001), t);
	ALPHA = entrada * dilui * margem * mix(0.45, transparencia, meio);
}
