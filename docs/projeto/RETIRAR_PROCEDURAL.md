# Retirar o estilo procedural (#58)

> **Feito em 10/10/2026.** O procedural saiu do jogo inteiro, nas fatias 1 a 8 deste
> plano, numa só rodada (branch `estilo/sem-procedural`): ver o CHANGELOG_3D do dia.
> Duas diferenças do plano: o autoload `Estilo` não foi renomeado (ficou com as
> plaquinhas de nome e o cursor, e perdeu `modo`, `tripo()` e `procedural()`), e o
> `vista_do_alto` passou para o Tripo com as mesmas conferências. Este documento fica
> como o mapa do que existia.

Inventário, riscos e plano em fatias. **Só mapeamento**: nenhum código de jogo
foi removido nesta rodada (ver "O que já saiu"). Levantado por `grep` sobre
`scripts/`, `tests/`, `tools/`, `scenes/`, `docs/` na `nuvem/base-10-10`; o
Godot não rodou aqui, então nada abaixo foi validado em execução.

Pontos de partida: o AGENTS.md já diz que o procedural é "só comparação", sem
arte nova, e a decisão do autor de 29/09 (`COMPOSICAO_AUTORAL_3D.md`) tirou a
obrigação de equivalente procedural para peça Tripo nova. Esta retirada é o
passo seguinte: o código deixa de existir, não só de crescer.

## 1. Inventário

### 1.1 O autoload `Estilo` (`scripts/autoload/estilo.gd`, `project.godot:24`)

Faz **três coisas**, e só uma é o estilo:

| Papel | Fica? |
|---|---|
| `modo`, `tripo()`, `procedural()`, `definir()`, gravação em `preferencias_visuais.cfg` (`[estilo] modo`) | sai |
| `mostrar_nomes` / `definir_nomes` / sinal `nomes_alterados` (usado por `placas_nomes.gd:185` e `painel_ajustes.gd:311`) | **fica**, precisa de outro lar |
| `_cursor_de_clique` (mãozinha em todo botão/slider, via `node_added`) | **fica**, precisa de outro lar |

Consequência: o autoload não pode simplesmente ser apagado. Ou ele é
renomeado/enxugado (sugestão: manter o nome `Estilo` durante a transição e só
depois trocar por `Interface`), ou as duas funções migram para autoloads que já
existem (`Tela` guarda preferências visuais no mesmo `.cfg`).

### 1.2 Consumidores de `Estilo.tripo()` / `Estilo.procedural()` / `Estilo.modo` (39 pontos em 28 arquivos)

Todos em `scripts/prototipo_3d/` salvo indicação. Tipo **A** = ramo que só existe
para o procedural (apaga-se); **B** = guarda `Estilo.tripo()` que passa a ser
sempre verdadeira (remove-se a condição, mantém o corpo); **C** = outro.

