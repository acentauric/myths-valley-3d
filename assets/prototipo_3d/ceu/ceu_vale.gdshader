shader_type sky;
// O céu do vale, acertado a cada quadro por scripts/prototipo_3d/ceu_vale.gd. Antes era
// um ProceduralSkyMaterial: degradê cinza e bege, sem nuvens nem estrelas, e o bege da
// névoa engolia o horizonte. Camadas, de trás para a frente:
//   degradê do zênite à bruma · Via Láctea e estrelas · lua · sol · nuvens (cúmulos de
//   tempo bom e cirros, na passada de meia resolução) · a outra margem da baía.
// Abaixo do horizonte vai o azul do mar distante: é para essa cor que a névoa
// (perspectiva aérea do Environment) leva o mar ao longe, e por isso o mar não vira
// céu no horizonte. disable_fog: a névoa já tira a cor daqui; névoa no céu dobraria.

render_mode use_half_res_pass, disable_fog;

// Direção PARA o sol e para a lua (unitárias), sem a trava de 2° que a luz usa.
uniform vec3 sol_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 lua_dir = vec3(0.0, -1.0, 0.0);
// A fase da lua (#229): 0 = nova, 0,5 = cheia, de volta a 1 (dia do calendário, em ceu_vale.gd);
// o brilho é a fração iluminada do disco (0 na nova, 1 na cheia). A crescente acende à esquerda,
// como no céu do hemisfério sul.
uniform float lua_fase : hint_range(0.0, 1.0) = 0.5;
uniform float lua_brilho : hint_range(0.0, 1.0) = 1.0;
// 0 no fundo da noite, 1 de dia (Dia.luz_do_dia).
uniform float luz : hint_range(0.0, 1.0) = 1.0;
// 1 no crepúsculo: sol perto do horizonte, acima ou pouco abaixo dele.
uniform float horizonte : hint_range(0.0, 1.0) = 0.0;
uniform vec3 cor_zenite : source_color = vec3(0.31, 0.49, 0.74);
uniform vec3 cor_horizonte : source_color = vec3(0.77, 0.83, 0.87);
uniform vec3 cor_sol : source_color = vec3(1.0, 0.94, 0.82);
// Brilho do lado do sol no crepúsculo (latão e telha).
uniform vec3 cor_brilho : source_color = vec3(0.95, 0.62, 0.36);
uniform vec3 cor_mar : source_color = vec3(0.42, 0.55, 0.64);
uniform vec3 cor_nuvem_luz : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cor_nuvem_sombra : source_color = vec3(0.6, 0.66, 0.74);
uniform float cobertura : hint_range(0.0, 1.0) = 0.35;
// Rumo para onde as nuvens andam (XZ do mundo): o alísio de lés-sudeste as leva a oés-noroeste.
uniform vec2 vento = vec2(-0.92, -0.38);
uniform float velocidade_vento = 0.0015;
// Do mundo para a esfera celeste (x no equinócio, z no polo norte celeste): gira com a hora.
uniform mat3 esfera_celeste = mat3(1.0);
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash33(vec3 p3) {
	p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yxx) * p3.zyx);
}

// Ascensão reta e declinação (graus) para a esfera celeste.
vec3 celeste(float ascensao, float declinacao) {
	float a = radians(ascensao);
	float d = radians(declinacao);
	return vec3(cos(d) * cos(a), cos(d) * sin(a), sin(d));
}

float janela(float x, float de, float ate, float suave) {
	return smoothstep(de, de + suave, x) * (1.0 - smoothstep(ate - suave, ate, x));
}

// Estrelas miúdas: no máximo uma por célula de uma grade 3D em volta da esfera.
float estrelas(vec3 s, float escala, float chance, float raio) {
	vec3 c = floor(s * escala);
	if (hash13(c) > chance) {
		return 0.0;
	}
	vec3 estrela = normalize(c + 0.2 + 0.6 * hash33(c + 17.0));
	float brilho = pow(hash13(c + 5.3), 4.0);
	return smoothstep(raio, raio * 0.2, length(s - estrela)) * (0.2 + 1.6 * brilho);
}

// Uma estrela de verdade: o Cruzeiro do Sul conversa com o cruzeiro da praça.
float estrela(vec3 s, float ascensao, float declinacao, float raio) {
	return smoothstep(raio, raio * 0.15, length(s - celeste(ascensao, declinacao)));
}

