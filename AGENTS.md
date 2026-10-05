# Instruções do projeto para agentes

Myths' Valley 3D: projeto Godot independente na raiz.

## Orientações gerais

### Commits

Assunto em **prosa, no presente, dizendo o que mudou no jogo** — e não um rótulo
de categoria. A regra inteira, e por que ela não é `tipo(escopo):`, está em
[.agents/rules/commits.md](.agents/rules/commits.md). Cada fatia é um commit,
com portão e falsificação. Trabalha-se direto na `main`; ela sempre abre e
roda, porque nada é enviado (`git push`) sem `testar.ps1` verde no estado final.

### Chaves

**Nunca** leia, imprima ou copie para scripts ou navegador as chaves do `.env`
(PixelLab, ElevenLabs, OpenAI, LTX) nem as credenciais do Tripo, que ficam no
perfil local `%USERPROFILE%\.tripo`. Use as interfaces web já logadas. Ver
[docs/ferramentas/CHAVES.md](docs/ferramentas/CHAVES.md).

### NUNCA mate processo do Godot por nome

```
taskkill /F /IM Godot_v4.7.2-stable_win64.exe /T      ← não faça isto
```

`/IM` mata **por nome de imagem**: todos os processos com aquele nome, de quem
quer que sejam — e esse é o binário do **editor**. Os testes rodam no
`..._console.exe`, mas o console levanta o outro como filho, e quem vê pares
órfãos é tentado a varrer os dois nomes. Isso já fechou o editor aberto do
desenvolvedor no meio do trabalho, várias vezes, levando junto cena não salva.

Matar só **por PID**, e só PID que o próprio script levantou.

### Geração paga

Arte e áudio gerados consomem crédito: execute **só quando pedido
explicitamente**. Consultas de saldo, histórico e estado são livres. Todo asset
de terceiros entra em [assets/CREDITOS.md](assets/CREDITOS.md) com licença
verificada, e só entra o que permite uso comercial.

---

## O jogo 3D

Leia [docs/mundo/VALE_VIVO_3D.md](docs/mundo/VALE_VIVO_3D.md) antes de mexer em cenário,
luz, som ou moradores do 3D.

### A tarefa vem do board

