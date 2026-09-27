extends RefCounted
## Idioma do menu (abertura): português, inglês ou espanhol. Usa o TranslationServer do Godot
## com as frases em português como chave, então Label, Button e OptionButton se
## traduzem sozinhos; textos compostos passam por tr(). Só o menu muda de idioma —
## ao entrar no vale o locale volta ao português e o jogo segue como está.
## Textos vindos de dados (travessia, histórico) usam campos *_en / *_es nos próprios JSON.

const ARQUIVO := "user://preferencias_visuais.cfg"
const LOCALES := ["pt_BR", "en", "es"]
const ROTULOS := ["Português", "English", "Español"]
## Sufixo dos campos traduzidos nos JSON, por índice de idioma.
const SUFIXOS := ["", "_en", "_es"]

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
	"FECHAR": "CLOSE",
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
	"Casa da estrada": "Roadside house",
	# Histórico
	"Histórico": "Changelog",
	"O que mudou no vale a cada versão.": "What changed in the valley with each version.",
	"Idioma, tempo, sons e aparência do vale.": "Language, time, sounds and look of the valley.",
	"Quem faz o vale e de onde ele vem.": "Who makes the valley and where it comes from.",
	"Como funciona este ajuste.": "How this setting works.",
	"Página anterior": "Previous page",
	"Próxima página": "Next page",
	# Ajustes
	"Ajustes": "Settings",
	"Geral": "General",
	"Sons do vale": "Valley sounds",
	"Cenário e tempo": "Scenery and time",
	"Menu": "Menu",
	"Jogo": "Game",
	"Vale": "Valley",
	"Idioma": "Language",
	"Volume": "Volume",
	"Música": "Music",
	"Narração": "Narration",
	"Falas dos personagens": "Character voices",
	"Efeitos e passos": "Effects and footsteps",
	"Ambiente": "Ambience",
	"Cenário do menu": "Menu background",
	"Fonte do menu": "Menu font",
	"Padrão": "Default",
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
	"Cenário": "Scenery",
	"Estilo visual": "Visual style",
	"Tripo (modelos gerados)": "Tripo (generated models)",
	"Procedural (por código)": "Procedural (code-built)",
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
	# Conhecer
	"Por trás do vale": "Behind the valley",
	"Colaboradores": "Contributors",
	"O vale nasceu do encontro entre paisagens, memórias e histórias brasileiras. Entre casas, caminhos e mata, cada lugar convida a uma descoberta.": "The valley was born where Brazilian landscapes, memories and stories meet. Among houses, paths and woods, every place invites a discovery.",
	"Música, narração e efeitos acompanham a travessia e dão voz aos lugares e personagens. Esta é uma primeira visita a esse mundo. Obrigado por caminhar conosco enquanto a jornada cresce.": "Music, narration and sound effects follow the crossing and give voice to places and characters. This is a first visit to this world. Thank you for walking with us while the journey grows.",
	"Myths’ Valley é uma criação da equipe da Alpha Centauri, um spin-off do projeto Batalha de Mitos. Você pode saber mais acessando:": "Myths’ Valley is created by the Alpha Centauri team, a spin-off of the Batalha de Mitos project. You can learn more at:",
	# Travessia
	"A partida": "The departure",
	"A travessia": "The crossing",
	"A chegada": "The arrival",
	"CONTINUAR": "CONTINUE",
	"PULAR": "SKIP",
	"Carregando o vale…": "Loading the valley…",
}

