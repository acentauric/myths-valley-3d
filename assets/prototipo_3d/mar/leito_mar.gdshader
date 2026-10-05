shader_type spatial;
// Fundo do mar moldado pela batimetria (tools/mapas/gerar_batimetria.py): cada texel
// guarda a elevação acima da preamar, normalizada. A malha é um plano subdividido; a
// altura sai da textura aqui, sem custo de montagem na CPU. Areia perto da praia, lama
// no fundo, manchas de capim marinho no raso e cáusticas do sol onde a água é pouca.
// Acima da água (fora do quadro do mapa) o mesmo plano é o continente distante.
// A maré entra por `mare_offset_m` (autoload Mare): na baixa-mar a lâmina efetiva
// zera no raso e o fundo aflora como lama molhada com poças espelhadas.
// shadows_disabled: as sombras chegavam dobradas pela água por cima e ficavam feias.

render_mode shadows_disabled;

uniform sampler2D elevacao : filter_linear, repeat_disable;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
uniform vec2 texel = vec2(0.0018, 0.002);
// Retângulo (XZ, unidades) coberto pela batimetria; fora dele vale a borda da textura.
uniform vec2 origem = vec2(-500.0, -375.0);
uniform vec2 tamanho = vec2(1375.0, 1250.0);
// Plano distante: não desenha onde o fundo detalhado já está.
uniform bool recortar_grade = false;
uniform float elevacao_min_m = -35.0;
uniform float elevacao_max_m = 100.0;
uniform float metros_por_unidade = 4.0;
// A terra além do quadro sobe com o mesmo exagero do relevo do jogo (vertical_exaggeration);
// sem ele ficava na metade da altura, num degrau na borda. O fundo do mar não exagera.
uniform float exageracao_vertical = 1.0;
// Deslocamento da maré em metros: 0 na preamar, até -2,4 na baixa-mar.
uniform float mare_offset_m = 0.0;

uniform vec3 cor_areia : source_color = vec3(0.86, 0.80, 0.62);
uniform vec3 cor_lama : source_color = vec3(0.50, 0.46, 0.36);
uniform vec3 cor_capim : source_color = vec3(0.24, 0.31, 0.18);
uniform vec3 cor_pasto : source_color = vec3(0.42, 0.47, 0.25);
uniform vec3 cor_mata : source_color = vec3(0.16, 0.25, 0.12);
// Poças da baixa-mar: espelhos azul-claros do céu nas baixadas da lama.
uniform vec3 cor_poca : source_color = vec3(0.34, 0.44, 0.48);
uniform float causticas = 0.35;

varying float lamina_m;
varying vec2 chao_m;
varying vec2 chao;

// Lâmina d'água em metros na preamar (negativa = terra acima da preamar).
float lamina(vec2 uv) {
	return -mix(elevacao_min_m, elevacao_max_m, texture(elevacao, uv).r);
}

// Lâmina com o exagero do relevo só onde é terra (lâmina negativa).
float relevo(float l) {
	return l < 0.0 ? l * exageracao_vertical : l;
}

void vertex() {
	chao = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 uv = (chao - origem) / tamanho;
	lamina_m = lamina(uv);
	VERTEX.y = -relevo(lamina_m) / metros_por_unidade;
	vec2 passo = texel * tamanho;
	float leste = relevo(lamina(uv + vec2(texel.x, 0.0)));
	float oeste = relevo(lamina(uv - vec2(texel.x, 0.0)));
	float sul = relevo(lamina(uv + vec2(0.0, texel.y)));
	float norte = relevo(lamina(uv - vec2(0.0, texel.y)));
	NORMAL = normalize(vec3(
		(leste - oeste) / metros_por_unidade / (2.0 * passo.x),
		1.0,
		(sul - norte) / metros_por_unidade / (2.0 * passo.y)));
	chao_m = chao * metros_por_unidade;
}

// Rede de luz do sol refratada pelas marolas: diferença de duas camadas de ruído que
// andam em sentidos opostos, afinada em linhas claras.
float caustica(vec2 p, float t) {
	float a = texture(ruido, p / 7.0 + vec2(t * 0.021, t * 0.013)).r;
	float b = texture(ruido, p / 8.3 - vec2(t * 0.017, -t * 0.019)).r;
	return pow(clamp(1.0 - abs(a - b) * 4.0, 0.0, 1.0), 5.0);
}

