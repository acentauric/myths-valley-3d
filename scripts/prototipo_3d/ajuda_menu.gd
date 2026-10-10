extends RefCounted
## Textos de ajuda dos campos de AJUSTAR, abertos pelo botão "?" ao lado de cada rótulo.
## Chave: o rótulo em português (o mesmo usado por _slider/_choice). Valor: [pt, en, es].

const TEXTOS := {
	"Idioma": [
		"O idioma escolhido acompanha o menu e a partida. Textos ainda sem tradução aparecem em português; o chinês usa inglês quando disponível. A narração falada continua em português.",
		"Your language choice applies to the menu and the game. Texts awaiting translation appear in Portuguese; Chinese uses English when available. Spoken narration remains in Portuguese.",
		"El idioma elegido se mantiene en el menú y en la partida. Los textos pendientes aparecen en portugués; el chino usa inglés cuando está disponible. La narración hablada sigue en portugués.",
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
		"Volume geral dos sons do lugar: aves, mar, riacho, fogueira e insetos.\n\nCada um desses sons tem ainda um controle próprio na aba Sons, aplicado por cima deste volume geral.",
		"Overall volume of the place's sounds: birds, sea, stream, campfire and insects.\n\nEach of these sounds also has its own control in the Sounds tab, applied on top of this overall volume.",
		"Volumen general de los sonidos del lugar: aves, mar, arroyo, hoguera e insectos.\n\nCada uno de esos sonidos tiene además su propio control en la pestaña Sonidos, aplicado sobre este volumen general.",
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
	"Passagem do tempo": [
		"Velocidade do relógio do vale.\n\nParada: o tempo não anda.\nLenta: 90 segundos reais por hora do jogo.\nNormal: 30 segundos por hora.\nRápida: 10 segundos por hora.\n\nVale no menu, onde o dia começa às 6h30, e dentro do vale. No jogo, o menu do Esc também troca a velocidade.\n\nParada pede confirmação: com o tempo parado, a partida perde as conquistas dali em diante, e a mudança fica no registro do relógio, no save.",
		"Speed of the valley clock.\n\nStopped: time does not move.\nSlow: 90 real seconds per game hour.\nNormal: 30 seconds per hour.\nFast: 10 seconds per hour.\n\nIt applies in the menu, where the day starts at 6:30, and inside the valley. In game, the Esc menu also changes the speed.\n\nStopped asks for confirmation: with time stopped, the game loses achievements from then on, and the change is kept in the clock log, in the save.",
		"Velocidad del reloj del valle.\n\nDetenido: el tiempo no avanza.\nLento: 90 segundos reales por hora de juego.\nNormal: 30 segundos por hora.\nRápido: 10 segundos por hora.\n\nVale en el menú, donde el día empieza a las 6:30, y dentro del valle. En el juego, el menú de Esc también cambia la velocidad.\n\nDetenido pide confirmación: con el tiempo detenido, la partida pierde los logros de ahí en adelante, y el cambio queda en el registro del reloj, en la partida guardada.",
	],
	"Pausar o relógio no jogo": [
		"Se a linha Relógio do menu do Esc pode parar o tempo no meio da partida.\n\nPermitido: parar pede confirmação, porque a partida perde as conquistas dali em diante; a mudança fica no registro do relógio, no save.\nBloqueado: o tempo não para pelo menu. Um relógio já parado sempre pode voltar a correr.",
		"Whether the Clock line in the Esc menu can stop time during a game.\n\nAllowed: stopping asks for confirmation, because the game loses achievements from then on; the change is kept in the clock log, in the save.\nLocked: time cannot be stopped from the menu. A clock that is already stopped can always run again.",
		"Si la línea Reloj del menú de Esc puede detener el tiempo durante la partida.\n\nPermitido: detenerlo pide confirmación, porque la partida pierde los logros de ahí en adelante; el cambio queda en el registro del reloj, en la partida guardada.\nBloqueado: el tiempo no se detiene desde el menú. Un reloj ya detenido siempre puede volver a correr.",
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
	"Cursor do mouse": [
		"Desenho do ponteiro do mouse no menu e no vale. Em todos, a seta aponta e a mão com o dedo indicador aparece onde dá para clicar.\n\nClássico: o primeiro cursor do jogo.\nOuro polido: o ouro de talha, mais fino e legível.\nAzulejo: branco com traço cobalto, como os azulejos da igreja.\nTalha com punho: mão dourada com punho de renda.\nPergaminho: tinta sépia sobre papel.\nLuz do lampião: âmbar aceso, que aparece bem à noite.\n\nA troca vale na hora e fica salva.",
		"Look of the mouse pointer in the menu and in the valley. In every set the arrow points and the hand with the index finger shows where you can click.\n\nClassic: the game's first cursor.\nPolished gold: carved gold, thinner and easier to read.\nTile: white with cobalt lines, like the church tiles.\nCarved with cuff: a golden hand with a lace cuff.\nParchment: sepia ink on paper.\nLantern light: glowing amber that stands out at night.\n\nThe change applies right away and is saved.",
		"Aspecto del puntero del ratón en el menú y en el valle. En todos, la flecha apunta y la mano con el dedo índice aparece donde se puede hacer clic.\n\nClásico: el primer cursor del juego.\nOro pulido: oro tallado, más fino y legible.\nAzulejo: blanco con trazo cobalto, como los azulejos de la iglesia.\nTalla con puño: mano dorada con puño de encaje.\nPergamino: tinta sepia sobre papel.\nLuz del farol: ámbar encendido, que se ve bien de noche.\n\nEl cambio vale al momento y queda guardado.",
	],
	"Tamanho do texto": [
		"Tamanho de todos os textos do jogo: menu, ajustes, janelas, diálogos e HUD.\n\nMédio é o tamanho de fábrica. Pequeno deixa mais espaço na tela; Grande e Muito grande ajudam a ler de longe ou numa tela pequena.\n\nA troca vale na hora e fica salva.",
		"Size of every text in the game: menu, settings, windows, dialogues and HUD.\n\nMedium is the default size. Small leaves more room on screen; Large and Extra large help when reading from afar or on a small screen.\n\nThe change applies right away and is saved.",
		"Tamaño de todos los textos del juego: menú, ajustes, ventanas, diálogos y HUD.\n\nMediano es el tamaño predeterminado. Pequeño deja más espacio en pantalla; Grande y Muy grande ayudan a leer de lejos o en una pantalla pequeña.\n\nEl cambio vale al momento y queda guardado.",
	],
	"Tamanho do HUD": [
		"Tamanho dos botões do canto da tela, no menu e no vale: Home, ajustes, som, relógio, mapa e os demais.\n\nMédio é o tamanho de fábrica, mais discreto. Grande devolve o tamanho antigo, e Muito grande facilita o clique.\n\nA troca vale na hora e fica salva.",
		"Size of the buttons in the corner of the screen, in the menu and in the valley: Home, settings, sound, clock, map and the rest.\n\nMedium is the default, more discreet size. Large brings back the old size, and Extra large makes clicking easier.\n\nThe change applies right away and is saved.",
		"Tamaño de los botones de la esquina de la pantalla, en el menú y en el valle: Inicio, ajustes, sonido, reloj, mapa y los demás.\n\nMediano es el tamaño predeterminado, más discreto. Grande recupera el tamaño anterior, y Muy grande facilita el clic.\n\nEl cambio vale al momento y queda guardado.",
	],
	"Monitor": [
		"Em qual monitor o jogo abre, com mais de um ligado. A lista tem um item por tela, na ordem do sistema, com o tamanho de cada uma.\n\nA janela vai para o monitor escolhido na hora, em tela cheia ou em janela, e a escolha fica salva para as próximas aberturas. O padrão é o monitor principal; uma tela que deixou de existir volta a ele.",
		"Which monitor the game opens on, when more than one is connected. The list has one item per screen, in the system's order, with each one's size.\n\nThe window moves to the chosen monitor right away, in fullscreen or windowed mode, and the choice is saved for the next launches. The default is the primary monitor; a screen that no longer exists falls back to it.",
		"En qué monitor se abre el juego, con más de uno conectado. La lista tiene un elemento por pantalla, en el orden del sistema, con el tamaño de cada una.\n\nLa ventana pasa al monitor elegido al momento, en pantalla completa o en ventana, y la elección queda guardada para las próximas aperturas. El predeterminado es el monitor principal; una pantalla que dejó de existir vuelve a él.",
	],
	"Passos na água": [
		"Sons dos passos quando o personagem anda na água rasa.\n\nOriginal: os sons de sempre.\nNovos: a gravação mais recente dos passos na água.\n\nAo trocar, o som escolhido toca uma vez como prévia.",
		"Sounds of the footsteps when the character walks in shallow water.\n\nOriginal: the usual sounds.\nNew: the most recent recording of the water footsteps.\n\nWhen you switch, the chosen sound plays once as a preview.",
		"Sonidos de los pasos cuando el personaje camina en agua poco profunda.\n\nOriginal: los sonidos de siempre.\nNuevos: la grabación más reciente de los pasos en el agua.\n\nAl cambiar, el sonido elegido suena una vez como muestra.",
	],
	"Nomes dos personagens": [
		"Mostra ou esconde os nomes que aparecem sobre os moradores no vale.\n\nOcultar deixa a cena mais limpa para quem já conhece todo mundo. O tamanho dos nomes tem ajuste próprio em Tamanho de cada interface.",
		"Shows or hides the names that appear above the residents in the valley.\n\nHiding them leaves the scene cleaner for those who already know everyone. The size of the names has its own setting in Individual interface sizes.",
		"Muestra u oculta los nombres que aparecen sobre los habitantes en el valle.\n\nOcultarlos deja la escena más limpia para quien ya conoce a todos. El tamaño de los nombres tiene su propio ajuste en Tamaño de cada interfaz.",
	],
	"Minimapa": [
		"Mostra ou esconde o minimapa do canto da tela dentro do vale.\n\nA escolha vale na hora e fica salva. O tamanho do minimapa tem ajuste próprio em Tamanho de cada interface.",
		"Shows or hides the minimap in the corner of the screen inside the valley.\n\nThe choice applies right away and is saved. The size of the minimap has its own setting in Individual interface sizes.",
		"Muestra u oculta el mapa pequeño de la esquina de la pantalla dentro del valle.\n\nLa elección vale al momento y queda guardada. El tamaño del mapa pequeño tiene su propio ajuste en Tamaño de cada interfaz.",
	],
	"Maré": [
		"Como o mar da baía sobe e desce.\n\nSem maré: a água fica sempre cheia.\nCiclo do lugar: duas altas e duas baixas por dia de jogo, como na baía de verdade; a preamar cai às 7h e às 19h, e a baixa-mar às 13h e à 1h.\nCiclo lento: uma alta e uma baixa por dia de jogo.\nRápida: um ciclo inteiro em cerca de 90 segundos reais, para ver a maré acontecer.\n\nNa baixa-mar a praia seca e a lama aparece.",
		"How the bay's sea rises and falls.\n\nNo tide: the water always stays full.\nPlace cycle: two highs and two lows per game day, like the real bay; high tide at 7 am and 7 pm, low tide at 1 pm and 1 am.\nSlow cycle: one high and one low per game day.\nFast: a whole cycle in about 90 real seconds, to watch the tide happen.\n\nAt low tide the beach dries and the mud shows.",
		"Cómo sube y baja el mar de la bahía.\n\nSin marea: el agua queda siempre llena.\nCiclo del lugar: dos pleamares y dos bajamares por día de juego, como en la bahía de verdad; la pleamar cae a las 7 y a las 19 h, y la bajamar a las 13 y a la 1 h.\nCiclo lento: una pleamar y una bajamar por día de juego.\nRápida: un ciclo entero en unos 90 segundos reales, para ver la marea suceder.\n\nEn la bajamar la playa se seca y aparece el fango.",
	],
	"Sustos": [
		"Os sustos da mata: o vulto que parece fechar o jogo e o rastro do Curupira, cujas pegadas enlouquecem o mapa.\n\nLigados: eles podem acontecer enquanto você anda pelo vale.\nDesligados: a mata fica sossegada.\n\nNa edição do Tripothon os sustos vêm desligados; quem quiser liga aqui.",
		"The forest scares: the shape that seems to close the game and the Curupira's trail, whose footprints drive the map mad.\n\nOn: they may happen while you walk the valley.\nOff: the forest stays calm.\n\nIn the Tripothon edition the scares start off; turn them on here if you want.",
		"Los sustos de la mata: la sombra que parece cerrar el juego y el rastro del Curupira, cuyas huellas enloquecen el mapa.\n\nActivados: pueden ocurrir mientras caminas por el valle.\nDesactivados: la mata queda tranquila.\n\nEn la edición del Tripothon los sustos vienen desactivados; quien quiera los activa aquí.",
	],
	"Noites escuras": [
		"As fases da lua mudam a luz da noite: a cada oito dias de jogo a lua passa de nova a cheia e volta. Na cheia a noite é clara e prateada, com sombras definidas; na nova ela é bem escura, e o lampião, o candeeiro e a fogueira ganham importância.\n\nSim: a escuridão da lua nova é de verdade.\nSuaves: a diferença entre a lua nova e a cheia encolhe, para quem tem monitor escuro.\n\nO HUD, a dica do E e o marcador da missão continuam legíveis nas duas escolhas.",
		"The moon phases change the light of the night: every eight game days the moon goes from new to full and back. On a full moon the night is bright and silvery, with sharp shadows; on a new moon it is very dark, and the lantern, the oil lamp and the bonfire matter more.\n\nYes: the new moon is truly dark.\nSoft: the gap between new and full moon shrinks, for people with a dark monitor.\n\nThe HUD, the E hint and the mission marker stay readable either way.",
		"Las fases de la luna cambian la luz de la noche: cada ocho días de juego la luna pasa de nueva a llena y vuelve. Con luna llena la noche es clara y plateada, con sombras definidas; con luna nueva es muy oscura, y el farol, el candil y la hoguera cobran importancia.\n\nSí: la oscuridad de la luna nueva es de verdad.\nSuaves: la diferencia entre la luna nueva y la llena se reduce, para quien tiene un monitor oscuro.\n\nEl HUD, la pista de la E y el marcador de la misión siguen legibles en las dos opciones.",
	],
	"Dicas dos moradores": [
		"Os moradores ajudam quem está perdido: quando a missão acompanhada não anda por um bom tempo, ou o mesmo erro se repete (a ferramenta fora da mão, por exemplo), o morador que entende do assunto vem até você, diz uma dica curta e volta ao que fazia.\n\nLigadas: a ajuda vem depois de uns minutos sem avanço.\nPoucas: ela demora o dobro, e vem menos vezes.\nDesligadas: ninguém vem; a seta e o caderno (J) continuam valendo.\n\nNunca interrompe uma conversa, a narração ou o Pedro, e cada assunto só volta depois de um bom tempo.",
		"The residents help when you're lost: when the tracked mission doesn't move for a good while, or the same mistake keeps happening (a tool out of your hand, say), the resident who knows the subject walks over, gives a short hint and goes back to what they were doing.\n\nOn: help comes after a few minutes without progress.\nFew: it takes twice as long and comes less often.\nOff: nobody comes; the arrow and the journal (J) still work.\n\nIt never interrupts a conversation, the narration or Pedro, and each subject only comes back after a good while.",
		"Los habitantes ayudan a quien está perdido: cuando la misión seguida no avanza durante un buen rato, o se repite el mismo error (la herramienta fuera de la mano, por ejemplo), el habitante que entiende del asunto se acerca, da una pista corta y vuelve a lo que hacía.\n\nActivadas: la ayuda llega tras unos minutos sin avance.\nPocas: tarda el doble y llega menos veces.\nDesactivadas: nadie viene; la flecha y el cuaderno (J) siguen valiendo.\n\nNunca interrumpe una conversación, la narración ni a Pedro, y cada asunto solo vuelve tras un buen rato.",
	],
	"Legendas do viajante": [
		"O viajante, que é você, comenta em voz baixa o que acontece (a chuva que começa, a mochila cheia, a noite que cai). Quando ele fala, um ícone de ondas de som dourado pulsa sobre a cabeça dele.

Desligadas: só o ícone e a voz, sem texto na tela.
Ligadas: o que ele diz também aparece escrito, numa caixa pequena acima do ícone.

O texto cede a balões, dicas do E e painéis, e o ícone nunca cobre o rosto de ninguém.",
		"The traveler, who is you, mutters about what happens (the rain starting, a full backpack, nightfall). When he speaks, a golden sound-wave icon pulses above his head.

Off: just the icon and the voice, with no text on screen.
On: what he says also appears written, in a small box above the icon.

The text yields to balloons, E hints and panels, and the icon never covers anyone's face.",
		"El viajero, que eres tú, comenta en voz baja lo que pasa (la lluvia que empieza, la mochila llena, la noche que cae). Cuando habla, un icono dorado de ondas de sonido palpita sobre su cabeza.

Desactivadas: solo el icono y la voz, sin texto en pantalla.
Activadas: lo que dice también aparece escrito, en una cajita sobre el icono.

El texto cede ante globos, pistas de la E y paneles, y el icono nunca cubre el rostro de nadie.",
	],
	"Câmera do mouse": [
		"Como o mouse controla a câmera.\n\nLivre: o mouse gira a câmera direto, sem apertar nada, e o cursor fica preso na tela.\nArrastar: o cursor fica visível e a câmera só gira com o botão esquerdo segurado.\nAutomática: a câmera acompanha o caminho que você percorre, com o cursor visível.\n\nDentro do vale, a tecla de alternar a câmera (C, por padrão) percorre os três modos. A escolha fica salva.",
		"How the mouse controls the camera.\n\nFree: the mouse turns the camera directly, with no button, and the cursor stays locked to the screen.\nDrag: the cursor stays visible and the camera only turns while the left button is held.\nAutomatic: the camera follows the path you walk, with the cursor visible.\n\nInside the valley, the camera key (C by default) cycles through the three modes. The choice is saved.",
		"Cómo el ratón controla la cámara.\n\nLibre: el ratón gira la cámara directamente, sin pulsar nada, y el cursor queda atrapado en la pantalla.\nArrastrar: el cursor queda visible y la cámara solo gira con el botón izquierdo mantenido.\nAutomática: la cámara sigue el camino que recorres, con el cursor visible.\n\nDentro del valle, la tecla de cambiar la cámara (C, por defecto) recorre los tres modos. La elección queda guardada.",
	],
	"Atalhos": [
		"A letra que abre cada tela ou faz cada ação no vale. Escolha a letra no seletor; o ↺ volta à letra de fábrica.\n\nW, A, S e D ficam de fora, porque andam e navegam as telas. Se a letra escolhida já era de outra ação, as duas trocam de letra, e nunca fica uma letra com duas funções.\n\nO rodapé de controles e as dicas do jogo mostram as letras escolhidas.",
		"The letter that opens each screen or performs each action in the valley. Pick the letter in the selector; ↺ goes back to the default letter.\n\nW, A, S and D are left out, because they move and navigate the screens. If the chosen letter already belonged to another action, the two swap letters, so a letter never has two jobs.\n\nThe controls bar and the game hints show the chosen letters.",
		"La letra que abre cada pantalla o hace cada acción en el valle. Elige la letra en el selector; ↺ vuelve a la letra de fábrica.\n\nW, A, S y D quedan fuera, porque mueven y navegan las pantallas. Si la letra elegida ya era de otra acción, las dos intercambian letra, y nunca una letra tiene dos funciones.\n\nLa barra de controles y las pistas del juego muestran las letras elegidas.",
	],
	"Golpe de ferramenta (vigor do braço)": [
		"Quanto vigor do braço cada golpe de ferramenta gasta, antes de contar a dureza do alvo e a eficiência do personagem.\n\nO vigor volta com o descanso. Com 0, os golpes saem de graça; valores maiores deixam o trabalho mais cansativo.",
		"How much arm stamina each tool swing spends, before counting the target's hardness and the character's efficiency.\n\nStamina comes back with rest. At 0 swings are free; higher values make the work more tiring.",
		"Cuánta resistencia del brazo gasta cada golpe de herramienta, antes de contar la dureza del objetivo y la eficiencia del personaje.\n\nLa resistencia vuelve con el descanso. Con 0 los golpes son gratis; valores mayores hacen el trabajo más cansado.",
	],
	"Bater (machado, picareta)": [
		"Quanto fôlego gasta cada pancada de machado ou picareta, antes de contar a dureza do alvo e a eficiência do personagem.\n\nAlvo duro custa mais que este valor. Com 0, bater sai de graça.",
		"How much energy each axe or pickaxe blow spends, before counting the target's hardness and the character's efficiency.\n\nA hard target costs more than this value. At 0 hitting is free.",
		"Cuánto aliento gasta cada golpe de hacha o pico, antes de contar la dureza del objetivo y la eficiencia del personaje.\n\nUn objetivo duro cuesta más que este valor. Con 0 golpear es gratis.",
	],
	"Arar": [
		"Quanto fôlego gasta cada pedaço de terra arado, antes de contar a eficiência do personagem.\n\nCom 0, arar sai de graça.",
		"How much energy each plot of ploughed soil spends, before counting the character's efficiency.\n\nAt 0 ploughing is free.",
		"Cuánto aliento gasta cada parcela de tierra arada, antes de contar la eficiencia del personaje.\n\nCon 0 arar es gratis.",
	],
	"Plantar": [
		"Quanto fôlego gasta cada semente plantada, antes de contar a eficiência do personagem.\n\nCom 0, plantar sai de graça.",
		"How much energy each planted seed spends, before counting the character's efficiency.\n\nAt 0 planting is free.",
		"Cuánto aliento gasta cada semilla plantada, antes de contar la eficiencia del personaje.\n\nCon 0 plantar es gratis.",
	],
	"Regar": [
		"Quanto fôlego gasta cada rega, antes de contar a eficiência do personagem.\n\nCom 0, regar sai de graça.",
		"How much energy each watering spends, before counting the character's efficiency.\n\nAt 0 watering is free.",
		"Cuánto aliento gasta cada riego, antes de contar la eficiencia del personaje.\n\nCon 0 regar es gratis.",
	],
	"Colher": [
		"Quanto fôlego gasta cada colheita, antes de contar a eficiência do personagem.\n\nCom 0, colher sai de graça.",
		"How much energy each harvest spends, before counting the character's efficiency.\n\nAt 0 harvesting is free.",
		"Cuánto aliento gasta cada cosecha, antes de contar la eficiencia del personaje.\n\nCon 0 cosechar es gratis.",
	],
	"Rito": [
		"Quanto fôlego gasta cada rito de fé, antes de contar a eficiência do personagem.\n\nÉ o custo mais alto da tabela de fôlego, porque um rito pede o corpo inteiro. Com 0, os ritos saem de graça.",
		"How much energy each rite of faith spends, before counting the character's efficiency.\n\nIt is the highest cost in the energy table, because a rite asks for the whole body. At 0 rites are free.",
		"Cuánto aliento gasta cada rito de fe, antes de contar la eficiencia del personaje.\n\nEs el costo más alto de la tabla de aliento, porque un rito pide el cuerpo entero. Con 0 los ritos son gratis.",
	],
}


const ARQUIVO_INTERFACE := "res://data/interface_tamanhos.json"
const PREFIXO_INTERFACE := "interface:"
## O que fecha o texto de cada interface de "Tamanho de cada interface" (a descrição vem de
## `interface_tamanhos.json`, campo `ajuda`): [pt, en, es].
const FECHO_INTERFACE := [
	"\n\nEscolha de 65% a 150%; 100% é o tamanho de fábrica. A troca vale na hora e fica salva. O ↺ volta ao tamanho de fábrica, e o botão Restaurar todas as interfaces devolve todas de uma vez.",
	"\n\nPick from 65% to 150%; 100% is the default size. The change applies right away and is saved. ↺ goes back to the default size, and the Reset all interfaces button restores all of them at once.",
	"\n\nElige de 65% a 150%; 100% es el tamaño de fábrica. El cambio vale al momento y queda guardado. ↺ vuelve al tamaño de fábrica, y el botón Restaurar todas las interfaces las devuelve todas de una vez.",
]


## A entrada de `interface_tamanhos.json` de uma chave "interface:<componente>" (vazia se não houver).
static func _interface(titulo: String) -> Dictionary:
	if not titulo.begins_with(PREFIXO_INTERFACE):
		return {}
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_INTERFACE))
	if not (dados is Dictionary):
		return {}
	var entrada: Variant = (dados as Dictionary).get(titulo.trim_prefix(PREFIXO_INTERFACE), {})
	return entrada if entrada is Dictionary and (entrada as Dictionary).has("ajuda") else {}


static func tem(titulo: String) -> bool:
	return TEXTOS.has(titulo) or not _interface(titulo).is_empty()


static func texto(titulo: String, idioma: int) -> String:
	if idioma == 3:
		idioma = 1 # Chinês em preparação: ajuda em inglês.
	var interface := _interface(titulo)
	if not interface.is_empty():
		var campo: String = ["ajuda", "ajuda_en", "ajuda_es"][clampi(idioma, 0, 2)]
		return str(interface.get(campo, interface["ajuda"])) + String(FECHO_INTERFACE[clampi(idioma, 0, 2)])
	var textos: Array = TEXTOS.get(titulo, [""])
	return textos[idioma] if idioma < textos.size() else textos[0]
