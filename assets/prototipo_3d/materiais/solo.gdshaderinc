// Peças comuns dos shaders de chão (terreno, acostamento das ruas, cruzamentos).
// O hash e o ruído de valor são os mesmos que a praia, o leito do rio e a foz usam
// cada um na sua cópia (areia_praia, leito_rio, foz_rio): mesma conta, mesmo
// recorte, então a borda esfarelada de um casa com a do outro.

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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
