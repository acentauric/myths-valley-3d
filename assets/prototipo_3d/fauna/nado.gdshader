shader_type spatial;
// O NADO DO PEIXE DE CARDUME (cardume.gd): uma onda lateral que corre da cabeça
// para o rabo e cresce até a cauda, desenhada no vértice — centenas de peixes num
// MultiMesh só, sem esqueleto nenhum.
//
// `canonica` leva o vértice da malha do GLB para o "peixe canônico" do catálogo
// (deitado, de cabeça no -Z, centrado, na medida da "largura"); a onda é feita lá e
// `canonica_inv` devolve o vértice ao espaço da malha. Assim o rabear não depende de
// como cada GLB veio do Tripo.
//
// Por peixe, em INSTANCE_CUSTOM: x = fase (0..1), y = ritmo (1 no cruzeiro, mais
// na fuga), z = susto (0..1, aperta a onda), w = livre aqui (a silhueta do rio usa).
// Opaco: o mar (agua_mar.gdshader) lê a tela atrás dele e tinge o peixe pela
// espessura de água, como faz com o fundo.

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
// Comprimento do peixe canônico (unidades) e o rabear.
uniform float comprimento = 1.0;
uniform float amplitude = 0.08;
uniform float batida = 10.0;
// O tempo do nado, em segundos de JOGO: quem monta o cardume o avanca a cada quadro (cardume.gd).
// Com o TIME do motor (que nao pausa) o peixe seguia remando no lugar com o jogo pausado: a posicao parava, a cauda nao.
uniform float tempo = 0.0;
// Quantas ondas cabem no corpo: perto de 1 é o nado de peixe de escama.
uniform float ondas = 0.9;

void vertex() {
	vec3 c = (canonica * vec4(VERTEX, 1.0)).xyz;
	float fase = INSTANCE_CUSTOM.x * 6.2831853;
	float ritmo = max(INSTANCE_CUSTOM.y, 0.2);
	// 0 na ponta do focinho (-Z), 1 na ponta da cauda (+Z).
	float t = clamp(c.z / max(comprimento, 0.001) + 0.5, 0.0, 1.0);
	float peso = 0.08 + t * t;
	float onda = sin(tempo * batida * ritmo + fase - t * ondas * 6.2831853);
	float forca = amplitude * (1.0 + INSTANCE_CUSTOM.z * 0.6);
	c.x += onda * forca * comprimento * peso;
	// A cabeça gira um pouco contra o rabo, como no peixe de verdade.
	c.x -= onda * forca * comprimento * 0.05 * (1.0 - t);
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
		ROUGHNESS = 0.4;
		METALLIC = 0.25;
	}
	if (tem_normal) {
		NORMAL_MAP = texture(textura_normal, UV).rgb;
	}
}
