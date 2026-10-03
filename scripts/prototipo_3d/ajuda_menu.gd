extends RefCounted
## Textos de ajuda dos campos de AJUSTAR, abertos pelo botão "?" ao lado de cada rótulo.
## Chave: o rótulo em português (o mesmo usado por _slider/_choice). Valor: [pt, en, es].

const TEXTOS := {
	"Idioma": [
		"Idioma dos textos do menu: botões, ajustes, histórico, mapa, créditos e a legenda da travessia.\n\nPor enquanto só o menu é traduzido. Ao entrar no vale, o jogo segue em português, e a narração falada da travessia continua em português em todos os idiomas.",
		"Language of the menu texts: buttons, settings, changelog, map, credits and the crossing captions.\n\nFor now only the menu is translated. Inside the valley the game stays in Portuguese, and the spoken narration of the crossing remains in Portuguese in every language.",
		"Idioma de los textos del menú: botones, ajustes, historial, mapa, créditos y los subtítulos de la travesía.\n\nPor ahora solo se traduce el menú. Dentro del valle el juego sigue en portugués, y la narración hablada de la travesía se mantiene en portugués en todos los idiomas.",
	],
	"Cenário do menu": [
		"O que a câmera faz atrás do menu.\n\nParado: vista fixa da vila.\nSobrevoo: a câmera passeia devagar sobre o vale, num ciclo de cerca de 36 segundos.\n\nA escolha fica salva para as próximas vezes.",
		"What the camera does behind the menu.\n\nStill: a fixed view of the village.\nFlyover: the camera glides slowly over the valley in a loop of about 36 seconds.\n\nThe choice is saved for next time.",
		"Lo que hace la cámara detrás del menú.\n\nFijo: vista fija de la aldea.\nSobrevuelo: la cámara recorre despacio el valle, en un ciclo de unos 36 segundos.\n\nLa elección se guarda para las próximas veces.",
	],
	"Fonte do menu": [
		"Fonte dos textos do menu, dos ajustes e das janelas de histórico e ajuda.\n\nPadrão: a fonte limpa atual, a mais fácil de ler.\nAlmendra: serifada, com ar de manuscrito antigo; é a fonte escolhida no Myths' Valley 2D.\nMiva: fonte em pixel art, também do 2D.\n\nSó o menu muda; a interface dentro do vale segue com a fonte padrão.",
		"Font for the menu, settings, changelog and help windows.\n\nDefault: the current clean font, the easiest to read.\nAlmendra: a serif with an old handwritten feel; it is the font chosen in Myths' Valley 2D.\nMiva: a pixel-art font, also from the 2D.\n\nOnly the menu changes; the interface inside the valley keeps the default font.",
		"Fuente de los textos del menú, los ajustes y las ventanas de historial y ayuda.\n\nPredeterminada: la fuente limpia actual, la más fácil de leer.\nAlmendra: con serifa y aire de manuscrito antiguo; es la fuente elegida en Myths' Valley 2D.\nMiva: una fuente en pixel art, también del 2D.\n\nSolo cambia el menú; la interfaz dentro del valle mantiene la fuente predeterminada.",
	],
	"Trilha do menu": [
		"Música que toca no menu inicial. Trocar a opção já toca a trilha escolhida, para você comparar.\n\nIntrodução, Menu I, Menu II e Recôncavo são quatro temas diferentes; dentro do vale toca a trilha do roçado.",
		"Music played on the main menu. Changing the option plays the chosen track right away so you can compare.\n\nIntroduction, Menu I, Menu II and Recôncavo are four different themes; inside the valley the field theme plays.",
		"Música del menú principal. Al cambiar la opción suena la pista elegida, para que puedas comparar.\n\nIntroducción, Menú I, Menú II y Recôncavo son cuatro temas distintos; dentro del valle suena el tema del campo.",
	],
	"Som dos botões": [
		"Conjunto de sons ao passar o mouse e ao confirmar nos botões do menu.\n\nOriginal: cliques suaves.\nMadeira: toques de madeira, mais rústicos.\n\nAo trocar, o som escolhido toca uma vez como prévia.",
		"Sound set for hovering and confirming menu buttons.\n\nOriginal: soft clicks.\nWood: rustic wooden taps.\n\nWhen you switch, the chosen sound plays once as a preview.",
		"Conjunto de sonidos al pasar el ratón y al confirmar en los botones del menú.\n\nOriginal: clics suaves.\nMadera: golpes de madera, más rústicos.\n\nAl cambiar, el sonido elegido suena una vez como muestra.",
	],
	"Música": [
		"Volume das trilhas musicais, no menu e dentro do vale.\n\nEm 0% a música fica muda sem afetar vozes, efeitos ou ambiente.",
		"Volume of the music tracks, in the menu and inside the valley.\n\nAt 0% the music is silent without affecting voices, effects or ambience.",
		"Volumen de las pistas musicales, en el menú y dentro del valle.\n\nEn 0% la música queda en silencio sin afectar voces, efectos ni ambiente.",
	],
	"Narração": [
		"Volume da narração falada da travessia, quando você escolhe JOGAR.\n\nÉ separado das falas dos personagens, para você poder deixar o narrador mais alto ou mais baixo que os moradores.",
		"Volume of the spoken narration of the crossing, when you choose PLAY.\n\nIt is separate from the character voices, so you can make the narrator louder or quieter than the villagers.",
		"Volumen de la narración hablada de la travesía, cuando eliges JUGAR.\n\nEs independiente de las voces de los personajes, para que puedas dejar al narrador más alto o más bajo que los aldeanos.",
	],
	"Falas dos personagens": [
		"Volume das vozes dos moradores e do Pedro dentro do vale.\n\nAs vozes vêm de perto do personagem que fala: quanto mais longe você estiver, mais baixas ficam, até sumir por volta de 30 metros.",
		"Volume of the villagers' and Pedro's voices inside the valley.\n\nVoices come from the speaking character: the farther away you are, the quieter they get, fading out at about 30 meters.",
		"Volumen de las voces de los aldeanos y de Pedro dentro del valle.\n\nLas voces salen del personaje que habla: cuanto más lejos estés, más bajas se oyen, hasta desaparecer a unos 30 metros.",
	],
	"Efeitos e passos": [
		"Volume dos efeitos sonoros: passos em terra, grama ou areia, corrida e os sons dos botões do menu.",
		"Volume of sound effects: footsteps on dirt, grass or sand, running, and the menu button sounds.",
		"Volumen de los efectos de sonido: pasos sobre tierra, hierba o arena, la carrera y los sonidos de los botones del menú.",
	],
	"Ambiente": [
		"Volume geral dos sons do lugar: aves, mar, riacho, fogueira e insetos.\n\nCada um desses sons tem ainda um controle próprio na aba Sons do vale, aplicado por cima deste volume geral.",
		"Overall volume of the place's sounds: birds, sea, stream, campfire and insects.\n\nEach of these sounds also has its own control in the Valley sounds tab, applied on top of this overall volume.",
		"Volumen general de los sonidos del lugar: aves, mar, arroyo, hoguera e insectos.\n\nCada uno de esos sonidos tiene además su propio control en la pestaña Sonidos del valle, aplicado sobre este volumen general.",
	],
	"Aves": [
		"Canto das aves do Recôncavo. Toca de dia e fica mais forte ao amanhecer e no fim da tarde; à noite some.\n\nTambém é usado na paisagem sonora do menu.",
		"Song of the Recôncavo birds. It plays by day and is stronger at dawn and late afternoon; at night it fades out.\n\nIt is also used in the menu soundscape.",
		"Canto de las aves del Recôncavo. Suena de día y es más fuerte al amanecer y al final de la tarde; de noche desaparece.\n\nTambién se usa en el paisaje sonoro del menú.",
	],
	"Mar": [
		"Maré mansa da baía. Vem do píer: fica mais alta quanto mais perto do mar você está.\n\nTambém é usado na paisagem sonora do menu.",
		"Gentle tide of the bay. It comes from the pier: the closer you are to the sea, the louder it gets.\n\nIt is also used in the menu soundscape.",
		"Marea mansa de la bahía. Sale del muelle: cuanto más cerca del mar estés, más fuerte se oye.\n\nTambién se usa en el paisaje sonoro del menú.",
	],
	"Riacho": [
		"Água correndo nos dois pontos do rio. Só se ouve por perto das margens.",
		"Running water at the two river spots. You only hear it near the banks.",
		"Agua corriendo en los dos puntos del río. Solo se oye cerca de las orillas.",
	],
	"Fogueira": [
		"Estalos da fogueira do terreiro. Só toca quando a fogueira está acesa, à noite, e só por perto dela.",
		"Crackling of the yard campfire. It only plays when the fire is lit, at night, and only near it.",
		"Crepitar de la hoguera del patio. Solo suena cuando está encendida, de noche, y solo cerca de ella.",
	],
	"Insetos e grilos": [
		"Insetos da mata de dia e grilos, sapos e corujas à noite.\n\nPara não cansar, aparecem só em momentos curtos, de 6 a 12 segundos, com pausas de 1 a 2 minutos e meio entre eles.",
		"Woodland insects by day, and crickets, frogs and owls at night.\n\nTo avoid fatigue they only come in short moments of 6 to 12 seconds, with pauses of 1 to 2.5 minutes between them.",
		"Insectos del bosque de día; grillos, sapos y búhos de noche.\n\nPara no cansar, aparecen solo en momentos cortos de 6 a 12 segundos, con pausas de 1 a 2 minutos y medio entre ellos.",
	],
	"Paisagem sonora do menu": [
		"Som de fundo do menu inicial, além da música: silêncio, só o mar, só as aves ou mar e aves juntos.\n\nAo trocar, a opção toca por alguns segundos como prévia.",
		"Background sound of the main menu besides the music: silence, sea only, birds only, or sea and birds together.\n\nWhen you switch, the option plays for a few seconds as a preview.",
		"Sonido de fondo del menú principal, además de la música: silencio, solo el mar, solo las aves, o mar y aves juntos.\n\nAl cambiar, la opción suena unos segundos como muestra.",
	],
	"Estilo visual": [
		"Como o vale inteiro é construído, sempre num estilo só.\n\nTripo: casas, árvores, objetos e personagens em modelos 3D gerados no Tripo Studio.\nProcedural: tudo montado por código com formas simples, até o personagem.\n\nTrocar o estilo reconstrói o cenário do menu na hora.",
		"How the whole valley is built, always in a single style.\n\nTripo: houses, trees, objects and characters as 3D models generated in Tripo Studio.\nProcedural: everything assembled in code from simple shapes, down to the character.\n\nSwitching style rebuilds the menu scenery immediately.",
		"Cómo se construye todo el valle, siempre en un único estilo.\n\nTripo: casas, árboles, objetos y personajes como modelos 3D generados en Tripo Studio.\nProcedural: todo montado por código con formas simples, hasta el personaje.\n\nCambiar el estilo reconstruye el escenario del menú al momento.",
	],
	"Passagem do tempo": [
		"Velocidade do relógio do vale.\n\nLenta: 90 segundos reais por hora do jogo.\nNormal: 30 segundos por hora.\nRápida: 10 segundos por hora.\n\nVale no menu, onde o dia começa às 6h30, e dentro do vale. No jogo, o menu do Esc também troca a velocidade.\n\nPara parar o relógio, use a linha Relógio do menu do Esc. Parar desliga as conquistas daquela partida dali em diante.",
		"Speed of the valley clock.\n\nSlow: 90 real seconds per game hour.\nNormal: 30 seconds per hour.\nFast: 10 seconds per hour.\n\nIt applies in the menu, where the day starts at 6:30, and inside the valley. In game, the Esc menu also changes the speed.\n\nTo stop the clock, use the Clock line in the Esc menu. Stopping it turns off achievements for that game from then on.",
		"Velocidad del reloj del valle.\n\nLento: 90 segundos reales por hora de juego.\nNormal: 30 segundos por hora.\nRápido: 10 segundos por hora.\n\nVale en el menú, donde el día empieza a las 6:30, y dentro del valle. En el juego, el menú de Esc también cambia la velocidad.\n\nPara detener el reloj, usa la línea Reloj del menú de Esc. Detenerlo desactiva los logros de esa partida de ahí en adelante.",
	],
	"Hora inicial": [
		"Hora em que o dia começa quando você entra no vale por JOGAR ou EXPLORAR.\n\nO menu sempre abre no começo do dia; esta hora só vale para o jogo.",
		"Time of day when you enter the valley through PLAY or EXPLORE.\n\nThe menu always opens at the start of the day; this time only applies to the game.",
		"Hora del día en que entras al valle con JUGAR o EXPLORAR.\n\nEl menú siempre abre al comienzo del día; esta hora solo se aplica al juego.",
	],
	"Teclas de movimento": [
		"Quais teclas andam com o personagem no vale.\n\nWASD: só W, A, S e D.\nSetas: só as setas do teclado.\nWASD e setas: as duas funcionam.\n\nO rodapé de controles no jogo mostra as teclas escolhidas. Shift continua correndo e o clique com o botão direito continua levando até o ponto.",
		"Which keys move the character in the valley.\n\nWASD: only W, A, S and D.\nArrows: only the arrow keys.\nWASD and arrows: both work.\n\nThe controls bar in game shows the chosen keys. Shift still runs and right-clicking still walks to a point.",
		"Qué teclas mueven al personaje en el valle.\n\nWASD: solo W, A, S y D.\nFlechas: solo las flechas del teclado.\nWASD y flechas: funcionan las dos.\n\nLa barra de controles del juego muestra las teclas elegidas. Shift sigue corriendo y el clic derecho sigue llevando hasta el punto.",
	],
}


static func tem(titulo: String) -> bool:
	return TEXTOS.has(titulo)


static func texto(titulo: String, idioma: int) -> String:
	var textos: Array = TEXTOS.get(titulo, [""])
	return textos[idioma] if idioma < textos.size() else textos[0]
