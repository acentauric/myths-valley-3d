extends RefCounted
## AS FASES DA LUA (#229): a noite deixa de ter sempre a mesma claridade. A fase sai do dia do
## calendário (`Relogio.dia_absoluto()`), num ciclo curto de OITO dias de jogo — o jogador vê a
## variação sem esperar um mês —, e muda a luz da lua, o ambiente, o disco no céu, as estrelas e a
## força das luzes locais (lampião, candeeiro, fogueira, o brilho do viajante).
##
##   dia do ciclo   0      1          2                3                4      5                6                7
##   fase           nova   crescente  quarto crescente  gibosa crescente cheia  gibosa minguante quarto minguante minguante
##   iluminada      0%     15%        50%              85%              100%   85%              50%              15%
##
## NADA NOVO NO SAVE: a fase é derivada do dia, e o dia já está no save. O dia 1 cai no quarto
## crescente (a primeira noite do tutorial tem meia lua, nem breu nem festa); a lua cheia vem no dia 3
## e a nova no dia 7.
##
## "NOITES ESCURAS: SIM / SUAVES" (Ajustes → Cenário): quem tem monitor escuro escolhe Suaves, e a
## diferença entre a nova e a cheia encolhe (SUAVIZA) sem sumir. Guarda em
## `user://preferencias_visuais.cfg`, [interface] noites_suaves.
##
## Funções PURAS sobre o dia e a fase, sem autoload: o céu passa `Relogio.dia_absoluto()`. Assim o
## portão (tests/fases_da_lua.gd) mede a conta sem montar o vale.

const CICLO_DIAS := 8
## O dia 1 do calendário cai no índice 2 do ciclo (quarto crescente).
const DESLOCAMENTO := 2
const NOVA := 0
const CHEIA := 4
const NOMES := ["Lua nova", "Lua crescente", "Quarto crescente", "Gibosa crescente", "Lua cheia",
	"Gibosa minguante", "Quarto minguante", "Lua minguante"]

## Quanto da luz da lua (DirectionalLight3D) cada fase deixa, sobre a energia de sempre (0,26 no
## fundo da noite): a cheia um pouco mais clara que hoje, a nova bem escura.
const LUA_NOVA := 0.22
const LUA_CHEIA := 1.25
## O mesmo para o ambiente da noite (a luz que vem de todo lado).
const AMBIENTE_NOVA := 0.55
const AMBIENTE_CHEIA := 1.08
## Quanto de cada diferença sobra com as noites suaves: 0 = nenhuma, 1 = a escolha de fábrica. A
## nova suave fica em 0,22 + (1 − 0,22) × 0,65 ≈ 0,73 da luz de hoje.
const SUAVIZA := 0.65
## Na lua nova as luzes de 1887 ganham este tanto a mais de energia (lampião, candeeiro, fogueira).
const LUZES_LOCAIS_NA_NOVA := 0.4
## O brilho em volta do viajante (energia da OmniLight3D) na lua nova; some na cheia.
const BRILHO_DO_VIAJANTE := 0.85
const ALCANCE_DO_VIAJANTE := 6.5
## A lua cheia faz sombra definida; abaixo desta iluminação não faz.
const ILUMINACAO_DA_SOMBRA := 0.85

const PREFERENCIAS := "user://preferencias_visuais.cfg"
const SECAO := "interface"
const CHAVE := "noites_suaves"
## As escolhas de Ajustes: o índice é 0 = Sim (escuras), 1 = Suaves.
const ROTULOS := ["Sim", "Suaves"]

static var _suaves_guardado := -1


## O índice do ciclo (0 = nova … 4 = cheia … 7 = minguante) no dia `dia_absoluto` do calendário.
static func indice_do_dia(dia_absoluto: int) -> int:
	return posmod(dia_absoluto - 1 + DESLOCAMENTO, CICLO_DIAS)


## A fase em 0–1 (0 = nova, 0,5 = cheia) no dia `dia_absoluto`.
static func fase_do_dia(dia_absoluto: int) -> float:
	return float(indice_do_dia(dia_absoluto)) / float(CICLO_DIAS)


## Quanto do disco está iluminado (0 na nova, 1 na cheia) para uma fase em 0–1.
static func iluminacao(fase: float) -> float:
	return (1.0 - cos(TAU * fase)) * 0.5


## O nome da fase do dia, traduzido.
static func nome_do_dia(dia_absoluto: int) -> String:
	return String(TranslationServer.translate(NOMES[indice_do_dia(dia_absoluto)]))


## Encolhe a diferença para 1 quando as noites estão suaves.
static func _suavizar(fator: float, suaves: bool) -> float:
	return lerpf(fator, 1.0, SUAVIZA) if suaves else fator


## O multiplicador da energia da luz da lua.
static func fator_da_lua(fase: float, suaves: bool) -> float:
	return _suavizar(lerpf(LUA_NOVA, LUA_CHEIA, iluminacao(fase)), suaves)


## O multiplicador da energia do ambiente da noite.
static func fator_do_ambiente(fase: float, suaves: bool) -> float:
	return _suavizar(lerpf(AMBIENTE_NOVA, AMBIENTE_CHEIA, iluminacao(fase)), suaves)


## O multiplicador da energia das luzes locais: 1 na cheia, mais na nova.
static func fator_das_luzes_locais(fase: float, suaves: bool) -> float:
	var escuro := 1.0 - iluminacao(fase)
	if suaves:
		escuro *= 1.0 - SUAVIZA
	return 1.0 + LUZES_LOCAIS_NA_NOVA * escuro


## A energia do brilho em volta do viajante: só nas noites escuras.
static func brilho_do_viajante(fase: float, suaves: bool) -> float:
	var escuro := 1.0 - iluminacao(fase)
	if suaves:
		escuro *= 1.0 - SUAVIZA
	return BRILHO_DO_VIAJANTE * escuro * escuro


## A cor da luz da lua: azul-prateada na cheia, mais fria e fechada na nova.
static func cor_da_luz(fase: float) -> Color:
	return Color("7f94c4").lerp(Color("b4c8f0"), iluminacao(fase))


## A opacidade da sombra da lua: só na lua cheia (ou quase), e só de noite fechada. `luz` é a
## claridade do dia (0 = fundo da noite). Some devagar ao entardecer, para a sombra não "pular".
static func opacidade_da_sombra(fase: float, luz: float) -> float:
	var cheia := smoothstep(ILUMINACAO_DA_SOMBRA - 0.15, ILUMINACAO_DA_SOMBRA, iluminacao(fase))
	return cheia * (1.0 - smoothstep(0.1, 0.35, luz))


static func suaves() -> bool:
	if _suaves_guardado >= 0:
		return _suaves_guardado == 1
	var valor := false
	var preferencias := ConfigFile.new()
	if preferencias.load(PREFERENCIAS) == OK:
		valor = bool(preferencias.get_value(SECAO, CHAVE, false))
	_suaves_guardado = 1 if valor else 0
	return valor


static func definir_suaves(valor: bool) -> void:
	_suaves_guardado = 1 if valor else 0
	var preferencias := ConfigFile.new()
	preferencias.load(PREFERENCIAS)
	preferencias.set_value(SECAO, CHAVE, valor)
	if preferencias.save(PREFERENCIAS) != OK:
		push_warning("Não foi possível salvar a preferência das noites escuras.")


## Esquece o que a sessão guardou (o portão troca a escolha sem passar pelo arquivo).
static func esquecer_a_escolha() -> void:
	_suaves_guardado = -1
