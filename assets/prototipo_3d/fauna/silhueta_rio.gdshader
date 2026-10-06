shader_type spatial;
// O PEIXE DO RIO COMO SILHUETA: a água doce (agua_rio.gdshader) é escura e opaca no
// meio da calha, e um peixe submerso desenhado do jeito normal sumiria debaixo
// dela. Aqui ele é desenhado DEPOIS da água (transparente, render_priority 1 no
// material, sem escrever profundidade) — o mesmo truque do CorpoSombra do tubarão —
// como a sombra escura que se vê de cima num poço de rio. Quem salta (INSTANCE_CUSTOM.w
// = 1) aparece com a textura inteira, fora da água.
//
// O nado é o mesmo do nado.gdshader: x = fase, y = ritmo, z = susto.

render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform sampler2D textura_cor : source_color, filter_linear_mipmap, repeat_enable;
uniform bool tem_textura = false;
uniform vec4 cor : source_color = vec4(1.0);
// Cor e opacidade da sombra dentro d'água.
uniform vec4 sombra : source_color = vec4(0.05, 0.06, 0.04, 0.55);
uniform mat4 canonica;
uniform mat4 canonica_inv;
uniform float comprimento = 1.0;
uniform float amplitude = 0.08;
uniform float batida = 10.0;
// O tempo do nado, em segundos de JOGO: quem monta o cardume o avanca a cada quadro (cardume.gd).
// Com o TIME do motor (que nao pausa) o peixe seguia remando no lugar com o jogo pausado: a posicao parava, a cauda nao.
uniform float tempo = 0.0;
uniform float ondas = 0.9;

varying float fora_dagua;

void vertex() {
	vec3 c = (canonica * vec4(VERTEX, 1.0)).xyz;
	float fase = INSTANCE_CUSTOM.x * 6.2831853;
	float ritmo = max(INSTANCE_CUSTOM.y, 0.2);
	float t = clamp(c.z / max(comprimento, 0.001) + 0.5, 0.0, 1.0);
	float peso = 0.08 + t * t;
	float onda = sin(tempo * batida * ritmo + fase - t * ondas * 6.2831853);
	float forca = amplitude * (1.0 + INSTANCE_CUSTOM.z * 0.6);
	c.x += onda * forca * comprimento * peso;
	VERTEX = (canonica_inv * vec4(c, 1.0)).xyz;
	fora_dagua = INSTANCE_CUSTOM.w;
}

void fragment() {
	vec4 base = tem_textura ? texture(textura_cor, UV) : vec4(1.0);
	vec3 viva = base.rgb * cor.rgb;
	ALBEDO = mix(sombra.rgb, viva, fora_dagua);
	ALPHA = mix(sombra.a, 1.0, fora_dagua);
}