| Arquivo:linha | Tipo | O que o ramo procedural faz |
|---|---|---|
| `world_builder.gd:619` `estilo_tripo()` (≈35 usos internos, ver 1.3) | A/B | encapsula tudo abaixo |
| `player_controller.gd:294,298` | A | `PersonagemProcedural.novo("viajante")` como corpo do jogador |
| `npc.gd:456,479,1881` | A/B | corpo do morador; o `if modelo == null` final (l.478) só é alcançável no procedural, pois no Tripo o fallback é `_corpo_provisorio()` |
| `retratos_3d.gd:158,161` | A | retrato do diário com o boneco procedural |
| `painel_personagens.gd:22,888,894` | A | `Humanoide = preload(personagem_procedural.gd)` — prévia do painel |
| `boneco_da_mochila.gd:182–183,234` | A | boneco da mochila |
| `vestimenta_3d.gd:121,275,297,337,396,426,534` | A/B | `machado_procedural`, âncoras de mão/cabeça do boneco, `is PersonagemProcedural` |
| `bando_de_chao.gd:509–521` | A | leque do pavão na caixa do procedural |
| `animador_bicho.gd:278` | B | (caixa cinza `Animador.vestir` continua, ver 2.3) |
| `fauna_vale.gd:88` (`_tripo`), `cardume.gd:192` (`opcoes["tripo"]`), `tubarao.gd:375`, `revoar_vale.gd:762`, `saveiro_vale.gd:316,321`, `curral_vale.gd:260`, `luta_vale.gd:334`, `lavoura_vale.gd:220` | B | cada um troca GLB por forma de código |
| `interior_casa.gd:143,705`, `interior_igreja.gd:268`, `interiores.gd:160`, `comodo.gd:536` | A/B | interiores sem casca GLB: usam corpos de caixa do lote |
| `prototype.gd:638` | A | texto do HUD "Estilo procedural…" |
| `prototype.gd:918`, `abertura.gd:267` | C | `print("PROTOTYPE_READY: estilo=…")` / `OPENING_READY: … estilo=…` — **os testes casam essas linhas?** (ver risco R4) |
| `prototype_hud.gd:1314` | C | `style_icon.definir(Estilo.tripo())` — ícone de estilo no HUD |
| `painel_ajustes.gd:306–310` | A | opção **AJUSTAR → Estilo visual** (`"Tripo (modelos gerados)"` / `"Procedural (por código)"`) |
| `catalogo_assets.gd:5` | doc | comentário de cabeçalho |

Além do `Estilo`, `GeoRegionRenderer` recebe o estilo por parâmetro
(`set_estilo_tripo`, `_estilo_tripo`), sem tocar no autoload — ver 1.3.

### 1.3 Código que existe só para o procedural

| Item | Tamanho | Quem chama | Observação |
|---|---|---|---|
| `flora_reconcavo.gd` | 510 linhas | `world_builder.gd` (árvores nomeadas `1606`, 15 adereços `1405–1419`), `geo_region_renderer.gd:319,2268`, `comodo.gd:555–558`, `catalogo_assets.gd:864` | árvores: mangueira, jaqueira, cajueiro, palmeira (dendê/coqueiro), bananeira, ipê, embaúba, mata_alta; adereços: poço, cruzeiro, carroça, varal, lenha, pote, cerca, banco, lampião, candeeiro, fogueira, túmulo, pedras, canteiro de mandioca, moita |
| `personagem_procedural.gd` | 396 linhas | `player_controller`, `npc`, `retratos_3d`, `boneco_da_mochila`, `vestimenta_3d`, `painel_personagens` (ver 1.2) | também age como "animador" (`animador = procedural`) |
| `world_builder._igreja_procedural` (l.1921) e os callables `procedural` dos `_construcao(...)` (capela, casa_carro_quebrado, casa_pasto, casa_taipa, igreja, mirante, pier, venda) + `_girar_construcao_procedural` (l.984) | ≈250 linhas | `world_builder` | `_construcao` recebe um `Callable procedural` por construção |
| `world_builder._adereco` — bloco `match` de `FloraReconcavo` | 20 linhas | `world_builder` | |
| `geo_region_renderer.gd`: `FloraReconcavo.ESPECIES_MATA` (l.35 do flora), `_malha_da_especie` no ramo procedural, `ESPECIES_MATA_TRIPO` vs lista, `_estilo_tripo` (≈12 guardas) | espalhado | — | `set_estilo_tripo` fixado em `world_builder.gd:655` |
| `comodo._procedural` (l.553) | 8 linhas | `comodo.gd:542` | |
| `canoas.gd` `_casco_procedural` | ? | `tests/canoa_colisao.gd:11` | o casco procedural de canoa é chamado direto por um teste; **verificar se ainda é usado no Tripo** |
| `cabra_de_cena.gd`, `bancadas_vale.gd`, `criatura_vale.gd`, `animador_bicho.gd` | — | — | "caixa cinza" é o **fallback sem modelo**, não só o procedural; ver 2.3 |
| `zona_de_flora.gd` (38 linhas) | | `scenes/prototipo_3d/paisagismo_vale.tscn`, `tools/mapas/planejar_paisagismo.gd` | **não é procedural**: é a zona de flora do paisagismo autoral; fica |
| `Copas` (`tests/lod_vegetacao.gd:164–173`) | | | ramo "malha que não é a do catálogo (procedural)" |