vec3 ceu_estrelado(vec3 d) {
	vec3 s = esfera_celeste * d;
	vec3 cor = vec3(0.0);
	// Via Láctea: faixa em volta do polo galáctico, mais larga e clara no bojo de
	// Sagitário, com nuvens e a fenda escura sorteadas por ruído.
	float b = dot(s, celeste(192.86, 27.13));
	float faixa = exp(-b * b / 0.02);
	float bojo = pow(max(dot(s, celeste(266.4, -28.94)), 0.0), 3.0);
	vec2 uv = vec2(atan(s.y, s.x) / TAU * 4.0, s.z * 1.6);
	float n = textureLod(ruido, uv, 0.0).r;
	float n2 = textureLod(ruido, uv * 3.0 + 0.31, 0.0).r;
	float nuvem = smoothstep(0.3, 0.75, n * 0.6 + n2 * 0.4);
	float fenda = smoothstep(0.035, 0.0, abs(b + (n2 - 0.5) * 0.08)) * smoothstep(0.35, 0.6, n);
	cor += vec3(0.62, 0.66, 0.78) * faixa * (0.18 + 0.55 * bojo) * nuvem * (1.0 - 0.75 * fenda);
	// Campo de estrelas: muitas fracas e poucas fortes, com um leve cintilar.
	float pisca = 0.85 + 0.15 * sin(TIME * 2.3 + hash13(floor(s * 160.0)) * 40.0);
	float campo = estrelas(s, 160.0, 0.022 + 0.03 * faixa, 0.0019) + estrelas(s, 60.0, 0.03, 0.0024) * 1.4;
	cor += vec3(0.93, 0.95, 1.0) * campo * pisca;
	// As que se nomeiam: Cruzeiro, as Guardas do Centauro e algumas de primeira grandeza.
	float nomeadas = 0.0;
	nomeadas += estrela(s, 186.65, -63.10, 0.0034) * 2.4; // Acrux
	nomeadas += estrela(s, 191.93, -59.69, 0.0032) * 2.1; // Mimosa
	nomeadas += estrela(s, 187.79, -57.11, 0.0031) * 1.9; // Gacrux
	nomeadas += estrela(s, 183.79, -58.75, 0.0026) * 1.2; // Pálida
	nomeadas += estrela(s, 185.34, -60.40, 0.0021) * 0.7; // Intrometida
	nomeadas += estrela(s, 219.90, -60.83, 0.0036) * 2.6; // Rigil Kentaurus
	nomeadas += estrela(s, 210.96, -60.37, 0.0032) * 2.0; // Hadar
	nomeadas += estrela(s, 95.99, -52.70, 0.0036) * 2.5;  // Canopus
	nomeadas += estrela(s, 24.43, -57.24, 0.0031) * 1.9;  // Achernar
	nomeadas += estrela(s, 344.41, -29.62, 0.0030) * 1.7; // Fomalhaut
	nomeadas += estrela(s, 297.70, 8.87, 0.0030) * 1.7;   // Altair
	nomeadas += estrela(s, 279.23, 38.78, 0.0032) * 2.0;  // Vega
	cor += vec3(0.95, 0.97, 1.0) * nomeadas;
	cor += vec3(1.0, 0.55, 0.38) * estrela(s, 247.35, -26.43, 0.0033) * 2.0; // Antares
	return cor;
}

