shader_type spatial;
render_mode cull_back, specular_disabled;
// A COPA DISTANTE (`copas_distantes.gd`): a esfera facetada de 64 triângulos que
// faz as vezes da árvore depois de ela sumir por LOD. A cor vem do vértice (escuro
// no pé, claro no topo) vezes a da instância (a da espécie, com a variação de
// cada copa), em linear. Aqui só entra o MALHADO de folhagem: o mesmo ruído de
// 6 a 12 u do chão (terreno.gdshader pinta a copa com ele, em #3E6B34 variando
// de #2E5229 a #4F7F45), para a borda da mata não ser uma bola lisa. A névoa e a
// perspectiva aérea são do ambiente; a luz, a do sol.

uniform float malha_grande = 7.0;
uniform float malha_fina = 2.2;
uniform float contraste = 0.4;

varying vec3 mundo;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// A altura entra no plano do ruído: o lado da copa não vira listra.
	vec2 plano = mundo.xz + vec2(mundo.y * 0.6, mundo.y * 0.35);
	float malhado = ruido(plano / malha_grande) * 0.6 + ruido(plano / malha_fina) * 0.4;
	vec3 cor = COLOR.rgb * (1.0 - contraste * 0.5 + contraste * malhado);
	ALBEDO = cor;
	ROUGHNESS = 0.95;
}