### 1.4 Testes e portões

O runner descobre portões por `tests/*.gd` (`testar.ps1:491`); não há lista
fixa para editar. O estilo do portão vem de `_estilo_do_portao()` (que grava
`/root/Estilo.modo`).

**Onze portões que existem só para o outro estilo** (6 linhas cada, herdam o
base e devolvem `"procedural"`):

`bichos_de_casa_procedural`, `camera_resiliente_procedural`, `casa_procedural`,
`colisoes_de_passeio_procedural`, `colisoes_do_vale_procedural`,
`fauna_do_mar_procedural`, `interiores_procedural`, `lapides_no_chao_procedural`,
`lod_das_pecas_procedural`, `rocado_procedural`, `sobrevoo_livre_procedural`.

**Portões base que têm ramo procedural interno** (editar, não apagar):

- `tests/vista_do_alto.gd:15` — fixa `modo = "procedural"`: o portão **inteiro** roda no procedural. É o caso mais delicado (ver R2).
- `tests/onca.gd:299–306` — seção "8b. O PROCEDURAL: A CAIXA".
- `tests/itens_na_mao.gd:35,110,344–357` — item 10 "só o machado no procedural" e `_conferir_procedural()`.
- `tests/lod_vegetacao.gd:164–173` — caso "malha que não é a do catálogo".
- `tests/casa.gd`, `casas_por_dentro.gd`, `camera_resiliente.gd`, `colisoes_de_passeio.gd`, `colisoes_do_vale.gd`, `fauna_do_mar.gd`, `interiores.gd`, `lapides_no_chao.gd`, `lod_das_pecas.gd`, `rocado.gd`, `sobrevoo_livre.gd`, `bichos_de_casa.gd` — têm `_estilo_do_portao()` (o ramo `== "tripo"` de `casa.gd:121` mostra que há asserções por estilo).
- `tests/saveiro.gd:31,124–129`, `casas_dos_moradores.gd:87`, `estacoes_do_vale.gd:39`, `hud_desempenho.gd:30` — menções em asserção ou comentário ("boneco do procedural", cal com shader no procedural, folhagem procedural registrada).
- `tests/canoa_colisao.gd:11` — chama `_casco_procedural()` direto.

**Ferramentas** com `--estilo=tripo|procedural`: `tools/prototipo_3d/medir_carregamento.gd:32`,
`tools/prototipo_3d/sobrevoo/extrair_geometria.gd` (modo `uniao` mescla os dois
estilos), `fotografar_chao`, `fotografar_varais`, `fachadas_das_casas`,
`medir_lod`, `medir_lod_das_pecas`, `fotos_da_mao`, `tools/mapas/extrair_composicao_vale.gd`,
`tools/mapas/planejar_casas_moradores.gd`, `docs/projeto/desempenho_05_10_2026/ferramentas/medir_fps.gd`.

### 1.5 Dados, textos, saves, docs