// Cúmulos de tempo bom num plano baixo e cirros num plano alto, na passada de meia
// resolução. Volta a cor pré-multiplicada e a opacidade. Os cúmulos são poucos, grandes
// e de borda macia (uma só escala larga e um detalhe fraco); somem para a bruma perto do
// horizonte em vez de virar farelo. Os cirros são um véu fino e quase sem contraste,
// esticado só um pouco no rumo do vento: nada de risco reto.
vec4 nuvens(vec3 d, bool cubo) {
	if (d.y <= 0.0) {
		return vec4(0.0);
	}
	float deriva = TIME * velocidade_vento;
	float sobe = smoothstep(0.02, 0.26, d.y);
	float longe = pow(1.0 - d.y, 7.0);
	float luz_sol = smoothstep(-0.06, 0.08, sol_dir.y);
	float cs = max(dot(d, sol_dir), 0.0);
	vec2 para_sol = normalize(sol_dir.xz + vec2(0.0001, 0.0)) * 0.02;

	// Cirros: véu alto de manchas macias, esticadas 2,5x no rumo do vento; rosados no
	// crepúsculo, quando ainda pegam sol depois que ele sumiu para quem está no chão.
	vec2 q = d.xz / (d.y + 0.35);
	vec2 uvc = vec2(dot(q, vento) * 0.035, dot(q, vec2(-vento.y, vento.x)) * 0.09) + vec2(deriva * 0.2, 0.0);
	float fio = texture(ruido, uvc + vec2(0.13, 0.57)).r;
	float cirro = smoothstep(0.52, 0.78, fio) * 0.2 * smoothstep(0.08, 0.45, d.y);
	vec3 cor_cirro = mix(vec3(1.0, 0.99, 0.97), cor_brilho * 1.25 + vec3(0.12, 0.04, 0.12), horizonte);
	cor_cirro *= mix(0.07, 1.0, max(luz, horizonte * 0.6));
	cor_cirro = mix(cor_cirro, cor_horizonte, longe * 0.8);

	// Cúmulos: uma escala larga para a forma e uma fraca para o felpudo da borda; uma
	// amostra deslocada para o sol dá a sombra própria; base escura no miolo e borda
	// prateada perto do sol.
	vec2 p = d.xz / (d.y + 0.14);
	vec2 uv = p * 0.07 + vento * deriva;
	float base = texture(ruido, uv).r;
	float n = base;
	float n_sol = texture(ruido, uv + para_sol).r;
	if (!cubo) {
		vec2 uv_fino = uv * 4.3 - vento * deriva * 0.5;
		n = base * 0.7 + texture(ruido, uv_fino).r * 0.3;
		n_sol = n_sol * 0.7 + texture(ruido, uv_fino + para_sol * 4.3).r * 0.3;
	}
	float limiar = 0.76 - cobertura * 0.4;
	float dens = smoothstep(limiar, limiar + 0.11, n);
	float miolo = smoothstep(limiar + 0.08, limiar + 0.3, n);
	float sombra = clamp((n_sol - n) * 9.0 + 0.4, 0.0, 1.0);
	vec3 cor = mix(cor_nuvem_luz, cor_nuvem_sombra, sombra * 0.8);
	cor = mix(cor, cor_nuvem_sombra * 0.85, miolo * 0.4);
	float borda = dens * (1.0 - miolo);
	cor += cor_sol * borda * (pow(cs, 10.0) * 1.4 + pow(cs, 3.0) * 0.2) * luz_sol;
	cor = mix(cor, cor_horizonte, longe * 0.75);
	float alfa = dens * sobe * mix(0.6, 0.95, luz);

	// Cúmulo por cima do cirro.
	vec3 total = cor_cirro * cirro * (1.0 - alfa) + cor * alfa;
	return vec4(total, alfa + cirro * (1.0 - alfa));
}