- **Toda fatia do 3D nasce de uma issue** com rótulo `3d`
  (`gh issue list -R acentauric/myths-valley-3d --label 3d`). Enquanto o marco
  **Jam 04/10** (#1–#6) tiver issue aberta, é dele que se tira a próxima; o
  **Pós-jam** (#7–#32) segue a dependência que cada fase declara em
  [docs/projeto/PLANO.md](docs/projeto/PLANO.md).
- **Leia a issue e a seção do plano que ela cita** antes do código. Os
  critérios de aceite da issue são o portão mínimo da fatia.
- **Confira se o contexto da issue ainda vale.** O board foi aberto antes do
  fechamento da Fase 2, e #7, #10, #11, #12, #14 e #15 descrevem como ausente
  uma regra que já roda em `scripts/compartilhado/`. Parta do que
  existe; o que falta nelas é gatilho, tela e portão.
- **O commit cita a issue no corpo** (`Refs #N`, ou `Closes #N` quando todos os
  critérios fecham). O assunto continua em prosa, pela regra de commits; o
  número vai no corpo, não no assunto.
- **Fechou a issue, atualize o plano** em `PLANO.md` no mesmo commit, e
  registre a mudança em `docs/projeto/CHANGELOG_3D.md`, na seção "Em desenvolvimento" do
  dia. O `data/historico_3d.json` (o que o rodapé do jogo mostra,
  nos três idiomas) só muda quando um build é fechado — numerar build é decisão
  de release, não de fatia.
- **Issue `modelos-3d` gasta crédito**: o custo do lote é aprovado na conversa
  antes de gerar, como manda "Geração paga".

- **Dois estilos, nunca misturados.** O autoload `Estilo` decide se o vale
  inteiro é Tripo ou procedural. Peça nova = uma entrada em
  `CatalogoAssets.PECAS` (`scripts/prototipo_3d/catalogo_assets.gd`) + o
  construtor procedural equivalente em `world_builder.gd` ou
  `flora_reconcavo.gd`. Nunca instancie um GLB do Tripo fora do catálogo nem
  uma peça procedural dentro do estilo Tripo.
- **O catálogo é a única fonte** de caminho, medida (`altura` ou `largura`),
  colisão (`tronco` ou `caixa`) e correções (`girar`, `afundar`, `piso`) de cada
  GLB. Os GLBs do Tripo chegam normalizados com 0,98 no maior eixo; confira com
  `tools/tripo/medir_glb.py` antes de escolher a medida.
- **Texturas:** o `project.godot` importa texturas novas comprimidas em VRAM
  (`[importer_defaults]`). Texturas de interface (HUD, ícones) devem ficar
  **Lossless** no `.import` delas. As texturas que o Godot extrai dos GLBs
  (`*_tripo_*.jpg/png` e seus `.import`) são ignoradas pelo Git; ao trocar um
  GLB, apague os `.import` órfãos das texturas antigas.
- **Todo texto que o jogador lê existe nos TRÊS idiomas** — pt-BR, inglês e
  espanhol. Decisão do autor, setembro de 2026. A forma é `campo`, `campo_en`,
  `campo_es` no mesmo objeto JSON, e `IdiomaMenu.sufixo()` escolhe. Isso
  implica que **texto de jogador não mora em constante de GDScript**: em
  constante não há como traduzir. `tests/idiomas.gd` cobra, inclusive contra
  tradução que é cópia do português; o que ainda falta fica declarado em
  `FALTAM_TRADUCAO`, com a razão escrita.
- **Moradores e voz:** postos e falas em `data/npcs_3d.json`;
  missões do Pedro em `guia_pedro.gd`; vozes pt-BR do ElevenLabs em
  `assets/audio/vozes/` (o texto longo fica no balão; a voz é só a
  saudação ou a narração curta).
- **Sobrevoo do menu:** é um trajeto gravado (`data/sobrevoo_menu.json`) que contorna
  árvores e casas pelos lados, sem subir. Mexeu em árvore ou casa perto dele e
  `sobrevoo_livre`/`sobrevoo_livre_procedural` reprovaram: replaneje pelo
  `tools/prototipo_3d/sobrevoo/README.md` em vez de afrouxar o portão.
- **Para depurar num lugar do vale sem refazer o caminho**: `JOGAR_3D.cmd -Lugar igreja`
  (ou `-- --lugar=igreja` no Godot); os nomes são os do `Lugares`. Os testes põem o
  jogador no ponto direto, e não precisam disso.
- **Teste rodado com `--script` não enxerga autoload pelo nome, e nem o que ele
  pré-carrega.** Pegue o autoload por `root.get_node("/root/Nome")`, e carregue com
  `load()` DEPOIS de o vale subir todo script que cite autoload: com `preload`, ele
  compila antes deles, falha, e fica quebrado no cache para o jogo inteiro.
- **Erro de compilação no Godot NÃO derruba o jogo — e por isso não confie em
  código de saída 0.** Um `Parse Error` deixa o nó sem script e a cena segue;
  o estrago aparece longe de onde foi feito. Já aconteceu: um
  `IdiomaMenu.sufixo()` sem o `preload` passou por onze testes e só reprovou no
  décimo segundo. Ao rodar a bateria, **conte também `Parse Error` e
  `Compile Error` no stderr**, e não só o `ExitCode`.
- **Teste `SceneTree` que estoura no meio TRAVA, não reprova.** O erro aborta o
  `_run` antes do `quit()`, e a árvore fica girando — de fora se vê um Godot
  vivo e calado. Por isso a bateria mata por PID depois de um teto de tempo,
  como o runner deste projeto faz, e por isso "travou" é um resultado tão ruim
  quanto "reprovou".
- **No Godot 4, `_unhandled_key_input` roda ANTES de `_unhandled_input`.** As
  telas do vale ouvem no `_unhandled_input` (o folheto, o amanhecer, o painel), e
  por isso recebem a tecla DEPOIS de quem ouve no `_unhandled_key_input` — o Esc
  do menu no `prototype.gd`, o E que come na barra de mão. Quem ouve no primeiro
  pergunta se uma tela dessas está aberta antes de agir. Apareceu na #21: o Esc
  que devia pular o cartão do amanhecer abria o menu.
- **Classe sem `class_name` se carrega com `preload`.** `IdiomaMenu`
  (`scripts/prototipo_3d/idioma_menu.gd`) é assim, e a abertura o carrega
  desse jeito. E ele já tem `campo(dados, chave)`, que escolhe o texto pelo
  idioma do jogador — use esse, não escreva outro.
- **Git LFS é necessário:** instale-o antes de clonar e desenvolver; modelos
  e áudio precisam estar baixados, e não apenas como ponteiros.

### Pipeline de assets 3D (decisão de 26/09/2026)

- O modo **Tripo** é a linha mestra. Fluxo obrigatório: Modelo HD →
  Remesh/Retopologia (Malha Smart, Quad) → Exportar GLB. Nunca coloque um HD cru
  no jogo e não use o redutor antigo, removido por abrir costuras de UV.
- Textura **1K para adereços e itens**, 2K só para construções de destaque,
  árvores nomeadas e personagens; 8K jamais no jogo. Tabela de polígonos e o
  restante em [docs/arte/ASSETS_TRIPO.md](docs/arte/ASSETS_TRIPO.md).
- Todo GLB promovido para `assets/` precisa de linha em `ORIGEM.md`
  (tarefa Tripo, faces, textura) e em [assets/CREDITOS.md](assets/CREDITOS.md).
- O estilo procedural continua existindo (AJUSTAR → Estilo visual) apenas como
  comparação; não crie arte nova nele.
- Antes de mover um resultado para `assets/`, confira malha,
  materiais, escala, rig, nomes dos clipes e licença. Registre origem e hash ao
  promover o arquivo.

### Tripo pelo MCP e pelo Studio

- Para criação ou processamento de modelos 3D, prefira o servidor MCP `tripo`
  configurado localmente para o Tripo CLI. Aceita imagens locais ou URLs; grave
  resultados experimentais em `.assets-raw/tripo/`, que não é versionada.
- Para personagens animados, use o cenário `anim` ou a cadeia
  `rig-check,rig,retarget`. O cenário `anim` inclui `idle` e `walk`.
- Quando o saldo do Tripo Studio for preferível ao da API, use o MCP
  `playwright`, conectando ao Chrome do usuário **apenas** pela extensão oficial
  Playwright MCP, com o usuário escolhendo a aba e aprovando a conexão. Não
  registre `PLAYWRIGHT_MCP_EXTENSION_TOKEN` no repositório.
- **Antes de clicar numa ação que consuma créditos**, informe o custo mostrado
  pela interface e obtenha confirmação explícita — salvo quando o pedido atual
  já autorizar claramente aquela geração. CAPTCHA, dois fatores, confirmação por
  e-mail e pagamento permanecem sob controle humano.
- Registre as tarefas num `tools/tripo/lote_*.json`; retopologia e exportação em
  massa com `tools/tripo/lote_studio.js` no console do Studio (aba visível);
  `sincronizar_downloads.py` copia de Downloads; `registrar_origem.py` escreve o
  `ORIGEM.md` de cada pasta. Teste nos dois estilos antes de commitar. Mantenha
  downloads temporários em `tools/tripo-studio/output/` e promova para
  `.assets-raw/tripo/` só o material escolhido. Instalação e operação em
  [docs/ferramentas/TRIPO_MCP.md](docs/ferramentas/TRIPO_MCP.md) e
  [docs/ferramentas/TRIPO_PLAYWRIGHT.md](docs/ferramentas/TRIPO_PLAYWRIGHT.md).

## Sistemas e validação

Os sistemas de `scripts/compartilhado/` pertencem ao 3D; não copie versões de
outro checkout. Rode `.\tools\prototipo_3d\testar.ps1` antes de commitar e,
obrigatoriamente, antes de `git push`. Ele roda **só os portões que a mudança
alcança** (fecho de dependências de cada teste, com impressão digital do
conteúdo), reaproveita o que já ficou verde nesta máquina e o que é igual a
`origin/main`, e roda em paralelo. Doc mudada não roda portão nenhum; não
contorne isso rodando a bateria inteira à mão. `-Explicar` diz o que rodaria e
por quê; `-Tudo` força a bateria completa e fica para antes de fechar build.
Os testes não podem acessar o diretório pai do projeto. Preserve UIDs, opções
de importação e o diretório de saves. Os binários grandes usam Git LFS.
