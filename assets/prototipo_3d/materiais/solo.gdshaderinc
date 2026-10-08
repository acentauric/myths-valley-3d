// Peças comuns dos shaders de chão (terreno, acostamento das ruas, cruzamentos).
// O hash e o ruído de valor são os mesmos que a praia e o leito do rio usam cada um na
// sua cópia (areia_praia, leito_rio): mesma conta, mesmo recorte, então a borda
// esfarelada de um casa com a do outro.

// SEM sin(): o hash de seno de 43758 amplifica o erro de arredondamento da GPU (o mesmo
// canto de célula, lido de duas células vizinhas, dava dois valores) e, longe da origem do
// vale, cada célula do ruído virava um retângulo de borda reta no chão e na praia (#197,
// #138). Esta conta só multiplica e soma, e o erro de um bit continua de um bit.
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Ruído de valor, de 0 a 1, interpolado com smoothstep.
float ruido(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(c), hash21(c + vec2(1.0, 0.0)), f.x), mix(hash21(c + vec2(0.0, 1.0)), hash21(c + vec2(1.0, 1.0)), f.x), f.y);
}

// Duas oitavas: manchas grandes com a borda quebrada.
float ruido2(vec2 p) {
	return ruido(p) * 0.65 + ruido(p * 2.17 + vec2(17.3, 5.1)) * 0.35;
}

float distancia_segmento(vec2 p, vec2 a, vec2 b) {
	vec2 s = b - a;
	float t = clamp(dot(p - a, s) / max(dot(s, s), 0.0001), 0.0, 1.0);
	return distance(p, a + s * t);
}

// Alfa esfarelado das franjas, em duas escalas (a receita da areia_praia): manchas
// médias deslocam o limiar e o grão fino pontilha a borda. `borda` vai de 0 (fora)
// a 1 (dentro); acima de 0,5 o fragmento fica.
float esfarelar(float borda, vec2 mundo) {
	return borda * 1.35 + (ruido(mundo * 0.5) - 0.5) * 0.6 + (ruido(mundo * 5.0) - 0.5) * 0.35 - 0.18;
}