- **Texto de jogador**: opção "Estilo visual" em `painel_ajustes.gd:306` + traduções em `idioma_menu.gd:322` (en) e `:814` (es, hoje cópia do pt — está em `FALTAM_TRADUCAO`?) e a ajuda em `ajuda_menu.gd:87–89` (explica Tripo × Procedural, 3 idiomas); status do HUD em `prototype.gd:638–644`; ícone do HUD (`prototype_hud.gd:1314` e a classe do ícone).
- **Preferência salva**: `user://preferencias_visuais.cfg` seção `[estilo] modo`. Quem já salvou `procedural` precisa **cair para Tripo** (hoje já cai se o valor for inválido; a regra continua valendo se `Estilo` ler a chave).
- **Docs**: `AGENTS.md` (regra "Dois estilos"), `docs/mundo/VALE_VIVO_3D.md`, `docs/arte/ASSETS_TRIPO.md`, `docs/mundo/COMPOSICAO_AUTORAL_3D.md` (fala em "os dois estilos"), `docs/testes/PORTOES_2D_3D.md`, `docs/testes/ANIMACOES_DOS_ANIMAIS.md`, `docs/experiencia/COMO_JOGAR_3D.md`, `docs/projeto/{GDD,PLANO,DECISOES_PROTOTIPO_3D,BOARD_2026-10-07,ISSUES_ABERTAS_2026-10-07,ARQUITETURA}.md`, `assets/prototipo_3d/{arvores,construcoes}/ORIGEM.md` (citam `FloraReconcavo`). Históricos (`CHANGELOG_3D`, `HISTORICO_DESENVOLVIMENTO_3D`, `RETOMADA_*`, `REVISAO_DOCUMENTAL_72`, `desempenho_05_10_2026/`) **não se reescrevem**: são registro.
- `data/*.json`: sem chave de estilo.

## 2. Se o procedural sair

### 2.1 O que o jogador perde
Só a opção em AJUSTAR → Estilo visual e o texto de ajuda sobre ela. O vale
padrão já é Tripo (`Estilo.modo = TRIPO`). Quem tem `modo=procedural` salvo
volta ao Tripo na primeira abertura.

### 2.2 O que quebra por dependência escondida
Estas são as pegadinhas, em ordem de gravidade.

- **R1 — Fallbacks que hoje caem no procedural dentro do estilo Tripo.**
  `_adereco`: se `CatalogoAssets.instanciar` devolve `null` no Tripo, o código
  **cai no `match` de `FloraReconcavo`** (world_builder 1398–1419) em vez de
  retornar. O mesmo acontece em `_construcao` (`world_builder.gd:917–976`) e na
  árvore nomeada (`1592–1606`). O AGENTS.md proíbe "peça procedural dentro do
  estilo Tripo", mas o fallback silencioso existe. Ao retirar, GLB ausente
  deixa de aparecer e vira `null` — hoje `CatalogoAssets.relatorio_faltando()`
  só imprime `CATALOGO:` (l.679). **Os 263 GLBs distintos do catálogo existem em disco**
  (confirmado nesta rodada), então hoje nada cai no fallback; a fatia deve
  trocar o fallback por erro explícito (`push_error` + portão que falha).
- **R2 — `vista_do_alto.gd` roda inteiro no procedural.** Se o procedural sair,
  o portão testa outra coisa (ou nada). É preciso decidir: passar para Tripo
  (vira outro teste, de custo de render) ou aposentar. Ler o teste antes.
- **R3 — `Estilo` carrega cursor e nomes** (1.1). Apagar o autoload quebra HUD
  de nomes e a mãozinha em todos os botões, sem erro de compilação óbvio nos
  botões (apenas perde o cursor).
- **R4 — Impressão digital do runner.** `testar.ps1` calcula fecho de
  dependências por teste. Apagar `flora_reconcavo.gd` e `personagem_procedural.gd`
  muda o fecho de quase todos os portões do 3D: a primeira rodada depois da
  remoção vai rodar **praticamente a bateria inteira** (comportamento esperado,
  não é bug). Também: se algum portão casa a string `PROTOTYPE_READY: estilo=`
  ou `OPENING_READY`, mudar o `print` quebra o portão (conferir com
  `grep -rn "estilo=" tests tools` antes de mexer em `prototype.gd:918` e
  `abertura.gd:267`).