// A outra margem da baía: Itaparica, a margem sul com o Paraguaçu e as ilhas do norte.
// Uma faixa baixa, de perfil macio (morros arredondados, sem degrau), que some nas pontas
// e esmaece para a bruma na base. Devolve a cobertura (0–1) com a borda de cima suave.
float outra_margem(vec3 d) {
	float azimute = degrees(atan(d.x, -d.z));
	azimute += azimute < 0.0 ? 360.0 : 0.0;
	float perfil = textureLod(ruido, vec2(azimute / 360.0 * 2.0, 0.21), 0.0).r;
	float fino = textureLod(ruido, vec2(azimute / 360.0 * 7.0, 0.67), 0.0).r;
	float itaparica = janela(azimute, 112.0, 180.0, 22.0) * (0.2 + 0.85 * perfil + 0.1 * fino);
	float sul = janela(azimute, 168.0, 240.0, 20.0) * (0.1 + 0.6 * perfil + 0.08 * fino);
	float ilha = smoothstep(0.5, 0.72, textureLod(ruido, vec2(azimute / 360.0 * 5.0, 0.83), 0.0).r);
	float ilhas = janela(azimute, 50.0, 104.0, 14.0) * ilha * (0.12 + 0.4 * fino);
	float topo = max(max(itaparica, sul), ilhas);
	float altura = degrees(asin(clamp(d.y, -1.0, 1.0)));
	return smoothstep(topo, topo - 0.06, altura) * step(-0.05, altura) * smoothstep(0.0, 0.05, topo);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	bool cubo = AT_CUBEMAP_PASS;
	if (AT_HALF_RES_PASS) {
		vec4 n = nuvens(d, cubo);
		COLOR = n.rgb;
		ALPHA = n.a;
	} else {
		float h = max(d.y, 0.0);
		vec2 rumo = normalize(d.xz + vec2(0.00001, 0.0));
		float lado = dot(rumo, normalize(sol_dir.xz + vec2(0.00001, 0.0))) * 0.5 + 0.5;
		// Degradê: bruma clara rente ao horizonte, cobalto suave no alto.
		vec3 ceu = mix(cor_zenite, cor_horizonte, pow(1.0 - h, 4.5));
		// No crepúsculo o horizonte esquenta do lado do sol e esfria do outro.
		float brilho = horizonte * pow(lado, 2.2) * pow(1.0 - h, 3.0);
		ceu = mix(ceu, cor_brilho, clamp(brilho, 0.0, 1.0));
		float cs = dot(d, sol_dir);
		float luz_sol = smoothstep(-0.12, 0.02, sol_dir.y);
		// Halo largo do sol (mais forte com o sol baixo) e núcleo apertado.
		ceu += cor_brilho * pow(max(cs, 0.0), 6.0) * 0.32 * horizonte * luz_sol;
		ceu += cor_sol * (pow(max(cs, 0.0), 1800.0) * 1.4 + pow(max(cs, 0.0), 90.0) * 0.22) * luz_sol * mix(0.6, 1.0, luz);
		if (d.y >= 0.0) {
			if (!cubo) {
				// Sem lua no céu (a nova) as estrelas aparecem mais.
				ceu += ceu_estrelado(d) * pow(1.0 - luz, 3.0) * smoothstep(0.0, 0.2, d.y) * mix(1.35, 1.0, lua_brilho);
			}
			// Lua: disco com mares sorteados por ruído e um halo frio.
			float cl = dot(d, lua_dir);
			float lua_vis = smoothstep(-0.02, 0.03, lua_dir.y);
			ceu += vec3(0.5, 0.58, 0.75) * (pow(max(cl, 0.0), 900.0) * 0.35 + pow(max(cl, 0.0), 40.0) * 0.06) * (1.0 - luz) * lua_vis * lua_brilho;
			if (!cubo && cl > 0.99) {
				vec3 t = normalize(cross(lua_dir, vec3(0.0, 1.0, 0.0)) + vec3(0.0001, 0.0, 0.0));
				vec2 local = vec2(dot(d, t), dot(d, cross(t, lua_dir))) / 0.0125;
				float r = length(local);
				float mares = smoothstep(0.46, 0.62, textureLod(ruido, local * 0.18 + vec2(0.31, 0.62), 0.0).r);
				vec3 disco = vec3(0.97, 0.95, 0.88) * (1.0 - 0.32 * mares) * (0.8 + 0.2 * sqrt(max(1.0 - r * r, 0.0)));
				// A fase: o terminador é a elipse de meia-largura w·cos(fase). A crescente (fase < 0,5)
				// acende à esquerda, a minguante à direita; na nova o disco some, e nas outras o resto
				// dele fica num cinza de luz refletida da Terra.
				float largura = sqrt(max(1.0 - local.y * local.y, 0.0));
				float terminador = cos(TAU * lua_fase) * largura;
				float dentro_da_luz = lua_fase < 0.5 ? (-terminador - local.x) : (local.x - terminador);
				float iluminado = smoothstep(-0.04, 0.04, dentro_da_luz) * smoothstep(0.0, 0.08, lua_brilho);
				float cinza = 0.04 * smoothstep(0.0, 0.3, lua_brilho) * (1.0 - iluminado);
				float forma = smoothstep(1.0, 0.9, r) * lua_vis * mix(1.0, 0.35, luz);
				ceu = mix(ceu, disco * mix(2.4, 1.05, luz), forma * (iluminado + cinza));
			}
			// Disco do sol (~0,7°).
			if (!cubo) {
				float ang = acos(clamp(cs, -1.0, 1.0));
				ceu = mix(ceu, cor_sol * 16.0, smoothstep(0.0062, 0.0052, ang) * step(0.0, sol_dir.y + 0.006));
			}
			// Nuvens por cima de tudo isso.
			vec4 nuvem = HALF_RES_COLOR;
			ceu = ceu * (1.0 - nuvem.a) + nuvem.rgb;
			// A outra margem: silhueta na bruma, mais escura e azulada que o céu atrás.
			vec3 margem = mix(cor_horizonte, cor_mar * 0.8, 0.55);
			margem = mix(margem, cor_mar * 0.55, horizonte * pow(lado, 2.0) * 0.6);
			ceu = mix(ceu, mix(margem, cor_horizonte, 0.4 * pow(1.0 - smoothstep(0.0, 0.7, degrees(d.y)), 2.0)), outra_margem(d) * 0.85);
		} else {
			// Abaixo do horizonte: o mar distante. Passa da bruma ao azul devagar: o mar do jogo
			// acaba no far da câmera (2 800 u) e, de um ponto alto, uma faixa do céu aparece
			// entre o fim dele e o horizonte; com a transição lenta ela emenda no mar com a névoa
			// (95% dela já é a cor do céu ali) em vez de virar uma tira de papelão.
			// Rente ao horizonte tem a mesma cor do céu de cima (bruma, esquentada do lado do sol).
			vec3 bruma = mix(cor_horizonte, cor_brilho, clamp(horizonte * pow(lado, 2.2), 0.0, 1.0));
			vec3 fundo = mix(cor_mar, cor_brilho, horizonte * pow(lado, 4.0) * 0.22);
			ceu = mix(bruma, fundo, smoothstep(0.0, 0.12, -d.y));
		}
		COLOR = ceu;
	}
}