void fragment() {
	if (recortar_grade) {
		vec2 dentro = (chao - origem) / tamanho;
		if (all(greaterThan(dentro, vec2(0.0))) && all(lessThan(dentro, vec2(1.0)))) {
			discard;
		}
	}
	// Lâmina efetiva do momento: a preamar da carta mais o deslocamento da maré.
	float d = lamina_m + mare_offset_m;
	float medio = texture(ruido, chao_m / 37.0).r;
	float fino = texture(ruido, chao_m / 5.5).r;
	// Manchas grandes com a borda torcida por outro ruído: formas irregulares.
	vec2 torcao = vec2(texture(ruido, chao_m / 160.0 + 0.37).r, texture(ruido, chao_m / 160.0 + 0.71).r) - 0.5;
	float grande = texture(ruido, chao_m / 420.0 + torcao * 0.35).r;

	// Areia clara no raso, lama acinzentada a partir de ~4 m (a carta marca L e A).
	vec3 cor = mix(cor_areia, cor_lama, smoothstep(2.5, 9.0, d + (medio - 0.5) * 3.0));
	// Capim marinho e lama escura em poucas manchas, entre ~1 e 6 m.
	float faixa_capim = smoothstep(0.9, 1.8, d) * (1.0 - smoothstep(5.0, 8.0, d));
	float mancha = smoothstep(0.66, 0.76, grande + (medio - 0.5) * 0.25) * faixa_capim;
	cor = mix(cor, cor_capim, mancha * 0.55);
	cor *= 0.88 + 0.24 * fino;
	// Beira: areia amarelada e bem clara no primeiro palmo d'água, como na foto.
	cor = mix(cor, cor_areia * vec3(1.06, 1.02, 0.9), (1.0 - smoothstep(0.1, 0.9, d)) * step(0.0, d) * 0.6);

	float aspereza = 0.92;
	float especular = 0.2;
	// Baixa-mar: onde havia água na preamar e a lâmina efetiva zerou, o fundo aflora —
	// lama molhada escura com brilho úmido e poças espelhadas nas manchas mais baixas.
	float exposto = (1.0 - smoothstep(0.0, 0.15, d)) * smoothstep(0.02, 0.25, lamina_m);
	if (exposto > 0.001) {
		vec3 lama_umida = mix(cor_lama, cor_areia, 0.35) * vec3(0.62, 0.58, 0.5) * (0.88 + 0.24 * fino);
		// Poças (como na foto da canoa amarela): poucas, grandes e escuras espelhando o
		// céu, juntas da água que recuou — onde o fundo mal acabou de secar (d perto de
		// 0) e numa baixada das manchas grandes. Longe da linha d'água, lama só úmida.
		float perto_agua = 1.0 - smoothstep(0.05, 0.9, -d);
		float baixada = smoothstep(0.6, 0.7, 1.0 - grande + (medio - 0.5) * 0.18);
		float poca = clamp(baixada * (0.15 + 0.85 * perto_agua), 0.0, 1.0);
		poca = smoothstep(0.35, 0.6, poca);
		cor = mix(cor, mix(lama_umida, cor_poca, poca * 0.9), exposto);
		aspereza = mix(aspereza, mix(0.35, 0.06, poca), exposto);
		especular = mix(especular, mix(0.45, 0.7, poca), exposto);
	}

	// Acima da preamar: o continente além do quadro (a maré não repinta a terra) —
	// areia seca na beira, depois pasto e mata. Transições largas e quebradas por
	// ruído para a vista alta não mostrar faixas horizontais de cor.
	float dl = lamina_m;
	float terra = smoothstep(-0.03, -0.7, dl + (fino - 0.5) * 0.25);
	vec3 chao_terra = mix(cor_pasto, cor_mata, smoothstep(0.3, 0.7, grande + (medio - 0.5) * 0.5));
	float subida = smoothstep(0.4, 8.0, -dl + (grande - 0.5) * 5.0 + (medio - 0.5) * 2.0);
	chao_terra = mix(cor_areia * 0.95, chao_terra, subida) * (0.85 + 0.3 * fino);
	cor = mix(cor, chao_terra, terra);

	float luz = caustica(chao_m, TIME) * causticas * exp(-max(d, 0.0) * 0.28) * step(0.05, d);
	ALBEDO = cor + vec3(0.95, 1.0, 0.9) * luz;
	ROUGHNESS = aspereza;
	SPECULAR = especular;
}