- **R5 — Erro de compilação não derruba o jogo** (AGENTS.md). Remover um
  `class_name`/`preload` de `PersonagemProcedural` deixa `Parse Error` no
  stderr e o nó sem script. Cada fatia precisa **contar `Parse Error` e
  `Compile Error`**, e não só `ExitCode`. `grep -rn PersonagemProcedural`
  e `Humanoide` devem voltar vazios antes de apagar o arquivo.
- **R6 — `.uid` e referências de cena.** Apagar `.gd` exige apagar o `.gd.uid`
  e conferir `grep` em `.tscn`/`.tres`. `zona_de_flora.gd.uid` **não** entra.
- **R7 — Sobrevoo gravado** (`data/sobrevoo_menu.json`). Os portões
  `sobrevoo_livre` e `sobrevoo_livre_procedural` validam o trajeto nos dois
  estilos; removendo o procedural cai o segundo, e a geometria que
  `extrair_geometria.gd --estilo=uniao` mescla deixa de existir. O trajeto
  atual continua válido para o Tripo (o portão Tripo já passa hoje).
- **R8 — Tradução.** `tests/idiomas.gd` cobra paridade; remover a opção exige
  remover as chaves em pt/en/es **e** em `FALTAM_TRADUCAO` se constarem.
- **R9 — Save.** `[estilo] modo` fica órfão no `.cfg`; é inofensivo (ninguém lê).
  Não migrar.
- **R10 — Desempenho.** `docs/projeto/desempenho_05_10_2026/` e
  `medir_carregamento.gd` comparam estilos. O número do procedural vira
  histórico; a medição Tripo continua.