const ES := {
	"Um vale cheio de histórias.": "Un valle lleno de historias.",
	"JOGAR": "JUGAR",
	"EXPLORAR": "EXPLORAR",
	"MAPA": "MAPA",
	"AJUSTAR": "AJUSTES",
	"CONHECER": "ACERCA DE",
	"SAIR": "SALIR",
	"VOLTAR": "VOLVER",
	"CANCELAR": "CANCELAR",
	"FECHAR": "CERRAR",
	"Ver o histórico": "Ver el historial",
	"Desativar": "Silenciar",
	"Ativar": "Activar",
	"Pausar": "Pausar",
	"Retomar": "Reanudar",
	"Sair do jogo?": "¿Salir del juego?",
	"Deseja encerrar Myths’ Valley?": "¿Quieres cerrar Myths’ Valley?",
	"Mapa do vale": "Mapa del valle",
	"1 unidade = %s m": "1 unidad = %s m",
	"N ↑ · roda: zoom · botão direito: mover": "N ↑ · rueda: zoom · botón derecho: mover",
	"Centralizar em %s": "Centrar en %s",
	"Rio": "Río",
	"Pedras": "Rocas",
	"Pier": "Muelle",
	"Cemitério": "Cementerio",
	"Ponte": "Puente",
	"Mirante": "Mirador",
	"Igreja": "Iglesia",
	"Bar": "Bar",
	"Praça": "Plaza",
	"Restaurante": "Restaurante",
	"Fazenda": "Hacienda",
	"Mata": "Bosque",
	"Casa da estrada": "Casa del camino",
	"Histórico": "Historial",
	"O que mudou no vale a cada versão.": "Lo que cambió en el valle en cada versión.",
	"Idioma, tempo, sons e aparência do vale.": "Idioma, tiempo, sonidos y aspecto del valle.",
	"Quem faz o vale e de onde ele vem.": "Quién hace el valle y de dónde viene.",
	"Como funciona este ajuste.": "Cómo funciona este ajuste.",
	"Página anterior": "Página anterior",
	"Próxima página": "Página siguiente",
	"Ajustes": "Ajustes",
	"Geral": "General",
	"Sons do vale": "Sonidos del valle",
	"Cenário e tempo": "Escenario y tiempo",
	"Menu": "Menú",
	"Jogo": "Juego",
	"Vale": "Valle",
	"Idioma": "Idioma",
	"Volume": "Volumen",
	"Música": "Música",
	"Narração": "Narración",
	"Falas dos personagens": "Voces de los personajes",
	"Efeitos e passos": "Efectos y pasos",
	"Ambiente": "Ambiente",
	"Cenário do menu": "Fondo del menú",
	"Fonte do menu": "Fuente del menú",
	"Padrão": "Predeterminada",
	"Parado": "Fijo",
	"Sobrevoo": "Sobrevuelo",
	"Trilha do menu": "Música del menú",
	"Introdução": "Introducción",
	"Menu I": "Menú I",
	"Menu II": "Menú II",
	"Recôncavo": "Recôncavo",
	"Som dos botões": "Sonido de los botones",
	"Original": "Original",
	"Madeira": "Madera",
	"Aves": "Aves",
	"Mar": "Mar",
	"Riacho": "Arroyo",
	"Fogueira": "Hoguera",
	"Insetos e grilos": "Insectos y grillos",
	"Paisagem sonora do menu": "Paisaje sonoro del menú",
	"Silêncio": "Silencio",
	"Mar e aves": "Mar y aves",
	"Cenário": "Escenario",
	"Estilo visual": "Estilo visual",
	"Tripo (modelos gerados)": "Tripo (modelos generados)",
	"Procedural (por código)": "Procedural (por código)",
	"Tempo": "Tiempo",
	"Passagem do tempo": "Paso del tiempo",
	"Parada": "Detenido",
	"Lenta": "Lento",
	"Normal": "Normal",
	"Rápida": "Rápido",
	"Hora inicial": "Hora inicial",
	"Pausar o relógio no jogo": "Pausar el reloj en el juego",
	"Permitido": "Permitido",
	"Bloqueado": "Bloqueado",
	"Madrugada (4h30)": "Madrugada (4:30)",
	"Manhã (7h)": "Mañana (7:00)",
	"Meio-dia": "Mediodía",
	"Tarde (15h)": "Tarde (15:00)",
	"Entardecer (17h30)": "Atardecer (17:30)",
	"Noite (20h30)": "Noche (20:30)",
	"Por trás do vale": "Detrás del valle",
	"Colaboradores": "Colaboradores",
	"O vale nasceu do encontro entre paisagens, memórias e histórias brasileiras. Entre casas, caminhos e mata, cada lugar convida a uma descoberta.": "El valle nació del encuentro entre paisajes, memorias e historias brasileñas. Entre casas, caminos y bosque, cada lugar invita a un descubrimiento.",
	"Música, narração e efeitos acompanham a travessia e dão voz aos lugares e personagens. Esta é uma primeira visita a esse mundo. Obrigado por caminhar conosco enquanto a jornada cresce.": "La música, la narración y los efectos acompañan la travesía y dan voz a los lugares y personajes. Esta es una primera visita a este mundo. Gracias por caminar con nosotros mientras el viaje crece.",
	"Myths’ Valley é uma criação da equipe da Alpha Centauri, um spin-off do projeto Batalha de Mitos. Você pode saber mais acessando:": "Myths’ Valley es una creación del equipo de Alpha Centauri, un spin-off del proyecto Batalha de Mitos. Puedes saber más en:",
	"A partida": "La partida",
	"A travessia": "La travesía",
	"A chegada": "La llegada",
	"CONTINUAR": "CONTINUAR",
	"PULAR": "SALTAR",
	"Carregando o vale…": "Cargando el valle…",
}

## Uma tradução fica registrada só enquanto o menu está no idioma dela: registrada,
## o Godot a usaria como fallback (locale padrão "en") também em português.
static var _traducao: Translation


static func indice() -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) != OK:
		return 0
	return clampi(int(preferencias.get_value("menu", "idioma", 0)), 0, LOCALES.size() - 1)


static func ingles() -> bool:
	return indice() == 1


static func sufixo() -> String:
	return SUFIXOS[indice()]


static func definir(novo: int) -> void:
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("menu", "idioma", clampi(novo, 0, LOCALES.size() - 1))
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar o idioma do menu.")
	aplicar_menu()


## Liga o idioma escolhido enquanto o menu está aberto.
static func aplicar_menu() -> void:
	restaurar_jogo()
	var atual := indice()
	if atual == 0:
		return
	var frases: Dictionary = EN if atual == 1 else ES
	_traducao = Translation.new()
	_traducao.locale = LOCALES[atual]
	for chave: String in frases:
		_traducao.add_message(chave, frases[chave])
	TranslationServer.add_translation(_traducao)
	TranslationServer.set_locale(LOCALES[atual])


## O jogo ainda não tem tradução: ao sair do menu, tudo volta ao português.
static func restaurar_jogo() -> void:
	if _traducao != null and TranslationServer.has_translation(_traducao):
		TranslationServer.remove_translation(_traducao)
	_traducao = null
	TranslationServer.set_locale(LOCALES[0])


## Campo de dados no idioma do menu: `chave_en` / `chave_es` quando existir.
static func campo(dados: Dictionary, chave: String, padrao: Variant = "") -> Variant:
	var traduzida := chave + sufixo()
	if traduzida != chave and dados.has(traduzida):
		return dados[traduzida]
	return dados.get(chave, padrao)
