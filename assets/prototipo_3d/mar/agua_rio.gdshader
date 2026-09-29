shader_type spatial;
// Rio de água doce de mata do Recôncavo: água escura âmbar/marrom-esverdeada, calma e
// semitransparente — o leito escuro fica sugerido na própria cor, mais fundo no meio
// da faixa. Duas camadas de normais deslizam rio abaixo (UV.y cresce ao longo do
// percurso, em larguras) como correnteza lenta; o brilho especular é baixo, de água
// parada de sombra. As margens desvanecem (ALPHA some em UV.x 0 e 1) para a água
// morrer na grama sem linha dura. shadows_disabled: sem sombra dura de árvore
// quebrando a lâmina d'água.

render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx, shadows_disabled;

uniform sampler2D ondas_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ondas_b : hint_normal, filter_linear_mipmap, repeat_enable;
// Água rasa da margem (mais âmbar) e o miolo escuro sobre o leito sugerido.
uniform vec3 cor_margem : source_color = vec3(0.3, 0.27, 0.14);
uniform vec3 cor_fundo : source_color = vec3(0.13, 0.13, 0.07);
// Céu refletido na lâmina (visto de cima é o que faz parecer água, não lama).
uniform vec3 cor_ceu : source_color = vec3(0.62, 0.7, 0.68);
// Velocidade da correnteza em larguras do rio por segundo.
uniform float correnteza = 0.12;
uniform float ondulacao = 0.14;
uniform float transparencia : hint_range(0.0, 1.0) = 0.72;
uniform float comprimento = 1.0;
uniform float transicao_foz_larguras = 1.0;
uniform bool suavizar_inicio = false;
uniform bool suavizar_fim = false;

void fragment() {
	// UV.y está em larguras do rio: escala parecida nos dois eixos, sem esticar.
	vec3 a = texture(ondas_a, UV * vec2(0.9, 0.45) + vec2(0.0, -TIME * correnteza)).xyz;
	vec3 b = texture(ondas_b, UV * vec2(1.7, 0.8) + vec2(0.03, -TIME * correnteza * 1.7)).xyz;
	NORMAL_MAP = normalize(a + b - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = ondulacao;
	// Talvegue: mais escuro e mais opaco no meio, âmbar raso nas margens.
	float meio = smoothstep(0.0, 0.4, UV.x) * (1.0 - smoothstep(0.6, 1.0, UV.x));
	vec3 agua = mix(cor_margem, cor_fundo, meio);
	// Reflexo do céu por Fresnel: olhando de raspão o rio espelha o céu; de cima,
	// um brilho leve — sem isso a faixa lia como lama seca, não como água.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = mix(agua, cor_ceu, 0.14 + 0.5 * fresnel);
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	// Margens desvanecem na grama; o miolo é forte, mas nunca um breu opaco.
	float margem = smoothstep(0.0, 0.12, UV.x) * (1.0 - smoothstep(0.88, 1.0, UV.x));
	float transicao_foz = 1.0;
	if (suavizar_inicio) {
		transicao_foz *= smoothstep(0.0, transicao_foz_larguras, UV.y);
	}
	if (suavizar_fim) {
		transicao_foz *= 1.0 - smoothstep(max(comprimento - transicao_foz_larguras, 0.0), comprimento, UV.y);
	}
	ALPHA = transicao_foz * margem * mix(0.45, transparencia, meio);
}