### 2.3 O que NÃO é procedural e deve ficar
- **Caixa cinza provisória** (`npc._corpo_provisorio`, `animador_bicho` "A caixa
  cinza dos bichos", `bancadas_vale`, `cabra_de_cena`, `criatura_vale`): é o
  fallback do **Tripo** para quem ainda não tem modelo (caititu, oficina,
  Quirino). Alguns comentários chamam isso de "procedural"; a fatia final só
  corrige o texto. Conferir se o `CatalogoAssets` já cobre todos hoje
  (`quirino` tem GLB no catálogo; o comentário em `npc.gd:466` — "Hoje é só o
  mestre Quirino" — parece desatualizado).
- `ZonaDeFlora`, `Copas`, `PecasDistantes`, `CoqueiroCortado`, `EspeciesDaMata`
  (o `EspeciesDaMata.malha()` é o mapa Tripo, usado no ramo `_estilo_tripo`).
- `GeoRegionRenderer`: os ramos `_estilo_tripo` são o caminho vivo; só o `else`
  morre.

### 2.4 Peças Tripo que faltam para cobrir algo hoje só procedural
Comparei cada construtor de `FloraReconcavo` e cada `_construcao` com
`CatalogoAssets.PECAS`. **Todas as chaves têm GLB no catálogo e em disco**:

- adereços: poco, cruzeiro, carroca, varal, lenha, pote, cerca, banco,
  lampiao_poste, fogueira, tumulo, pedras, mandioca_canteiro, moita, candeeiro ✔
- árvores: mangueira, jaqueira, cajueiro, coqueiro, dendezeiro, bananeira,
  ipe_amarelo/roxo, embauba, mata_alta ✔
- construções: capela, igreja, casa_taipa, casa_carro_quebrado, casa_pasto,
  venda, pier, mirante ✔
- personagens e bichos: viajante e os moradores do catálogo ✔

**Lacunas conhecidas (nenhum crédito é gasto aqui)**, para a fatia de
verificação, não para gerar:
1. `Cardume`/peixes e `Tubarao` no Tripo: confirmar que cada espécie do
   `fauna_do_mar` tem peça (o catálogo traz sardinha…budião, tubarão).
2. Chaves que o ramo Tripo ainda resolve por **nome de teste** (`tem_tripo("bote")`, `"capelinha"`, `"pedras_praia"`, `"pedra_mare"`, `"sub_bosque"`, `"mangue"`, `"ingazeiro"`) — hoje condicionais com fallback silencioso; viram obrigatórias.
3. `Canoas._casco_procedural` — se o casco da canoa no Tripo ainda depende dele, é uma lacuna real.
4. `PersonagemProcedural` é usado como *retrato* no painel de personagens
   se faltar GLB; hoje todo morador do `data/npcs_3d.json` tem GLB? Verificar
   cruzando `npcs_3d.json` × `PECAS`. Quirino é o caso a checar.

Se a verificação achar lacuna, a decisão do crédito é do autor (AGENTS.md,
"Geração paga"): a retirada não deve gerar nada sozinha.

## 3. Plano em fatias

Regra de cada fatia: um commit, assunto em prosa dizendo o que muda no jogo,
`Refs #58` no corpo, `testar.ps1` verde (e nenhum `Parse Error` / `Compile
Error` no stderr) antes de seguir. Antes do push final: `testar.ps1 -Push`.
`-Explicar` mostra o que cada fatia alcança.

**Fatia 0 — Portão de entrada (sem código).** Cruzar `data/npcs_3d.json`,
`CatalogoAssets.PECAS` e as espécies de fauna; listar o que ainda cai em
caixa cinza ou procedural no Tripo (itens 1–4 de 2.4). Registrar em `#58`.
- Arquivos: nenhum (ou só este doc).
- Validar: `.\tools\prototipo_3d\testar.ps1 -Explicar`; rodar o jogo com
  `JOGAR_3D.cmd` e conferir o stdout por `CATALOGO:` (lista de faltantes).

**Fatia 1 — Fallback procedural vira erro dentro do Tripo.** `_adereco`,
`_construcao`, árvore nomeada em `world_builder.gd` e `comodo.gd`:
quando o GLB falta, `push_error` em vez de construir pela flora; ainda sem
apagar nada.
- Arquivos: `world_builder.gd`, `comodo.gd`, `interior_*.gd` conforme grep.
- Portões afetados: `composicao_vale`, `colisoes_do_vale`, `casas_por_dentro`, `interiores`, `lapides_no_chao`, `rocado`, `casa`.
- Validar: `.\tools\prototipo_3d\testar.ps1` (lote). Falsificar: renomear
  temporariamente um GLB do catálogo e ver o erro aparecer.

**Fatia 2 — Tira a opção "Estilo visual" de AJUSTAR.** `painel_ajustes.gd:306–310`,
traduções de `idioma_menu.gd:322,814`, texto de `ajuda_menu.gd:87–89`, status
em `prototype.gd:638–644` e `style_icon` de `prototype_hud.gd`. `Estilo.modo`
fica fixo em `TRIPO` (a chave salva é ignorada: quem tinha `procedural` volta
ao Tripo).
- Portões: `ajustes_com_ajuda`, `idiomas`, `composicao_do_hud`, `hud_desempenho`.
- Validar: `testar.ps1`; a bateria de idiomas não pode reclamar de chave órfã.

**Fatia 3 — Separa o que não é estilo do `Estilo`.** Mover `mostrar_nomes` /
`nomes_alterados` e o `_cursor_de_clique` para um autoload próprio (ou `Tela`),
mantendo o ID e o `.cfg`. Atualiza `placas_nomes.gd`, `painel_ajustes.gd`,
`project.godot`.
- Portões: `placas_e_baloes`, `placas_sem_rosto`, `ajustes_com_ajuda`.
- Validar: `testar.ps1`; conferir manualmente a mãozinha nos botões do menu.

**Fatia 4 — Aposenta os onze portões `*_procedural` e os ramos internos.**
Apaga os 11 arquivos (e `.uid`), tira `_estilo_do_portao()` dos base, a seção
8b de `onca.gd`, o item 10 / `_conferir_procedural` de `itens_na_mao.gd`, o
caso procedural de `lod_vegetacao.gd`, e decide o `vista_do_alto.gd` (R2).
- Portões: o runner recalcula o fecho; esperar rodada larga.
- Validar: `testar.ps1`; falsificar quebrando de propósito uma asserção do
  caminho Tripo de um dos base (precisa continuar vermelha).

**Fatia 5 — Corta o personagem procedural.** Remove `personagem_procedural.gd`
(+ `.uid`), o `else` em `player_controller`, `npc`, `retratos_3d`,
`boneco_da_mochila`, `vestimenta_3d` (inclui `machado_procedural`),
`painel_personagens` (`Humanoide`) e `bando_de_chao` (leque).
- Antes de apagar: `grep -rn "PersonagemProcedural\|Humanoide\|machado_procedural"` vazio.
- Portões: `itens_na_mao`, `rotina_dos_moradores`, `falas_dos_moradores`,
  `painel_personagens*`, `saveiro` (retrato sem modelo), `beata_no_vale`,
  `cadeia_do_coveiro`.
- Validar: `testar.ps1` + contagem de `Parse Error`/`Compile Error`.

**Fatia 6 — Corta a flora e as construções procedurais.** Remove
`flora_reconcavo.gd` (+ `.uid`), `_igreja_procedural`, os `Callable`s
`procedural` de `_construcao` (muda a assinatura: arrastar chamadores),
`_girar_construcao_procedural`, `comodo._procedural`, o `else` da lista de
espécies em `geo_region_renderer.gd`, `FloraReconcavo.cerca` em
`catalogo_assets.gd:864` (**atenção**: é fallback de `lance_de_cerca`), e o
`_casco_procedural` se a verificação da fatia 0 permitir.
- Portões: praticamente todos os do cenário; o mais sensível é
  `sobrevoo_livre` (R7): o trajeto deve continuar sem mexer em árvore.
- Validar: `testar.ps1`; se `sobrevoo_livre` reprovar, replanejar pelo
  README do sobrevoo, **sem afrouxar o portão**.

**Fatia 7 — Tira o autoload `Estilo` de vez.** `tripo()` vira `true` constante
e some; `estilo_tripo()` do `world_builder`, `set_estilo_tripo`, `_estilo_tripo`
do `GeoRegionRenderer` e as opções `"tripo"` de `cardume`/`fauna_vale` saem.
Remove `--estilo=` das ferramentas (`medir_carregamento`, `sobrevoo/extrair_geometria`
(modo `uniao`), `fotografar_*`, `medir_lod*`, `fotos_da_mao`, `tools/mapas/*`).
- Validar: `testar.ps1`; rodar uma ferramenta de cada família.

**Fatia 8 — Documentação.** AGENTS.md (apagar "Dois estilos…"), `VALE_VIVO_3D`,
`ASSETS_TRIPO`, `COMPOSICAO_AUTORAL_3D`, `PORTOES_2D_3D`, `ARQUITETURA`, `PLANO`,
`ORIGEM.md` de árvores e construções; `CHANGELOG_3D` e `historico_3d.json`
(entrada para o jogador: a opção sumiu). Históricos ficam como estão.
- Validar: `grep -rni "procedural" docs AGENTS.md` só devolve registro histórico.

Ordem: 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8. As fatias 1–3 não removem
comportamento visível além da opção; 4–6 são as grandes e podem ser
divididas por arquivo se o `testar.ps1` ficar lento (cada subfatia roda só o
que alcança). `Closes #58` só na fatia 8.

## 4. O que já saiu nesta rodada

Um commit separado, com remoção comprovadamente morta (grep em `scripts/`,
`tests/`, `tools/`, `docs/`, `scenes/`):

- `Estilo.estilo_alterado` (sinal emitido sem ouvinte) e sua emissão em
  `definir()`;
- `Estilo.rotulo()` (sem chamador).

Nada mais foi tocado. O jogo não foi executado aqui (Godot indisponível):
validar com `.\tools\prototipo_3d\testar.ps1`.
