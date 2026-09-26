extends RefCounted
## Idioma do menu (abertura): português ou inglês. Usa o TranslationServer do Godot
## com as frases em português como chave, então Label, Button e OptionButton se
## traduzem sozinhos; textos compostos passam por tr(). Só o menu muda de idioma —
## ao entrar no vale o locale volta ao português e o jogo segue como está.
## Textos vindos de dados (travessia, histórico) usam campos *_en nos próprios JSON.

const ARQUIVO := "user://preferencias_visuais.cfg"
const LOCALES := ["pt_BR", "en"]
const ROTULOS := ["Português", "English"]

const EN := {
	# Início
	"Um vale cheio de histórias.": "A valley full of stories.",
	"JOGAR": "PLAY",
	"EXPLORAR": "EXPLORE",
	"MAPA": "MAP",
	"AJUSTAR": "SETTINGS",
	"CONHECER": "ABOUT",
	"SAIR": "QUIT",
	"VOLTAR": "BACK",
	"CANCELAR": "CANCEL",
	"Ver o histórico": "View changelog",
	"Desativar": "Mute",
	"Ativar": "Unmute",
	"Pausar": "Pause",
	"Retomar": "Resume",
	# Sair
	"Sair do jogo?": "Quit the game?",
	"Deseja encerrar Myths’ Valley?": "Do you want to close Myths’ Valley?",
	# Mapa
	"Mapa do vale": "Valley map",
	"1 unidade = %s m": "1 unit = %s m",
	"N ↑ · roda: zoom · botão direito: mover": "N ↑ · wheel: zoom · right button: pan",
	"Centralizar em %s": "Center on %s",
	"Rio": "River",
	"Pedras": "Rocks",
	"Pier": "Pier",
	"Cemitério": "Cemetery",
	"Ponte": "Bridge",
	"Mirante": "Lookout",
	"Igreja": "Church",
	"Bar": "Bar",
	"Praça": "Square",
	"Restaurante": "Restaurant",
	"Fazenda": "Farm",
	"Mata": "Woods",
	# Histórico
	"Histórico": "Changelog",
	"Página anterior": "Previous page",
	"Próxima página": "Next page",
	# Ajustes
	"Ajustes": "Settings",
	"Geral": "General",
	"Sons do vale": "Valley sounds",
	"Cenário e tempo": "Scenery and time",
	"Menu": "Menu",
	"Idioma": "Language",
	"Volume": "Volume",
	"Música": "Music",
	"Narração": "Narration",
	"Falas dos personagens": "Character voices",
	"Efeitos e passos": "Effects and footsteps",
	"Ambiente": "Ambience",
	"Cenário do menu": "Menu background",
	"Parado": "Still",
	"Sobrevoo": "Flyover",
	"Trilha do menu": "Menu music",
	"Introdução": "Introduction",
	"Menu I": "Menu I",
	"Menu II": "Menu II",
	"Recôncavo": "Recôncavo",
	"Som dos botões": "Button sounds",
	"Original": "Original",
	"Madeira": "Wood",
	"Aves": "Birds",
	"Mar": "Sea",
	"Riacho": "Stream",
	"Fogueira": "Campfire",
	"Insetos e grilos": "Insects and crickets",
	"Paisagem sonora do menu": "Menu soundscape",
	"Silêncio": "Silence",
	"Mar e aves": "Sea and birds",
	"Cada som tem volume próprio, aplicado sobre o volume geral de Ambiente (aba Geral).": "Each sound has its own volume, applied on top of the overall Ambience volume (General tab).",
	"Cenário": "Scenery",
	"Estilo visual": "Visual style",
	"Tripo (modelos gerados)": "Tripo (generated models)",
	"Procedural (por código)": "Procedural (code-built)",
	"O vale inteiro é construído num só estilo — modelos do Tripo Studio ou tudo por código, até o personagem.": "The whole valley is built in a single style — Tripo Studio models or everything in code, down to the character.",
	"Tempo": "Time",
	"Passagem do tempo": "Time speed",
	"Parada": "Stopped",
	"Lenta": "Slow",
	"Normal": "Normal",
	"Rápida": "Fast",
	"Hora inicial": "Starting time",
	"Pausar o relógio no jogo": "Pause the clock in game",
	"Permitido": "Allowed",
	"Bloqueado": "Locked",
	"Madrugada (4h30)": "Before dawn (4:30)",
	"Manhã (7h)": "Morning (7:00)",
	"Meio-dia": "Noon",
	"Tarde (15h)": "Afternoon (15:00)",
	"Entardecer (17h30)": "Dusk (17:30)",
	"Noite (20h30)": "Night (20:30)",
	"O menu abre sempre no começo do dia e o relógio do canto mostra o dia correndo nesta velocidade.": "The menu always opens at the start of the day, and the corner clock shows the day passing at this speed.",
	# Conhecer
	"Por trás do vale": "Behind the valley",
	"O vale nasceu do encontro entre paisagens, memórias e histórias brasileiras. Entre casas, caminhos e mata, cada lugar convida a uma descoberta.": "The valley was born where Brazilian landscapes, memories and stories meet. Among houses, paths and woods, every place invites a discovery.",
	"Música, narração e efeitos acompanham a travessia e dão voz aos lugares e personagens. Esta é uma primeira visita a esse mundo. Obrigado por caminhar conosco enquanto a jornada cresce.": "Music, narration and sound effects follow the crossing and give voice to places and characters. This is a first visit to this world. Thank you for walking with us while the journey grows.",
	"Myths’ Valley é uma criação da equipe da Alpha Centauri, um spin-off do projeto Batalha de Mitos. Você pode saber mais acessando:": "Myths’ Valley is created by the Alpha Centauri team, a spin-off of the Batalha de Mitos project. You can learn more at:",
	# Travessia
	"A partida": "The departure",
	"A travessia": "The crossing",
	"A chegada": "The arrival",
	"CONTINUAR": "CONTINUE",
	"PULAR": "SKIP",
}

## A tradução inglesa só fica registrada enquanto o menu está em inglês: com ela
## registrada, o Godot a usaria como fallback (locale padrão "en") também em português.
static var _traducao: Translation


static func indice() -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) != OK:
		return 0
	return clampi(int(preferencias.get_value("menu", "idioma", 0)), 0, LOCALES.size() - 1)


static func ingles() -> bool:
	return indice() == 1


static func definir(novo: int) -> void:
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("menu", "idioma", clampi(novo, 0, LOCALES.size() - 1))
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar o idioma do menu.")
	aplicar_menu()


## Liga o idioma escolhido enquanto o menu está aberto.
static func aplicar_menu() -> void:
	if not ingles():
		restaurar_jogo()
		return
	if _traducao == null:
		_traducao = Translation.new()
		_traducao.locale = "en"
		for chave: String in EN:
			_traducao.add_message(chave, EN[chave])
	if not TranslationServer.has_translation(_traducao):
		TranslationServer.add_translation(_traducao)
	TranslationServer.set_locale(LOCALES[1])


## O jogo ainda não tem tradução: ao sair do menu, tudo volta ao português.
static func restaurar_jogo() -> void:
	if _traducao != null and TranslationServer.has_translation(_traducao):
		TranslationServer.remove_translation(_traducao)
	TranslationServer.set_locale(LOCALES[0])


## Campo de dados no idioma do menu: `chave_en` quando em inglês e disponível.
static func campo(dados: Dictionary, chave: String, padrao: Variant = "") -> Variant:
	if ingles() and dados.has(chave + "_en"):
		return dados[chave + "_en"]
	return dados.get(chave, padrao)
