shader_type spatial;
// Faixa de areia da praia (geo_region_renderer._add_beach): UV.x vai de 0 (lado da
// terra) a 1 (lado do mar, já dentro d'água). Textura de areia projetada pelo mundo
// (areia_praia_v1.png: grão, ondinhas de vento, conchinhas). A areia úmida escurece
// aos poucos, com borda irregular, e acompanha a maré (`mare_offset_m` do autoload
// Mare: na baixa-mar a linha d'água desce e a faixa quase toda seca). Do lado da
// terra a areia se desfaz em duas escalas — manchas médias com o grão fino
// pontilhando as bordas — em vez de terminar em ilhas duras recortadas. A parte
// submersa da rampa casa de cor com a areia rasa do leito, sem linha escura.

render_mode cull_back;

uniform sampler2D textura_areia : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ladrilho = 5.0;
uniform vec3 tom : source_color = vec3(0.92, 0.88, 0.8);
uniform vec3 umida : source_color = vec3(0.62, 0.55, 0.42);
// Areia rasa do leito_mar já com a tinta clara da beira: a rampa some nessa cor.
uniform vec3 cor_leito : source_color = vec3(0.91, 0.82, 0.56);
// Fração da faixa (a partir da terra) em que a areia se desfaz sobre o chão.
uniform float franja = 0.2;
// Deslocamento da maré em metros: 0 na preamar, até -2,4 na baixa-mar.
uniform float mare_offset_m = 0.0;
varying vec2 mundo;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(c), hash21(c + vec2(1.0, 0.0)), f.x), mix(hash21(c + vec2(0.0, 1.0)), hash21(c + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 areia = texture(textura_areia, mundo / ladrilho).rgb * tom;
	// Umidade: começa no meio da faixa com borda recortada e escurece de vez perto da
	// água; a maré baixa empurra a linha úmida rumo ao mar (a faixa seca cresce).
	float desce = clamp(-mare_offset_m, 0.0, 2.4) * 0.24;
	float recorte = ruido(mundo * 0.22) * 0.22 + ruido(mundo * 1.3) * 0.08;
	float molhada = smoothstep(0.38 + recorte + desce, min(0.9 + recorte * 0.5 + desce, 1.05), UV.x);
	vec3 cor = mix(areia, areia * umida * 1.25, molhada);
	// Fim da rampa: debaixo d'água casa com a areia clara do leito; na baixa-mar,
	// exposta, fica só úmida escura — nunca uma linha de cor no encontro.
	float baixa = clamp(-mare_offset_m / 2.4, 0.0, 1.0);
	vec3 alvo_fim = mix(cor_leito, areia * umida * 1.1, baixa);
	float fim = smoothstep(0.84, 0.98, UV.x + recorte * 0.3);
	cor = mix(cor, alvo_fim, fim * 0.85);
	ALBEDO = cor;
	ROUGHNESS = mix(0.95, 0.4, max(molhada, fim));
	SPECULAR = mix(0.3, 0.6, molhada);
	// Lado da terra: a areia raréia até a grama em duas escalas — manchas médias
	// deslocam o limiar e o grão fino pontilha a borda pixel a pixel (dithering),
	// então o recorte do ALPHA_SCISSOR vira um esfarelado orgânico, sem ilhas duras.
	float borda = clamp(UV.x / max(franja, 0.001), 0.0, 1.0);
	float manchas = ruido(mundo * 0.5);
	float graos = ruido(mundo * 5.0);
	ALPHA = borda * 1.35 + (manchas - 0.5) * 0.6 + (graos - 0.5) * 0.35 - 0.18;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
