# Migração 2D → 3D: o que já existe e como aproveitar

> Escrito em 29 de setembro de 2026, depois de medir os dois projetos arquivo a
> arquivo. Três decisões do autor ordenam este documento:
>
> - **o 3D vira o jogo completo**, e o 2D passa a ser a referência de regras;
> - **a migração é a prioridade**, e a jam de 5/10 entra com o que estiver de pé;
> - **o que o 3D já tem fica.** Ver a regra abaixo, que manda em todas as fases.
>
> Este documento é para trabalhar em cima. Quando uma fase sair, ela é riscada
> aqui, como no [PLANO.md](PLANO.md).

## O board: onde a próxima tarefa é escolhida

Este plano virou **32 issues** no GitHub
([acentauric/myths-valley/issues](https://github.com/acentauric/myths-valley/issues)),
todas com o rótulo `3d`, divididas em dois marcos:

| Marco | Issues | O que é |
|---|---|---|
| [**Jam 04/10**](https://github.com/acentauric/myths-valley/milestone/1) | #1 a #6 | O corte da jam: missões nas âncoras que existem, mochila, fôlego no HUD, teclas das telas novas, o primeiro lote Tripo e a tradução |
| [**Pós-jam**](https://github.com/acentauric/myths-valley/milestone/2) | #7 a #32 | Todo o resto da migração, na ordem das fases abaixo |

**A issue é a unidade de trabalho, e este documento é o porquê dela.** Cada
issue cita a seção daqui de onde saiu e traz os critérios de aceite. Tarefa
nova começa pelo marco da jam enquanto ele tiver issue aberta; o Pós-jam não
tem ordem própria além da de dependência que cada fase declara. Quando uma
fatia fecha uma issue, a fase correspondente é riscada aqui **no mesmo
commit** — board e plano que discordam são dois planos.

Os rótulos de área separam quem pode pegar o quê: `sistemas`, `interface`,
`conteudo`, `mapa`, `modelos-3d` e `qualidade`. As issues `modelos-3d` gastam
crédito do Tripo e exigem o custo aprovado **antes** de gerar.

| Fase deste plano | Issues |
|---|---|
| Fase 2 — sistemas | ~~#10 Vida~~ (feita) · ~~#11 receitas, cozinha, oficina e pesca~~ (feita) · ~~#12 cartas e coleção~~ (feita) · #13 Povoado · ~~#14 luta~~ (feita) · #15 obras e venda (a venda e as obras com efeito saíram; a casa que muda espera #26 e #27) |
| Fase 2.5 — geografia | #22 chapada e vizinhos · #23 rio, vau e lagoa · #24 mata e serra · #25 fazenda e ruínas |
| Fase 3 — missões e enredo | **#1** (jam) · #31 capítulos 6 e 7 |
| Fase 4 — salvar | ~~#7~~ (feita) |
| Fase 6 — interface | ~~#2 mochila~~ (feita) · ~~#3 fôlego~~ (feita) · ~~#4 teclas~~ (feita) · ~~#19 painel~~ (feita) · #20 teia, ~~coleção~~ (feita), arraial · ~~#21 fala com escolha, folheto e amanhecer~~ (feita) |
| Fase 7 — modelos | **#5** comidas e carta (jam) · #26 interiores · #27 roçado e trabalho · #28 bichos · #29 vila · #30 fazenda e ruínas |
| O idioma | **#6** (jam) |
| O som · as estações | #16 · #17 |
| O que não migra (reescrita) | #8 plantação · #9 construções e terrenos |
| Portões | #18 (`_escolha`, `_folheto` e `_amanhecer` atravessaram com a #21) |
| Fora deste plano | #32 conversa por IA — vem do [DECISOES_PROTOTIPO_3D.md](DECISOES_PROTOTIPO_3D.md), prioridade a confirmar |

> **O board foi aberto antes do fechamento da Fase 2** (29/09, 16h; o commit
> `3095afb` é das 17h45), e o contexto de seis issues ficou para trás:
> #7, #10, #11, #12, #14 e #15 dizem que o sistema "não existe" ou "não
> atravessou", e a **regra** delas já roda no vale. O que falta nelas é o
> gatilho do 3D, a tela e o portão — os critérios de aceite continuam valendo
> e continuam abertos. Ao pegar uma delas, comece pelo que já está em
> `prototipo_3d/scripts/compartilhado/` e não por uma cópia nova do 2D.

## A regra que manda em tudo: o 3D não é reescrito

Migrar aqui quer dizer **acrescentar**, e nunca refazer o que já está de pé. O
protótipo 3D tem seis builds de trabalho em cima de assets do Tripo, terreno
geográfico real, dois estilos visuais, dia e noite com as luzes de 1887,
moradores com posto por período e voz, e uma abertura própria. Nada disso é
matéria-prima para ser substituída — é a base que recebe.

Em três frases:

1. **Asset 3D nunca é trocado por arte 2D.** Sprite não substitui GLB, tilemap
   não substitui terreno, e o `CatalogoAssets` continua sendo a única fonte de
   cada peça. A arte do 2D só entra **na interface**, onde o 3D não tem
   equivalente e precisa de um: ícone de item na mochila, folha de cordel, face
   de carta, ícone de nó da teia. No mundo, nenhuma.
   **E o que só existe em 2D vira modelo 3D** — 44 peças, da cama ao casarão da
   fazenda, com o sprite servindo de imagem de referência para o Tripo. É a
   Fase 7, que corre em paralelo com todas as outras desde o primeiro dia,
   porque modelo tem prazo de forno e sistema não espera modelo.
2. **Mecânica que já funciona no 3D continua dona do assunto dela.** O relógio
   do vale é o `Dia`; quem anda com o jogador e narra é o `GuiaPedro`; o HUD é
   o `prototype_hud`; o balão de fala é o do 3D; o mapa é o `mapa_jogo`. O que
   vem do 2D entra **por baixo** — como calendário, como lista de missões, como
   painel a mais —, sem trocar a peça que já existe.
3. **Só nasce do zero o que o 3D não tem.** Inventário, fôlego, vida, teias, fé,
   cartas, coleção, receitas, obras, venda, afinidade e salvamento não existem
   lá. Esses vêm inteiros do 2D, com regra e portão, porque escrever de novo o
   que já tem 47 portões cobrindo seria o retrabalho mais caro possível.

**O teste de cada fatia:** se ela apaga, reescreve ou aposenta código ou asset
que hoje roda no `prototipo_3d/`, ela está errada e precisa ser recortada de
outro jeito. A única exceção prevista está na Fase 3, e é uma constante de
cinco linhas que vira dado — descrita lá, com o que se preserva.

## O que a medição mostrou, e por que ela muda o plano

A pergunta era "quanto do 2D dá para aproveitar". A resposta medida é **quase
tudo**, e por um motivo que não foi sorte: o 2D guarda regra em autoload e
desenho em cena, e nunca misturou os dois.

**Dos 30 autoloads de lógica, 25 não citam um único tipo 2D.** Fôlego, vida,
progressão, as duas teias, as três fés, inventário, cartas, coleção, receitas,
cozinha, oficina, obras, venda, afinidade, povoado, luta, ritos, equipamento,
jornada, relógio, áudio, efeitos, controles, telas e versão: nenhum `Vector2`,
nenhum `Node2D`, nenhum `TileMap`. São 5.320 linhas de regra
que rodam igual num jogo 3D.

Dos cinco restantes, três são falso positivo — `Jogo` usa `Vector2i` para o
tamanho mínimo da janela, `Pesca` usa `Vector2` como **par de números** (espera
mínima e máxima), e `Salvamento` só menciona o tipo em comentário. Sobram
**dois acoplamentos espaciais de verdade**, e é toda a dívida da migração:

| Onde | O quê | O tamanho |
|---|---|---|
| `Missoes.apontar(id, alvo: Vector2)` | o alvo da bússola | uma assinatura |
| `Terrenos` | `Vector2i` de célula, e recebe um `GeradorMundo` | duas funções |

**Dos 17 scripts de interface, 16 são `CanvasLayer` ou `Control`** — que
desenham por cima de um jogo 3D sem saber que ele é 3D. Painel, mochila, teia
de talentos, diálogo, coleção, arraial, vagas, folheto, amanhecer, HUD e menu
inicial somam cerca de 7.600 linhas que atravessam sem reescrita. A exceção é
`mira.gd`, que é `Node2D` e não tem sentido em 3D, e `mapa.gd`, que desenha a
região a partir do tilemap e precisa de outra fonte.

**E os dois mundos já falam a mesma língua de lugar.** O 2D tem 37 acessores
`ponto_*` no `Mundo` — `ponto_do_vau()`, `ponto_da_oficina()`,
`ponto_do_pier()` — e o 3D tem âncoras nomeadas em `world_builder.ancoras`:
Praça, Igreja, Pier, Roçado, Cemitério. Ninguém planejou essa simetria, e é ela
que torna a migração um trabalho de costura em vez de reescrita.

---

## ~~Fase 0 — Trazer os 43 commits que faltam~~ — FEITA (setembro de 2026)

> Em 29/09 a branch não tem nenhum commit da `main` por trazer
> (`git rev-list --count HEAD..origin/main` dá zero). O texto abaixo fica como
> registro de por que isso vinha antes de tudo.

A branch `prototype/myths-valley-3d` carrega uma cópia do jogo 2D na raiz, e
essa cópia parou em **23/09/2026**. Desde então a `main` andou 43 commits: as
nove fatias do playtest (P1 a P9), a fatia 6.1 inteira, e a revisão de 29/09.
Migrar a partir da raiz de hoje seria migrar um jogo que não existe mais.

**O custo disto é quase zero, e isso foi medido:** a branch 3D nunca tocou em
`scripts/`, `data/` nem `scenes/` do 2D. Os 587 arquivos que ela mudou estão em
`prototipo_3d/`, mais ferramentas e documentos. A interseção entre o que os
dois lados mexeram são **dois arquivos**: `README.md` e `AGENTS.md`.

```sh
git checkout prototype/myths-valley-3d
git merge origin/main     # 1181 arquivos entram; resolver README.md e AGENTS.md à mão
```

Os dois `AGENTS.md` não competem: o do 2D fala de portões, commits e chaves; o
do 3D fala de Tripo, pipeline de assets e do vale vivo. O resultado é a união
dos dois, com uma linha dizendo qual seção vale para qual projeto.

**Risco para a demo: nenhum.** Nada disso entra em `prototipo_3d/`, que é um
projeto Godot separado, com `project.godot` próprio e `user://` próprio.

---

## ~~Fase 1 — A costura: `Lugares`~~ — FEITA (setembro de 2026)

É a única peça de arquitetura nova que a migração pede, e tudo depende dela.

O contrato é um nó que traduz **nome de lugar** em posição, e cada projeto
implementa o dele:

```gdscript
# Contrato (o mesmo nos dois projetos)
func ponto(nome: String) -> Variant   # Vector2 no 2D, Vector3 no 3D
func existe(nome: String) -> bool
func perto_de(nome: String, quem, raio: float) -> bool
```

No 2D, `Lugares` embrulha os 37 acessores `ponto_*` que já existem. No 3D, lê
`world_builder.ancoras`. `Missoes.apontar(id, "vau")` passa a receber **nome**,
e quem resolve o nome é o mundo em que o jogo está rodando.

Isto resolve, de uma vez, o único acoplamento real do sistema de missões. E
resolve a bússola: `bussola.gd` já é `Control` e já recebe um ponto pronto —
em 3D ele passa a vir de `unproject_position` da câmera, que é a mesma conta
que o 3D já faz para as placas de nome.

**Onde a lógica compartilhada mora.** Recomendo `compartilhado/` na raiz do
repositório, referenciado pelos dois `project.godot` — e **não** cópia. Cópia
de 5.300 linhas de regra vira duas versões divergentes em três semanas, e o
2D é a referência de regras justamente porque ele tem 47 portões cobrindo
essas regras. Regra copiada é regra sem portão.

> **A Fase 2 descobriu que isso não dá**, e por limitação da engine: `res://` é
> a raiz de cada projeto. O que ficou no lugar foi cópia CONFERIDA byte a byte
> por portão — o parágrafo "Onde a regra compartilhada mora, resolvido na
> prática", na Fase 2, conta como e por quê. A objeção continua de pé e é ela
> que o portão responde.

### O que saiu

| O que entrou | Onde |
|---|---|
| O contrato no 2D: 35 nomes, cada um embrulhando um acessor `ponto_*` do `Mundo`, com `NENHUM` para o que não resolve | `scripts/autoload/lugares.gd` |
| O contrato no 3D: 17 nomes resolvendo em âncora do `world_builder`, e **13 declarados como ainda ausentes**, cada um com a razão escrita | `prototipo_3d/scripts/autoload/lugares.gd` |
| `Missoes.apontar` e `apontar_varios` passam a aceitar **nome ou posição**, resolvendo na hora de apontar | `scripts/autoload/missoes.gd` |
| 54 chamadas de campanha trocaram `_mundo.ponto_do_x()` por `"x"` — tutorial, arraial e fazenda | `scripts/mundo/` |
| Dois portões novos, um de cada lado | `tools/gdscript/testar_lugares.gd`, `prototipo_3d/tests/lugares.gd` |

**O nome resolve AGORA, e não na hora de desenhar.** Metade dos lugares é
móvel — o bicho mais perto, a erva mais perto, o aldeão que anda. Reresolver
a cada quadro faria o losango perseguir um alvo que muda, que é outra missão
e não esta. O nome é o que atravessa mundos; o ponto é o que aquela missão
passou a ter como destino.

**A posição continua aceita, e não é dívida.** Sobraram vinte chamadas que
passam `Vector2`, e elas estão certas: são alvo calculado (a célula que o
jogador acabou de arar) ou ponto que serve para duas coisas ao mesmo tempo —
apontar a bússola e medir distância. Lugar sem nome não ganha nada em virar
texto.

> **O que a fatia ensinou, e vale para as próximas.** Trocar coordenada por
> texto troca erro de compilação por erro calado: `ponto_do_vaU()` não compila,
> `"vaU"` compila e some a bússola. É por isso que o portão do 2D varre o
> **fonte** atrás de todo nome escrito à mão e cobra cada um contra o
> contrato — 29 nomes hoje. Sem essa pergunta, a costura teria trocado um
> acoplamento por uma classe de defeito pior.
>
> E dois portões antigos reprovaram, com razão: `testar_coveiro` e
> `testar_oficios` conferem o **texto** da linha que aponta o losango, e a
> linha mudou. A expectativa deles foi atualizada para a forma nova — o que
> eles medem continua sendo o mesmo.

---

## Fase 2 — Os sistemas que não sabem o que é um lugar

Estes atravessam **sem adaptação nenhuma**. A ordem abaixo é por dependência,
não por importância: cada um só precisa dos anteriores.

| Ordem | Sistema | Linhas | O que o 3D ganha |
|---|---|---|---|
| ~~1a~~ **FEITA** | ~~`Progressao`, `Energia`~~ | 229 | O fôlego, e o cansaço que encurta o passo para 62% — a mesma regra, lida dos mesmos arquivos |
| ~~1b~~ **FEITA** | ~~`Vida`~~ | 217 | A vida que a onça tira, e a queda que leva para casa. A regra veio no fechamento desta fase; **a barra no HUD e a queda que leva à porta da Casa de taipa** vieram com a #10 (`queda.gd`, `tests/vida.gd`). Quem tira vida no vale ainda não existe — é a #14 |
| ~~2~~ **FEITA** | ~~`Inventario`, `Equipamento`, `Catalogo`~~ | 817 | Os 30 espaços, os 10 de mão, o que o corpo veste, e o catálogo com 51 itens. Custou um refactor no 2D: a tecla da mão saiu do `Inventario` e foi para o `Controles` — doze linhas de entrada prendiam 174 de regra |
| ~~2.9~~ **FEITA** | ~~`Relogio`, `Efeitos`~~ | 255 | O calendário — dia, estação, ano — e o efeito que vence em dias. Veio da Fase 5, que era pré-requisito desta fase e não o penúltimo degrau |
| ~~3~~ **FEITA** | ~~`Talentos`, `Fe`, `Ritos`, `Afinidade`, `Jogo`~~ | 1.861 | 37 nós de teia, as três fés com XP separado, e os sete moradores com gosto e desgosto. Os quatro primeiros se citam em círculo e foram juntos; o `Jogo` veio inteiro, com a linha da janela mínima movida para o menu 2D. O `aldeoes.json` veio junto, porque sem ele a afinidade não sabe de quem é cada gosto |
| ~~4 a 8~~ **FEITAS** | ~~`Receitas`, `Cozinha`, `Oficina`, `Pesca`, `Cartas`, `Colecao`, `Luta`, `Obras`, `Venda`~~ + `Vida` e **`Salvamento`** | 2.944 | A receita que se aprende, a bancada, a água que decide o peixe, os pactos, a coleção, o golpe e a ginga, a casa que melhora, o preço por estação — e o SAVE de três vagas, que o vale não tinha |
| — | `Terrenos`, `Povoado` | 719 | **NÃO atravessam.** Dependem do `GeradorMundo`: as divisas são `Rect2i` em coordenada de tile. É a parte de reescrita que o plano sempre apontou |

> **A Fase 2 fechou** (setembro de 2026). São **25 arquivos compartilhados** e
> 24 autoloads do 2D rodando no vale, conferidos byte a byte. O que ficou de
> fora — `Terrenos` e `Povoado` — não é migração pendente: é reescrita, e o
> plano sempre disse isso.
>
> **A ordem prevista aqui errou três vezes**, e as três só apareceram medindo:
> a Fase 5 (o relógio) era pré-requisito desta e não a penúltima; a fé
> dependia do calendário; e o `Salvamento`, que parecia o mais emaranhado,
> atravessou sem uma linha de adaptação porque usa `get_node_or_null` em toda
> parte e degrada sozinho onde um sistema não existe.
>
> **E uma dependência escapou da minha própria medição:** o `Salvamento` usa
> `Versao` para carimbar o save, e o meu regex não listava esse nome. O erro
> apareceu como `Parse Error` no primeiro teste. O conserto ficou melhor que a
> migração teria ficado: em vez de importar o `Versao` do 2D — que carimbaria
> os saves do vale com a versão de outro jogo —, o protótipo ganhou o dele,
> lendo do `historico_3d.json`, que já é onde a versão desta derivação é
> declarada.

A fatia 6 é a que mais rende por linha escrita. O 3D já tem os sete moradores
com posto por período, três falas cada e voz do ElevenLabs — `npcs_3d.json` já
declara que as falas vêm de `data/dialogos/aldeoes.json`, que é arquivo do 2D.
Ligar `Afinidade` transforma um cumprimento a cada 45 segundos numa relação.

### Onde a regra compartilhada mora, resolvido na prática

A recomendação da Fase 1 era `compartilhado/` na raiz, lido pelos dois
`project.godot`. **Não dá**, e a razão é da engine: `res://` é a raiz de cada
projeto, e a raiz do protótipo é `prototipo_3d/`. Link simbólico resolveria e
traz dois problemas piores no Windows — o Git pede `core.symlinks` e modo de
desenvolvedor, e quem clonar sem isso ganha um arquivo de texto com um caminho
dentro em vez do código.

Então é **cópia conferida**, em `prototipo_3d/scripts/compartilhado/`:

- o **dono da regra é o 2D**, sempre; o protótipo tem um espelho;
- `tools\comum\sincronizar-compartilhado.ps1` move o espelho, e com `-Conferir`
  só reclama;
- `testar_compartilhado` compara **byte a byte** e reprova com o nome do
  arquivo que divergiu — foi falsificado, e pega;
- o portão cobra também que o compartilhado **não passe a citar tipo 2D**, que
  é o critério para estar na lista, e que a lista dele e a do sincronizador
  sejam a mesma;
- na `main` não há `prototipo_3d/`, e ali ele passa **dizendo** que não há o
  que conferir.

Isso responde à objeção do próprio plano — regra copiada é regra sem portão —
dando-lhe o portão. O critério para um autoload entrar na lista: não citar
tipo 2D **e** não depender de outro autoload que ainda não atravessou.

#### A DÍVIDA ABERTA: quatro arquivos bifurcaram (01/10/2026)

**Não rode o `sincronizar-compartilhado.ps1` sem decidir isto primeiro.** Ele
copia 2D → 3D, e hoje isso APAGARIA trabalho que só existe no 3D.

O commit `c9fa5ed` fez do machado um item de encaixe de mão, e a regra nasceu no
protótipo, não no 2D. Com ela vieram a reserva da mochila (ferramenta de encaixe
não ocupa espaço de mão), o arrasto para o encaixe e o `e_equipamento` que aceita
ferramenta. Quatro espelhos divergiram do dono:

| arquivo | linhas de diferença |
| --- | --- |
| `catalogo.gd` | 1 (`"encaixe": "maos"` no machado) |
| `inventario.gd` | 32 (reserva, `mover_ferramentas_para_reserva`) |
| `equipamento.gd` | 9 (`e_equipamento` aceita ferramenta de mão) |
| `mochila.gd` | 3 (arrasto para o encaixe) |

O `testar_compartilhado` do 2D **reprova os quatro**, e a mensagem dele manda
rodar o sincronizador — conselho certo pela regra antiga e destrutivo agora.
Medido em 01/10/2026: `compartilhado: 4 falha(s)`.

São duas saídas, e a escolha é do autor:

1. **Promover a regra ao 2D.** O 2D tem `scripts/autoload/equipamento.gd` próprio
   e lê `encaixe`, então o machado passaria a ser item de encaixe lá também — é
   mudança de comportamento no jogo que já roda, não só de arquivo.
2. **Declarar os quatro bifurcados** e tirá-los da lista do sincronizador e do
   portão, assumindo que a mochila do vale é outra. Perde-se o portão que impede
   as duas versões de andarem sozinhas, e é justamente o que ele existe para
   impedir.

Enquanto não se decide, o conserto de defeito que vale para os dois lados entra
nos dois à mão, para a bifurcação não crescer. Foi o que se fez com
`Inventario.quantidade("")`, que matava em qualquer espaço vazio: o mesmo
conserto, idêntico, nas duas cópias — a diferença continuou em 32 linhas.


### O mapa de dependência, medido

A ordem da tabela acima foi escrita de cabeça. Medindo arquivo a arquivo, ela
está quase certa e erra num ponto que importa: **a fé depende do calendário**,
e o calendário é a Fase 5. Quem quiser as teias antes do relógio vai descobrir
isso no meio.

| Autoload | Depende de verdade de | Estado |
|---|---|---|
| `Progressao`, `Energia` | nada | ✅ atravessaram |
| `Inventario`, `Equipamento`, `Catalogo` | entre si | ✅ atravessaram |
| `Relogio` | **nada** — 120 linhas, zero referências | a vez dele |
| `Efeitos` | `Progressao`, `Relogio` | destrava com o relógio |
| `Talentos` | `Progressao`, `Energia`, `Fe`, `Relogio` | preso no nó da fé |
| `Fe` | `Progressao`, `Energia`, `Talentos`, `Ritos`, `Relogio` | idem |
| `Ritos` | `Fe`, `Talentos`, `Efeitos`, `Afinidade`, `Relogio` | idem |
| `Afinidade` | `Fe`, `Ritos`, `Inventario`, `Jogo`, `Relogio` | idem |
| `Missoes` | `Inventario`, `Fe` | espera o nó |

**`Talentos`, `Fe`, `Ritos` e `Afinidade` formam um nó**: os quatro se citam em
círculo, e por isso vão juntos ou não vão. São 1.566 linhas numa fatia só, mais
o `Jogo` que a `Afinidade` puxa.

**E `Jogo` tem uma linha 2D**, uma só: ele força o tamanho mínimo da janela em
640×360, que encolheria a do vale. É o mesmo caso da tecla da mão —
apresentação disfarçada de regra — e sai pelo mesmo caminho.

Duas medições que corrigem a abertura deste documento: `Vida` parecia atravessar
com `Progressao` e `Energia` e não atravessa (chama seis sistemas), e `Relogio`
parecia o mais emaranhado de todos, por ser o conflito da Fase 5, e é o mais
solto que existe — zero dependências.

### A entrada é o que prende a regra, e ela se separa

A medição da abertura contou `Vector2` e `Node2D`, e por isso subestimou o
trabalho: o que prende um autoload ao 2D quase nunca é o tipo, é o
`_unhandled_input`. O `Inventario` não citava um tipo 2D sequer, e mesmo assim
não atravessava — doze linhas dependiam das ações `espaco_N`, que só existem
neste projeto, e do `Telas`, que o protótipo não tem.

A separação é limpa e vale como regra para as próximas fatias:

| Fica no 2D | Atravessa |
|---|---|
| qual tecla aciona | o que a ação faz |
| que telas bloqueiam a tecla | quantos espaços há, o que cabe, o que é estar de mão livre |

No caso da mão, o destino certo foi o `Controles`, que é onde a tecla já vira
ação neste jogo. O `Missoes` tem exatamente o mesmo nó — a tecla Tab que troca
a missão em foco — e vai sair pelo mesmo caminho.

**O que o catálogo ensinou:** ele parecia depender de `Colecao`, `Cozinha`,
`Oficina` e `Pesca`, e cita os quatro **só em comentário**. Medir dependência
por `grep` do nome superestima tanto quanto contar tipo subestima; os dois
erros se cancelaram por acaso, e nenhum dos dois é medida.

**Os ícones ficaram para trás, de propósito.** `Catalogo.icone()` procura em
`assets/sprites/itens/`, que é pasta do 2D, e já devolve `null` com aviso
quando não acha — do mesmo jeito que o `CatalogoAssets` trata peça Tripo não
exportada. As artes de 32px chegam com a mochila, na Fase 6, que é quando
alguém vai olhar para elas.

O que cada sistema precisa do 3D é **um gatilho**, não uma adaptação: quem
chama `Energia.gastar` quando o machado bate, quem chama `Afinidade.presentear`
quando o item muda de mão. Os gatilhos são do 3D e são poucos por sistema.

---

## Fase 2.5 — A geografia da campanha *(bloqueia a Fase 3)*

Esta é a fase que faltava neste plano, e ela é maior que a lista de modelos.

**O vale 3D não tem onde a campanha acontece.** O `world_builder` registra
quinze âncoras — Bar, Casa da estrada, Casa de Carro Quebrado, Casa de taipa,
Cemitério, Fogueira, Igreja, Mirante, Pedras, Píer, Ponte, Poço, Restaurante,
Roçado, Venda —, e a região vai de −1.734 a 1.880 m em X por 2.033 m em Z. É a
vila, e a vila está ótima. Mas metade dos 63 passos do 2D aponta para lugares
que não estão nela:

| Falta no vale 3D | O que acontece lá, no 2D |
|---|---|
| **a chapada de expansão** | onde o arraial do jogador é levantado — a segunda missão do tutorial |
| **os terrenos da Dona Zefa e do Seu Benedito** | a terra que se compra, as cercas, as porteiras, a cabra, a série das ervas |
| **o rio grande e o vau** | a ponte caída, doze tábuas e quatro cordas: a primeira obra do jogo |
| **a lagoa** | "terra com água", e mais um lugar de pescar |
| **a mata funda e a serra ao norte** | onde as criaturas nascem, de onde vem madeira de lei, as três picadas |
| **a fazenda e as ruínas do palacete** | os capítulos 6 e 7 inteiros |
| **a oficina, o canteiro, o curral, a horta** | a cadeia de produção |

Apontar uma missão para uma âncora que não existe é o modo mais silencioso de
a campanha inteira não funcionar — e é por isso que esta fase vem **antes** da
Fase 3, e não depois.

**O caminho já está construído, e não é refazer o mapa.** O
`regioes.json` nasceu com `"regions"` no plural e `active_region`, e
[MAPA_GEOGRAFICO_3D.md](../mundo/MAPA_GEOGRAFICO_3D.md) documenta como acrescentar
região a partir de KML. O que esta fase faz é usar isso:

1. **estender a região atual para o interior e para o norte**, que é onde o 2D
   põe o roçado, os vizinhos e a serra — o KML é desenhado pelo autor, então é
   trabalho de desenho, não de engenharia;
2. **acrescentar as âncoras que faltam**, uma por lugar da tabela acima;
3. **a fazenda pode ser uma segunda região**, e provavelmente deve: ela fica do
   outro lado do rio, é visitada uma vez, e o `regioes.json` já prevê a troca.

**O que esta fase não faz:** mexer na vila. A geografia que existe é fonte
real, medida em KML, e não se altera para caber no desenho do 2D. Onde os dois
discordam, **manda o vale 3D** — e é o passo da missão que se ajusta, porque o
lugar é o que o jogador vê e o passo é texto.

---

## Fase 3 — Missões e enredo — **o sistema FEITO, o conteúdo esperando**

> **O sistema atravessou** (setembro de 2026). `Missoes` e `Jornada` rodam no
> vale, e o `tests/missoes.gd` prova a costura de ponta a ponta: a missão abre,
> `apontar(id, "praca")` produz um `Vector3` de Bom Jesus, a checklist conta as
> tábuas da mochila compartilhada, e o foco gira pela regra — a tecla Tab ficou
> no `Controles` do 2D, como a tecla da mão.
>
> **O conteúdo não atravessou, e por duas razões que não são código.** A
> primeira é a tradução, que é do Ramon: `pedro.json` são 32 KB e
> `aldeoes.json` 26 KB, e cada passo precisa nascer com `_en` e `_es`. A
> segunda é a Fase 2.5: metade dos 63 passos aponta para o vau, a chapada, a
> lagoa e a fazenda, que o vale ainda não tem.
>
> A segunda é menos grave do que parecia, e o portão mede isso: **missão que
> aponta para lugar ausente ABRE mesmo assim**, sem bússola. Missão que não
> abre trava a campanha; missão sem seta só obriga a procurar. Então o
> conteúdo pode chegar antes da geografia, e não depois.
>
> **Um achado que vale para o resto da migração:** o `_resolver` declarava
> `var p: Vector2 = Lugares.ponto(alvo)`. A costura devolve `Vector2` de um
> lado e `Vector3` do outro — declarar o tipo faria ela servir só de um lado,
> que é exatamente o que ela existe para evitar. **Anotação de tipo é
> acoplamento tão real quanto chamada de função, e não aparece em busca
> nenhuma por nome.**

> **ONDE ISTO ESTÁ EM 01/10/2026.** O trecho acima descreve o vale de setembro,
> quando a missão era uma constante dentro do `guia_pedro.gd` e lia o `Missoes`
> do 2D. Mudou duas vezes desde então.
>
> **O 3D tem mecanismo próprio de missão**, por decisão do autor: o
> `CadernoDoVale` (autoload novo), e não o checklist do `Missoes`. A razão é de
> projeto, e está escrita no `caderno_do_vale.gd` — missão nova aqui pode ter
> padrão, formato e ordem diferentes do 2D, e o 2D é referência, não dono. O que
> se perdeu de propósito foi a CHECKLIST: missão do vale tem UMA linha de
> andamento, escrita por quem conduz ("Juntar lenha: 1 de 2").
>
> **A fila virou peça reusável**: `CadeiaDeMissoes` (`scripts/prototipo_3d/`),
> pendurada em cada morador pelo `_pendurar_cadeia` do `Prototype`, lendo um
> `data/missoes_<dono>.json`. Quatro tipos de meta, e cada um nasceu de uma
> missão do 2D que não caberia nos anteriores:
>
> | meta | o que mede | de onde veio |
> | --- | --- | --- |
> | `juntar` | item na mochila | a lenha do tutorial |
> | `derrubar` | pé cortado no mundo | o capim do Damião |
> | `levar` | encontro COM carga, com conta por item | o pirão da Filó; as seis canas da Candinha; as cinco cordas e três tábuas do Tonho |
> | `falar` | encontro sem carga | "fale com o Cosme" |
>
> **Seis cadeias atravessaram**, com portão próprio cada: `missoes_guia` (o
> passeio do Pedro), `missoes_coveiro` (3 passos), `missoes_filo` (2),
> `missoes_zefa` (4), `missoes_tonho` (5) e `missoes_candinha` (2). O
> `tests/ferramentas.gd` varre os seis arquivos e cobra que **toda missão seja
> cumprível**: meta de tipo que a cadeia sabe fazer, material que sai de alvo
> posto ou da bancada com receita nascida sabida, e morador procurado que mora
> aqui. Missão nova entra nessa conta sozinha.
>
> **O que falta, e por quê:**
>
> - **A cadeia da fé** (7 passos, `fe_zefa` a `fe_escolher`) pede o `terreiro` e
>   a `gameleira` como lugares, e os dois estão no `FALTAM_NO_VALE` do `Lugares`.
>   Esta espera a Fase 2.5 de verdade — não é mecanismo, é geografia.
> - **Recompensa**: a `CadeiaDeMissoes` não tem campo para ela. O 2D paga 2
>   peixes assados pela dívida do Tonho, 2 pirões e 2 cocadas pela terra, 3
>   garapas pela cana; os números estão anotados em cada `missoes_*.json` e em
>   `arraial.json` (`recompensas`), esperando o campo.
> - **Tradução**: cada `missoes_*.json` declara `"traducao": "pendente"`. É do
>   Ramon, como `pedro.json` e `aldeoes.json`.
> - **O resto do `arraial.json`** é sistema que o vale já tem: obras
>   (`canteiro_*`, `mirante_*`), luta (`armas_*`, `capoeira_*`, `meta_*`) e a
>   caderneta do arraial, que virou a teia do P.
>
> **Uma armadilha para quem escrever a próxima cadeia:** passo cujo `lugar` não
> resolve o `correr` PULA EM SILÊNCIO — de propósito, para o vale a meio não
> travar numa das âncoras que faltam. A consequência é que um erro de digitação
> não quebra nada: só apaga o meio da missão, e ninguém fica sabendo. Aconteceu
> ao escrever a rede do Tonho, que apontava "oficina" (ausente); o
> `tests/cadeia_do_tonho.gd` pergunta ao `Lugares` antes de jogar por isso.


Depois da Fase 1, o sistema de missões atravessa inteiro: `Missoes` (576
linhas), `Jornada` (104) e os dados.

O 3D tem hoje **cinco missões numa constante** dentro de `guia_pedro.gd`.
O 2D tem 63 passos com título, objetivo, alvo, lista de itens, recompensa e
arremate, separados entre ENREDO e DIA A DIA, com foco que não troca sozinho e
checklist viva — e um portão (`testar_missoes`) que cobra que cada passo diga o
que fazer.

**O conteúdo migra verbatim**, porque já é JSON e já é agnóstico:

| Arquivo | Tamanho | O que é |
|---|---|---|
| `data/dialogos/arraial.json` | 43 KB | As missões do arraial |
| `data/dialogos/pedro.json` | 34 KB | O tutorial inteiro, 27 passos com objetivo |
| `data/dialogos/aldeoes.json` | 26 KB | Os moradores *(o 3D já usa a primeira linha)* |
| `data/enredo/enredo.json` | 6,5 KB | Os capítulos 6 e 7, estruturados |
| `data/dialogos/fazenda.json` | 3,8 KB | A fatia 6.1 |
| `data/construcoes/obras.json` | 14 KB | As 22 obras de casa |
| `data/colecionaveis/*.json` | 13 KB | Cordéis, bichos e sinais |

São 146 KB de conteúdo escrito e revisado, com portão em cima. O trabalho aqui
não é migrar o texto: é **mapear os alvos para âncoras do 3D**, e é por isso
que esta fase vem depois da Fase 1. Um passo que aponta para `ponto_do_vau()`
precisa que o vau exista no vale 3D, ou de uma âncora que faça as vezes dele.

**O que acontece com o `GuiaPedro`, em detalhe** — é a única peça 3D que esta
migração mexe por dentro, e mexe no mínimo:

| Fica como está | Muda |
|---|---|
| seguir o jogador com `SEGUIR_MAX`/`CORRER_ALEM`, andar e correr | a constante `MISSOES`, de cinco linhas, deixa de ser a fonte |
| narrar com a voz do ElevenLabs quando está perto | o texto e o alvo passam a vir de `Missoes` |
| o aviso de que vai escurecer, e a despedida | — |
| os sinais `missao_mudou` e `narrou`, que o HUD já escuta | — |
| tudo que ele herda de `MoradorNPC` | — |

As cinco missões de hoje — praça, capela, casa de pasto, roçado, píer — **não
se perdem**: viram os cinco primeiros passos do arquivo de dados, com o mesmo
texto, o mesmo áudio e o mesmo raio de chegada. Quem chama `Missoes.adicionar`
com elas é o próprio `GuiaPedro`, no `_ready`, até o tutorial do 2D estar
mapeado. A tela não muda de comportamento, e o jogador não percebe a troca —
o que muda é que a lista passa a caber 63 passos em vez de cinco.

---

## ~~Fase 4 — Salvar~~ — FEITA (setembro de 2026, [#7](https://github.com/acentauric/myths-valley/issues/7))

> **O `Salvamento` roda no vale desde o fechamento da Fase 2** (`3095afb`),
> sem uma linha de adaptação, com `Versao` próprio lendo do
> `historico_3d.json`. A #7 ligou o que faz o jogador salvar, sem tocar nele:
>
> | O que entrou | Onde |
> |---|---|
> | As três vagas por baixo da abertura: JOGAR pergunta "qual vaga?"; recomeçar uma ocupada pede o segundo clique | `abertura.gd` |
> | O RETRATO DE FÁBRICA: partida nova não herda a anterior, porque os sistemas são autoloads e sobrevivem à troca de cena | `scripts/autoload/partida.gd` |
> | O estado que só o vale sabe — jogador, giro, **a hora do `Dia`**, o passo do Pedro, os lugares visitados, o bicho que caiu | `prototype.gd`, `estado_para_salvar` |
> | Salva ao cair (o dormir do vale), ao voltar ao menu, ao trocar o estilo e ao fechar a janela | `queda.gd`, `prototype.gd` |
> | O portão: fábrica, sem vaga não salva, ida e volta, queda salva, e todo campo público dos autoloads do 3D guardado ou declarado fora | `tests/salvamento.gd` |
>
> **Salvar ao voltar ao menu e ao fechar é desvio do 2D**, que salva só ao
> dormir e no painel. O vale não tem cama, e o painel J é a #19: sem esses
> dois, quem joga o vale nunca salvaria. Quando a cama e o painel chegarem,
> vale revisitar.
>
> **A hora é do `Dia`, e isso pede cuidado ao carregar.** O save guarda
> `Relogio.minutos`, mas no vale o `Relogio` só espelha o `Dia`: sem devolver
> a hora ao `Dia`, ele a sobrescreve no quadro seguinte. O estado do vale
> leva a hora, e o portão confere.

Antes da Fase 2, o 3D não salvava nada. O 2D tem três vagas, escrita atômica com releitura,
migração de formato em escada e limpeza de conteúdo que sumiu — 810 linhas com
dois portões (`testar_salvamento`, `testar_slots`) e uma página de documentação
([SALVAMENTO.md](../sistemas/SALVAMENTO.md)).

O formato é variante do Godot (`var_to_str`), e não JSON, porque o estado do 2D
é indexado por `Vector2i`. **Em 3D isso não piora: melhora** — a variante
guarda `Vector3` com a mesma naturalidade.

A regra que faz esse sistema não apodrecer vale igual no 3D e deve vir junto:
campo público novo entra em `O_QUE_GUARDAR` ou em `FORA_DO_SAVE` com a razão
escrita, e o portão cobra os dois.

---

## ~~Fase 5 — O relógio, o único lugar em que os dois se sobrepõem~~ — FEITA (setembro de 2026)

É o único assunto que os dois projetos resolvem ao mesmo tempo, e por isso o
único que precisa de decisão — em todo o resto, um tem e o outro não.

| | `Relogio` (2D) | `Dia` (3D) |
|---|---|---|
| hora | inteira, 6h às 2h | contínua, 0–24 |
| dia | conta, e só avança ao dormir ou desmaiar | não existe |
| estação e ano | quatro de 28 dias | não existem |
| velocidade | fixa | escolhida no AJUSTAR (4 velocidades) |
| sol, céu, névoa, lua | por estação, no tilemap | por elevação, no `world_builder` |

O `Dia` diz de si que é "independente dos saves do 2D", e hoje é verdade.

**A recomendação é: o `Dia` continua sendo o relógio do vale, e ganha
calendário.** Ele é quem o `world_builder`, as `luzes_epoca`, o
`ambiente_vale`, a tela de carregamento e o HUD já consultam — trocar o dono da
hora significaria mexer em cinco sistemas que funcionam, para ganhar nada.

O que falta nele não é a hora, é **o que vem depois dela**: contador de dia,
estação, ano, e o dia que só avança quando o jogador dorme. Essas quatro coisas
são a espinha do jogo longo — a planta que cresce, a obra que termina, a fé que
congela e o morador que muda de posto escutam o virar do dia, não a hora.

Então o recorte é aditivo:

| Continua no `Dia`, sem tocar | Entra vindo do `Relogio` |
|---|---|
| hora contínua 0–24, `hora_mudou`, `periodo_mudou` | `dia`, `estacao`, `ano` e os sinais deles |
| as quatro velocidades do AJUSTAR e a hora inicial | a regra de que o dia **termina**: dormir ou desmaiar avança o contador |
| `NASCER`, `POR`, `pausado`, `congelado_na_carga` | a virada de estação a cada 28 dias |
| a curva de sol, o céu, a névoa, a lua, os lampiões | — |

Na prática, o `Relogio` do 2D entra como **calendário** e não como relógio: ele
para de contar hora sozinho e passa a receber do `Dia` o aviso de que o dia
virou. Os sistemas migrados continuam escutando os sinais que já escutavam, com
os mesmos nomes — é o que faz eles atravessarem sem adaptação.

O que isso custa: a nota do `Dia` que diz ser "independente dos saves do 2D"
deixa de valer, porque dia, estação e ano precisam entrar no save. É uma linha
de comentário e um campo em `O_QUE_GUARDAR`.

### O que saiu, e por que custou menos do que esta fase previa

**Zero linhas mudadas no `Relogio`.** A porta já existia: o `pausado`. Com ele
ligado, o `_process` de lá não anda e quem manda na hora é quem está de fora.
O `Dia` liga o `pausado` e escreve `minutos` a cada vez que a hora dele muda —
seis linhas em `dia.gd`, num método chamado de dentro do `definir_hora` que já
existia.

| O que ficou onde | |
|---|---|
| **Hora** | `Dia`, como sempre. Céu, luzes de 1887, som e tela de carregamento não sabem que algo mudou |
| **Dia, estação, ano, dia absoluto** | `Relogio`, que é onde sempre foram contados |
| **A virada do dia** | `Relogio.dormir()`, e **ninguém a chama ainda** — o vale não tem cama. Quando tiver, é uma linha |

`tests/calendario.gd` cobra as duas metades: que os dois concordem na hora, e
que o calendário **não ande sozinho**. A segunda pergunta só funciona com o
`Dia` parado — a primeira versão do teste media com ele andando, viu o
calendário andar junto e acusou o jogo de contar duas vezes. Com o `Dia`
parado, qualquer movimento no calendário só pode ter vindo do `_process` dele,
que é o defeito procurado.

E o `Efeitos` entrou junto, porque só dependia de `Relogio` e `Progressao`. O
portão já cobra o que o calendário veio destravar: um efeito de dois dias vence
depois de duas noites, e não antes.

**O que esta fase revelou sobre a ordem do plano:** a fé depende do calendário.
`Talentos`, `Fe`, `Ritos` e `Afinidade` precisam dele para contar espera, zerar
o que se gasta uma vez por dia e achar a festa na estação certa. A Fase 5 não
era a penúltima — era pré-requisito da 2ᵃ.

---

## Fase 6 — A interface

> **O painel J saiu** ([#19](https://github.com/acentauric/myths-valley/issues/19)),
> em `painel_vale.gd`, e é a primeira tela do 2D a atravessar. Ela entrou como
> **cópia adaptada, declarada** (regra 3 do fim deste documento): o painel do 2D
> conversa com `Telas`, `SlotsTela`, `Terrenos`, `Povoado` e `Dialogo`, que o vale
> não tem, e compartilhá-lo byte a byte pediria mexer no 2D para tirar essas
> conversas dele. A regra de cada aba continua nos autoloads compartilhados; o que
> se copiou é desenho e teclado. **Volta a ser um arquivo só** quando o 2D separar
> o painel do `Telas` e do `SlotsTela` pela mesma porta que o `Vida` usou para a
> peçonha (`esta_lendo`): perguntar a quem foi apresentado, em vez de chamar pelo
> nome.
>
> O que mudou do 2D: a medida e a cara do HUD 3D; as teclas do vale (J, Tab,
> W/S, A/D, E, Esc); o relógio que para é o `Dia`; a aba de Trabalho fica de fora
> até o `Terrenos` e o `Povoado` (#9, #13); a aba Jogo não pergunta vaga (#7) e
> abre pelo botão JOGO do canto, porque no vale o Esc é da câmera. As abas de lugar
> aparecem pela distância até a âncora (`bancadas_vale.gd`): a Venda já tem balcão;
> oficina, canteiro, casa e cozinha estão em `FALTAM`, com a razão, até o lugar
> existir. De passagem, dois defeitos do painel 2D não vieram junto: a checklist
> entrava como linha escolhível e deslocava o índice das missões de baixo, e os
> campos de teste comparavam o índice com o cursor sem descontar as ações.
>
> **A coleção saiu, e mora no almanaque** (parte da [#20](https://github.com/acentauric/myths-valley/issues/20)).
> Primeiro veio como tela própria no L, cópia adaptada da `colecao_tela.gd`; depois,
> a pedido de quem joga, os cordéis, sinais e bichos viraram seções do almanaque,
> que ficou com o L, e as fichas foram para `fichas_da_colecao.gd`, que nenhuma tela
> possui. A tela avulsa, sem tecla e mostrando um pedaço do que o almanaque mostra,
> foi apagada. A ficha mostra a primeira linha do verso, como no 2D, e o cordel
> inteiro se lê no papel desde a #21 (o `Folheto`, ver abaixo). O arraial (P)
> continua na #20.
>
> **Os dados de coleção vieram junto**, e são a primeira cópia de DADO do 2D:
> `data/colecionaveis/` (cordéis, sinais, bichos). O `Colecao` lê `res://`, que
> aqui é a pasta do protótipo, então o arquivo tem de estar dentro dela. O dono
> continua sendo o 2D, e `tests/dados_do_2d.gd` compara as cópias byte a byte
> com o original na raiz — mudou lá sem copiar, reprova aqui.
>
> **Os achados e as cartas saíram** ([#12](https://github.com/acentauric/myths-valley/issues/12)),
> em `achados_vale.gd`, com a ordem das coisas do `Mundo` do 2D: o cordel está no
> lugar do arraial que o `onde` dele descreve (seis dos dez; os outros quatro
> esperam a lagoa, o vau, a ruína e o engenho, declarados), o sinal da Caipora está
> na mata fechada, e a carta ESPERA o sinal. O pacto se firma no lugar do mito com
> o segundo E — a pergunta de Sim e Não é da #21 — e o painel continua firmando e
> desfazendo. As cartas dos moradores chegam pela amizade (#13). A conferência das
> cópias de dado virou um portão só, `tests/dados_do_2d.gd`, com a lista do que o
> protótipo copiou.
>
> **As obras saíram com efeito, e a casa ainda não muda** ([#15](https://github.com/acentauric/myths-valley/issues/15)).
> O `obras.json` veio do 2D, e a aba de obras aparece perto de cada construção
> que o vale já tem (`BancadasVale.OBRAS`): a casa, o armazém, o mirante, o poço e o
> píer. O plano vem antes do material, como no 2D. A obra feita paga o ganho no
> corpo e fica no save; a casa não muda por fora nem por dentro até os modelos
> (#27) e o cômodo (#26) — decisão do usuário: efeito agora, arte depois.
>
> Dois defeitos apareceram no caminho, e nenhum é do vale:
>
> - **O `Obras.executar` do 2D não paga o ganho.** Só o `conceder` (obra dada por
>   morador) chama `_pagar_o_atributo`; a obra que o jogador faz consome o
>   material e não entrega o "+10 de fôlego máximo" que o painel promete. O
>   `testar_obras` de lá confere o `conceder` e não o `executar`. O conserto é no
>   2D; até lá o painel do vale paga (`pagar_o_que_a_obra_da`), e `tests/obras.gd`
>   cobra que pague UMA vez — quando o 2D consertar, ele reprova por dobro.
> - **A ordem dos autoloads do vale estava trocada.** No 2D o `Receitas` sobe
>   depois de `Obras`, `Cozinha` e `Oficina`; no vale subia antes, e o `conferir()`
>   dele encontrava o catálogo de obras vazio — nenhum plano de obra "de começo"
>   nascia sabido. A ordem agora é a do 2D.
>
> **Pesca, cozinha e oficina saíram** ([#11](https://github.com/acentauric/myths-valley/issues/11)).
> A pesca (`pesca_vale.gd`) é o `Mundo._pescar` do 2D no vale: a vara na mão, a
> água à frente e o E; a água é doce na calha de um rio do mapa geográfico e mar
> no resto, e é ela que decide o tanque do `Pesca` — traíra só no rio, robalo só no
> mar. A fisgada afunda a bóia e acende o "!", e ferrar escuta a tecla antes de
> todo mundo. A COZINHA é o fogo do terreiro da Casa de taipa, que faz as vezes do
> fogão até haver cômodo (#26); a OFICINA é uma bancada provisória em caixa cinza
> na beira do roçado, até o modelo dela (#27). Os sons são os da tabela do 2D —
> água no lance, o "regar" na fisgada, "pegar" no peixe —, e a tabela própria é a
> #16.
>
> **A mochila abre no vale** ([#2](https://github.com/acentauric/myths-valley/issues/2)),
> e é a segunda tela do 2D a atravessar — a primeira pela cópia compartilhada
> do `sincronizar-compartilhado.ps1`, e não adaptada. O vale acerta o que é dele: a camada (por cima do HUD) e a
> escala da tela de 640×360 para a janela, as ações de teclado que ela escuta
> (`equipar`, `interagir`, `cancelar`, `mover_*`), e a roda do mouse, que passou
> a trocar o item da mão como no 2D, com o zoom no Ctrl+roda e no +/-. A tecla
> dela entrou na tabela de atalhos com as outras quatro telas, e W/A/S/D ficaram
> fora da troca ([#4](https://github.com/acentauric/myths-valley/issues/4)).
>
> **A fala longa com Sim e Não saiu** ([#21](https://github.com/acentauric/myths-valley/issues/21)),
> em `dialogo_vale.gd`, o autoload `Dialogo`. Entrou como **cópia adaptada,
> declarada**, como o painel: o `dialogo.gd` do 2D chama `Telas.fechar_todas()`,
> liga o `Relogio.pausado` — que aqui é calendário preso, e soltá-lo no fim da
> fala o deixaria andando com o `Dia` parado — e carrega o `TemaIntro` do menu
> para o modo de digitar nome. Veio igual: a API (`falar`, `perguntar`, `ativo`,
> `ocupado`, `abriu`, `terminou`), a fila, as duas travas (o E que não responde
> sem escolha feita e a carência do martelo) e o desenho de 640×360, que o vale
> escala. Ficou de fora o `pedir_texto`. Quem fecha a tela aberta e para o vale
> e o `Dia` é o vale, ouvindo `abriu` e `terminou`; com a caixa aberta, o dono
> das telas não abre nem fecha tela e a barra de mão não ouve o E. **Volta a
> ser um arquivo só** quando o 2D trocar a chamada ao `Telas` e a pausa do
> `Relogio` por quem ouve os dois sinais — a porta que a mochila já usa
> (`alguem_fala`, `abrir_documento`). A primeira pergunta do vale é a do pacto:
> a carta abre a prosa na caixa, depois o preço e o "Firmar?", e o segundo E
> provisório da #12 saiu. O `testar_escolha` do 2D atravessou junto, como
> `tests/escolha.gd` (#18). De passagem: as telas do 2D soltam o `Relogio` ao
> fechar, e com o `Dia` parado ninguém o prendia de novo; pausar e retomar o
> vale agora o prendem.
>
> **O folheto saiu** (#21), e esse atravessou inteiro: `scripts/ui/folheto.gd` é
> o do 2D, e `tests/folheto.gd` o confere byte a byte com o original, junto com
> as perguntas do `testar_folheto` de lá (os dez cordéis cabem no papel). O vale
> só acerta a camada e a escala, e o põe no dono das telas como tela que o MUNDO
> abre — nenhuma tecla é dele: o cordel achado abre o papel, como no
> `Mundo._pegar_cordel`, e o almanaque relê o cordel aberto quando ele é
> escolhido de novo. Sendo tela, o Esc o guarda e a tecla de outra tela troca
> para ela, que é o "[L] coleção" do rodapé dele. No 2D a coleção fica aberta
> embaixo do papel; aqui só uma tela fica aberta, então o almanaque fecha e,
> guardado o papel, reabre onde estava. O dono das telas ganhou o aviso de tela
> que fechou sozinha (`fechou_por_conta`), porque o papel se guarda com o E
> dentro dele, sem passar por lá.
>
> **O amanhecer saiu** (#21), inteiro também: `scripts/ui/amanhecer.gd` é o do
> 2D, conferido byte a byte por `tests/amanhecer.gd`. Entra onde o vale vira o
> dia, que é a queda: o cartão aparece no escuro, acima da tela preta (como no 2D
> fica acima do véu), com o dia novo já virado e os lembretes do 2D — o dia da
> fazenda ou a festa da fé —, e só depois a tela clareia. A fala de quem caiu
> saiu do aviso do HUD para a caixa de fala, como no `Mundo._apagar`. Ao montar
> isso apareceu uma armadilha do Godot 4 que vale para toda tela do 2D: o
> `_unhandled_key_input` vem ANTES do `_unhandled_input`. O cartão e o papel
> ouvem no segundo; o vale (o Esc do menu) e a barra de mão (o E que come)
> ouvem no primeiro. Por isso o cartão para o vale enquanto está na tela (com o
> vale andando, o E que pula a espera batia na árvore ao lado da porta), e a
> barra não come com a fala, o papel ou o cartão abertos. O vale também cala a
> fala aberta ao sair da árvore, porque o `Dialogo` é autoload e ficaria
> esperando um E.

É a fase mais barata em relação ao que entrega, e a que mais precisa da regra
do topo: **a interface do 3D não é substituída, é acrescida.** Toda tela do 2D
que entra é uma tela que o 3D não tem.

**Onde o 3D já resolve, fica o do 3D:**

| O que | Por quê |
|---|---|
| a **abertura** (`abertura.gd`, 874 linhas) | tem identidade própria, vídeo, música e a tela de carregamento "Crônica do Recôncavo". O `menu_inicial` do 2D **não entra**; o que entra por baixo dele são as três vagas de salvamento |
| o **HUD** (`prototype_hud.gd`) | a coluna de botões redondos, o relógio, o estilo. Ele **ganha** widgets — fôlego, vida, missão em foco —, não é trocado pelo `hud.gd` do 2D |
| o **balão de fala 3D** | escolhe entre cinco posições em volta da cabeça para não cobrir ninguém; é melhor que caixa de rodapé para conversa de passagem. Fica para o cumprimento; a caixa do 2D entra só na **fala longa com escolha de Sim e Não**, que o 3D não tem |
| o **mapa** (`mapa_jogo.gd`, `minimapa.gd`) | vista aérea do cenário real, com zoom e marcadores. O `mapa.gd` do 2D **não migra**; dele se aproveitam as ideias que faltam: divisa de terreno por cor e nome do dono |
| a **mira** | o 3D resolve com raycast da câmera. `mira.gd` é mira de tile à frente e não migra |
| os **painéis de AJUSTAR e PERSONAGENS** | são do 3D e não têm par no 2D |

**O que entra inteiro, porque o 3D não tem:** `dialogo` (a fala longa com
escolha), `mochila`, `painel` com as oito abas, `talentos_tela`, `colecao_tela`,
`arraial_tela`, `slots_tela`, `folheto`, `amanhecer`. São `CanvasLayer` e
desenham por cima do 3D sem saber que ele é 3D.

### A medição das nove, e o que ela achou

**As nove têm ZERO nós 2D.** Medidas uma a uma, nenhuma cita `Node2D`,
`Sprite2D`, `TileMap` ou coisa que não exista numa árvore 3D. O que as prende
é outra coisa, e é pouca:

| Tela | Linhas | O que a prende |
|---|---|---|
| `amanhecer` | 163 | nada — só o `Relogio`, que atravessou |
| `slots_tela` | 351 | nada — `Salvamento`, `Jogo`, `Relogio`, `Audio`, todos do outro lado |
| `colecao_tela` | 323 | nada |
| `folheto` | 333 | nada |
| `painel` | 1.221 | nada |
| `arraial_tela` | 362 | os retratos em `assets/sprites/gerados` |
| `talentos_tela` | 1.495 | os 39 ícones em `assets/sprites/talentos` |
| `dialogo` | 388 | o `Telas`, que é o roteador de telas DESTE jogo |
| `mochila` | 846 | o `Tela`, que é o escurecimento e o passeio de câmera |

As duas últimas são o mesmo caso da tecla: `Telas` lista as telas do 2D e
`Tela` é a cortina dele. Saem pelo mesmo caminho quando for a vez delas.

**E a cena não atravessa — só o script.** A `.tscn` de cada tela é um
`CanvasLayer` vazio com o script em cima, e ela aponta para ele por caminho
absoluto, que do outro lado é outro. Não faz falta: um autoload apontado
direto para um script que estende `CanvasLayer` dá exatamente a mesma coisa.
Foi o que a primeira tentativa desta fatia descobriu tentando copiar as duas.

**As fontes já estavam lá.** `Almendra-Bold.ttf` e `miva.ttf` existem em
`prototipo_3d/assets/fonts/` com o mesmo nome — a abertura do vale já as usa.
Coincidência boa, e não planejada: as duas telas que atravessaram primeiro
não precisaram de um asset sequer.

**O que entra adaptado:** a `bussola`, cujo alvo passa a ser projetado na tela
com `unproject_position` — a mesma conta que o 3D já faz para as placas de nome.

**Sobre os ícones.** A mochila, a teia e a coleção mostram arte de item, de nó
e de cordel, e essa arte é 2D em qualquer jogo. Usar os PNG que já existem não
é trazer o visual do 2D para dentro do 3D: é aproveitar ícone de interface, que
é exatamente onde a arte do 2D tem lugar. Nenhum deles aparece no mundo.

---

## Fase 7 — Os modelos que só existem em 2D nascem em 3D

Esta fase **corre em paralelo com todas as outras, desde o primeiro dia**, e
não depois delas. Modelo tem prazo de forno: geração no Tripo, retopologia,
exportação, conferência de escala e colisão, linha no `ORIGEM.md`. Deixar para
quando o sistema estiver pronto é garantir sistema pronto sem nada para mostrar.

**O catálogo do 3D já tem 83 peças** — as 23 espécies de flora, nove
construções, os nove personagens (os sete moradores, o Pedro e o viajante), 23
itens de mão e os adereços da vila. O que falta é o que o 2D criou depois, ou
o que o 2D tem e o vale 3D ainda não precisou.

**A arte 2D é a referência, não o produto.** Cada sprite do 2D vira a imagem de
entrada do Tripo, que é como a casa de Carro Quebrado nasceu. Isso preserva a
direção de arte que já foi decidida e aprovada, e é o jeito de aproveitar o
desenho 2D sem pôr desenho 2D dentro do vale.

### O que falta modelar, por prioridade

**1. Os interiores — o buraco maior, e o que trava mais sistema.** O 3D não tem
cômodo nenhum. Sem interior não há dormir, não há lareira, não há baú, e as
obras (22 delas) não têm o que mudar. São **10 móveis**, todos com arte 2D
pronta para servir de referência:

> `cama` · `mesa` · `banco_tosco` · `bau` · `barril` · `cantareira` ·
> `fogao_barro` · `jirau` · `oratorio` · `rede`

**2. As construções do roçado e do trabalho** — são as que o tutorial e a
cadeia de produção citam passo a passo:

> `casa_rocado` (e `casa_n1`, `casa_n2`, `casa_n3`, que são ela nos três níveis
> de obra) · `casa_pedro` · `oficina` · `canteiro` · `forno_barro` ·
> `casa_farinha` · `engenho` · `galinheiro` · `terreiro`

**3. Os bichos** — cinco, e sem eles não há luta nem criação:

> `onca` · `caititu` · `jararaca` · `bode` · `galinha`

O catálogo do 3D não tem **nenhum animal terrestre** hoje. Estes precisam de
rig e de clipes (`idle`, `walk`, e o bote para os três da mata), o que os
coloca na trilha `rig-check,rig,retarget` e faz deles os mais caros do lote.

**4. A vila que falta** — o 3D tem capela, igreja, venda, casa de pasto, píer,
ponte, mirante, poço, cruzeiro e túmulo. Faltam:

> `bar` · `cabana_pesca` · `capela_estrada` · `casario_vila_a` ·
> `casario_vila_b` · `cemiterio` (o portão e o muro; o túmulo já existe)

**5. A fazenda e as ruínas — o cenário dos capítulos 6 e 7.** Sem eles não há
onde a história acontecer, e a 6.1 já chega lá:

> `casarao_fazenda` · `portao_fazenda` · `guarita` · `ruina_fachada` ·
> `ruina_muro` · `ruina_palacete` · `mirante_caido`

**6. As comidas e a carta** — itens de mão pequenos, 1K de textura, os mais
baratos do lote:

> `beiju` · `cocada` · `garapa` · `mungunza` · `peixe_assado` · `pirao` ·
> `carta`

**Total: 44 modelos.** Mais os dois itens da fatia 7.3 (`lanca_safira` e
`escudo`) quando ela for escrita — não existem nem em 2D ainda.

### Dois que NÃO viram modelo

- **`casa_rocado_corte`** é a casa em corte, para o 2D mostrar o interior de
  cima. Em 3D o jogador entra: o corte não existe como problema.
- **`portao_fazenda_aberto`** é o segundo sprite do portão. Em 3D é o mesmo
  modelo com as folhas giradas — uma animação, não uma peça.

São um bom lembrete de que nem todo asset 2D tem contrapartida: alguns existem
só para resolver limitação de perspectiva que o 3D não tem.

### Como cada um entra

Vale o pipeline que já está decidido em [ASSETS_TRIPO.md](../arte/ASSETS_TRIPO.md) e
no [AGENTS.md](../../AGENTS.md), sem exceção:

1. imagem de referência limpa, em perspectiva 3/4, a partir do sprite 2D;
2. Modelo HD → Remesh/Retopologia (Malha Smart, Quad) → exportar GLB;
3. textura **1K** para adereço, móvel e item; **2K** só para construção de
   destaque, e para os bichos;
4. uma linha em `PECAS` do `CatalogoAssets` com caminho, medida e colisão —
   nunca instanciar GLB fora do catálogo;
5. o construtor procedural equivalente, porque **os dois estilos não podem
   divergir**: peça que só existe em Tripo deixa o estilo procedural com buraco;
6. linha em `ORIGEM.md` e em [CREDITOS.md](../../assets/CREDITOS.md);
7. testar nos dois estilos antes de commitar.

**Cada lote é aprovado antes de rodar.** Geração consome crédito, e o custo
mostrado pela interface vai na conversa antes do clique — é a regra do
`AGENTS.md`, e 44 modelos com rig não é um número que se gasta sem combinar.

### Enquanto o modelo não existe

O catálogo já resolve isso e a migração se apoia nisso: peça não exportada
imprime `CATALOGO: Peças Tripo ainda não exportadas: …` e fica ausente, com o
morador caindo no humanoide procedural. A regra para esta fase é a mesma
—**nenhum sistema espera modelo**. A lareira pode cozinhar antes de a lareira
existir; a luta pode acontecer contra um caititu de caixa cinza. O modelo
entra depois, numa linha do catálogo, sem tocar no sistema.

---

## As quatro que atravessam todas as fases

Não são fases porque não têm começo e fim: cada fatia das outras encosta nelas.
Estavam faltando neste plano, e é onde um esquecimento sai caro depois.

### O idioma, e é a mais cara das quatro

O 3D fala **três**: `pt_BR`, `en`, `es`. O menu traduz pelo `TranslationServer`
com a frase em português como chave, e o que vem de dado usa campos `_en` e
`_es` no próprio JSON. Hoje isso funciona porque **ao entrar no vale o locale
volta ao português** — o jogo em si nunca precisou traduzir nada.

A migração acaba com essa folga: entram 146 KB de fala, missão e enredo, todos
em português, e todos dentro do vale. São três saídas, e a escolha precisa ser
feita **antes** da Fase 3, não depois:

> **DECIDIDO pelo autor (setembro de 2026): TUDO TRADUZ.** O jogo fala as três
> línguas pré-definidas — pt-BR, inglês e espanhol —, e não só o menu. Não há
> texto de jogador em uma língua só.

O que isso custa, escrito para ninguém se surpreender depois: **o conteúdo
triplica**, e cada texto novo passa a nascer três vezes. Os 63 passos de missão
do 2D, as 27 falas do tutorial, os objetivos, os nomes de item e os arremates —
todos precisam de `_en` e `_es` antes de atravessar.

O que isso ganha, e é o motivo de a decisão ser essa: o vale deixa de ter um
teto de público que nenhuma quantidade de trabalho depois desfaz barato.

**A regra é exigível, e não uma boa intenção.** `tests/idiomas.gd` varre os
arquivos declarados e reprova quando falta `_en` ou `_es` — e também quando a
tradução é **cópia do português**, que é o jeito mais comum de uma tradução
faltar sem parecer que falta. O que ainda não foi traduzido mora numa lista
`FALTAM_TRADUCAO`, com a razão escrita de cada um, no mesmo formato do
`FALTAM_NO_VALE` do `Lugares`: dívida registrada, não dívida esquecida.

**A forma é a que o projeto já usava:** `campo`, `campo_en`, `campo_es` no
mesmo objeto, e `IdiomaMenu.sufixo()` escolhe. Foi assim que o
`historico_3d.json` sempre fez; a decisão estendeu isso a tudo em vez de
inventar um sistema.

**Texto em constante de GDScript não tem como ser traduzido** — e é por isso
que a primeira consequência prática da decisão foi tirar as missões do Pedro
de dentro do código e pô-las num JSON. Toda fatia daqui para frente nasce em
dado pelo mesmo motivo.

**O que falta traduzir, declarado hoje:** as 21 falas dos moradores em
`npcs_3d.json` (com o agravante do `tts`, que leva marcação de interpretação e
pede a voz de cada idioma), as fichas de árvore, os epitáfios do cemitério, e
os dois arquivos grandes que vieram do 2D — `pedro.json` (32 KB, o tutorial
inteiro) e `aldeoes.json` (26 KB, os sete moradores).

> **A tradução é do Ramon** (decisão do autor, setembro de 2026). São 58 KB de
> prosa em registro regional — "Bora pro píer", "casa de pasto", "o pão desta
> terra" —, e isso não é trabalho de tradutor automático nem de quem não tem
> ouvido para o tom. O que a migração entrega é a **estrutura**: o campo nasce
> com `_en` e `_es` previstos, o `IdiomaMenu.campo` já escolhe, o portão já
> cobra, e a lista `FALTAM_TRADUCAO` diz exatamente o que falta e por quê.
> Traduzido um arquivo, ele sai da lista e entra em `TRADUZIDOS` — e a partir
> daí o portão não deixa mais regredir.

### O som

O 2D tem 36 arquivos e um `Audio` que sabe **passo por terreno** — grama,
terra, areia, madeira, água —, porta, machado, picareta e queda de árvore. O
3D tem o `Audio` dele, com camadas de ambiente por proximidade, música por
período e 58 áudios, e é bem mais sofisticado no ambiente.

Os dois não competem: **fica o `Audio` do 3D**, e o que migra é a *tabela* de
efeito por ação do 2D — som de machado, de enxada, de porta, de passo por
terreno. Cada sistema da Fase 2 que ganha uma ação ganha junto a linha de som
dela, e o `Efeitos` do 2D (135 linhas, partícula e sacudida de tela) entra
como fonte das reações que o 3D ainda não tem.

### As estações, que hoje não existem em 3D

A Fase 5 dá calendário ao `Dia`, e no instante em que a estação passa a existir
alguém tem de responder por ela. No 2D é a mata que é repintada. No 3D as
candidatas são a `flora_reconcavo`, a cor da luz do `world_builder` e os loops
do `ambiente_vale`.

**Não é obrigatório na primeira volta** — o calendário funciona sem ninguém
pintar nada, e a planta cresce igual. Mas quatro estações de 28 dias que não
mudam a cara do vale é uma promessa que o jogador percebe que não foi cumprida,
e isso é dívida a partir do dia em que o calendário entra.

### Controles, telas e versão

Três autoloads pequenos do 2D em que **o 3D já tem resposta própria**, e por
isso não migram:

| Do 2D | Por que não migra |
|---|---|
| `Controles` (86 linhas) | o 3D tem `teclas_movimento` e `atalhos`, e o esquema de 3ª pessoa não é o de cima. O que migra é a **ideia**: mapeamento em código, não no Input Map, para ficar legível no Git |
| `Telas` (107) | o 3D já orquestra os modais dele pelo `prototype_hud` |
| `Versao` (55) | o 3D tem `historico_3d.json` e o `CHANGELOG_3D.md`, com numeração própria e declarada |

As teclas das telas novas — I, J, K, L, P — precisam entrar no esquema do 3D
sem colidir com o que já existe: **T** adianta a hora e **M** é o HOME. Vale
conferir a tabela inteira antes da primeira tela, não depois da terceira.

---

## O que NÃO migra, e é bom que não migre

- **`GeradorMundo`** (3.250 linhas) e **`Mundo`** (6.265). São o mundo 2D. O 3D
  tem `world_builder` e `geo_region_renderer`, que fazem o mesmo trabalho a
  partir de dados geográficos reais, e fazem melhor.
- **`Construcoes`, `Plantacao`, `Terrenos`** na forma atual: todos raciocinam em
  célula de tilemap. A **regra** migra; a indexação por célula precisa virar
  posição ou lote no 3D. Estes três são o único trabalho de **reescrita** da
  migração inteira — em todo o resto, ou se copia ou se compartilha.

  A `Plantacao` merece nome próprio, porque é o laço central do jogo e não um
  detalhe de indexação: arar → plantar → regar → crescer por dia → colher, no
  alvo à frente, com planta não regada não crescendo naquele dia, mandioca de
  ciclo curto e três fruteiras perenes com carência em dias regados. **Tudo
  isso é regra e atravessa**; o que não atravessa é o `Vector2i` que diz *qual
  leira*. Em 3D isso vira um lote com posição e raio, e o "tile à frente" vira
  o raycast que o 3D já usa para interagir. O roçado já existe como âncora no
  vale — é onde essa fase começa.
- **32 dos 47 portões**, que sobem o mundo 2D para medir. Os outros **15 são de
  lógica pura** e atravessam quase de graça: `testar_afinidade`, `_amanhecer`,
  `_divida`, `_escolha`, `_folheto`, `_fracoes`, `_missoes`, `_povo`,
  `_receitas`, `_slots`, `_talentos`, `_teia`, `_intro`, `_menu` e
  `_menu_interacao`.

Os 32 restantes não se perdem: viram a especificação do que os portões 3D
precisam medir. Um portão que hoje confere que nenhum posto de morador cai
dentro de parede continua sendo a pergunta certa em 3D — muda a conta, não a
pergunta. E o 3D já tem sete testes próprios em `prototipo_3d/tests/`
(`smoke_opening`, `agua_rasa`, `click_controls`, `mapa_fluxo`,
`painel_personagens`, `tela_carregamento`, `tubarao`): eles continuam, e os
portões que chegarem entram ao lado deles, não no lugar deles.

**E nada de arte 2D no mundo 3D.** Os tilesets, os sprites de construção, os
bonecos de 48px e os quadros de cena do 2D ficam no 2D. O que o vale 3D mostra
sai do `CatalogoAssets` e dos construtores procedurais, hoje e depois da
migração.

---

## O corte da jam (4 de outubro)

> **No board, o corte é o marco [Jam 04/10](https://github.com/acentauric/myths-valley/milestone/1)**:
> #1 missões nas âncoras que existem, #2 mochila, #3 fôlego no HUD, #4 teclas
> das telas novas, #5 comidas e carta no Tripo, #6 tradução. As fases 0 e 1 da
> tabela abaixo já saíram, e os itens 1 e 2 da Fase 2 também — a regra deles
> roda no vale, e o que resta deles na jam é tela (#2, #3). A #4 vem **antes**
> da #2: a tabela de teclas se confere antes da primeira tela, não depois.

Cinco dias, com o 3D em desenvolvimento ativo. O que **dá** para ter de pé sem
arriscar a demo:

| Entra | Por quê |
|---|---|
| **Fase 0, o merge** | Risco zero para `prototipo_3d/`, e sem ele todo o resto migra de uma base velha. Meio dia |
| **Fase 1, `Lugares`** | É a costura; nada depende dela para funcionar hoje, e tudo depende dela depois. Um dia |
| **Fase 3 parcial: missões + bússola, nas âncoras que já existem** | É o que mais muda a cara da demo: cinco passos numa constante viram lista com objetivo, checklist e seta. **Só com os lugares que o vale já tem** — a Fase 2.5 não cabe em cinco dias, e sem ela nenhum passo do 2D que aponte para o vau, a chapada ou a fazenda tem para onde apontar. Dois dias |
| **Fase 2, itens 1 e 2** | Fôlego e inventário fazem o passeio virar jogo. Um dia, e só se os anteriores fecharem antes |
| **Fase 7, o primeiro lote** | Em paralelo, e não ocupa os mesmos dias: enquanto o modelo assa, o código anda. O lote da jam são os **itens de mão que a mochila vai mostrar** — as seis comidas e a carta, 1K, sem rig, os mais baratos e rápidos do inventário inteiro |

O que **não** entra são as telas de teias, fé e cartas, e o save ligado às
vagas (#7, #19, #20) — a regra dos quatro já atravessou, e o que ficou de fora
é o que o jogador toca. A razão é a mesma para os quatro: mexem em tela nova e
em estado persistente, e tela nova a quatro dias de
uma submissão é como se perde uma submissão. Eles são a semana seguinte.

Dos modelos, também não entram os **bichos** nem os **interiores**: os
primeiros pedem rig e clipes, os segundos pedem cômodo, que é sistema e não
peça. São o primeiro lote grande depois da submissão.

E **a Fase 2.5 não entra**, que é a mais pesada das que faltam: estender a
região é desenho de KML e importação, e a campanha do 2D só passa a ter para
onde apontar depois dela. A demo da jam usa a vila que existe, com os passos
que cabem nela.

**Uma decisão precisa sair antes do dia 4, mesmo sem código:** a do **idioma**.
Se o jogo inteiro for traduzir, o primeiro passo de missão já tem de nascer com
`_en` e `_es` — descobrir isso com 63 passos escritos é refazer os 63.

**A regra do corte:** nada entra na demo sem portão. A jam não é desculpa para
suspender a prática que fez o 2D chegar até aqui — e os 14 portões de lógica
pura atravessam junto com os sistemas, então o custo é baixo.

---

## Regras que valem para a migração inteira

1. **O 3D não é reescrito.** Se a fatia apaga, refaz ou aposenta o que já roda
   no `prototipo_3d/`, ela está errada — ver a regra do topo. Migração que
   gera retrabalho não é migração, é troca.
2. **Uma fase por commit**, com portão e falsificação, como no 2D.
3. **Regra migrada é regra compartilhada, nunca copiada.** Se copiar for
   inevitável numa fase, a fase declara aqui por que, e quando volta.
4. **O 2D continua abrindo e rodando.** Ele é a referência de regras; referência
   que quebrou não é referência.
5. **Toda fatia roda os dois lados antes do commit:** a suíte do 2D
   (`tools\comum\testar.ps1`) e os testes do 3D (`prototipo_3d/tests/`). O que
   prova que nada foi trocado sem querer é o segundo.
6. **Conteúdo não se reescreve na migração.** As 146 KB de fala e enredo foram
   escritas e revisadas uma vez. Migrar é ligar, não redigir.
7. **Antes de escrever texto novo, conferir se o texto já existe e não está
   chegando** — a lição que a rodada do playtest deixou no 2D, e que vale em
   dobro aqui, onde o conteúdo chega antes do sistema que o mostra.
