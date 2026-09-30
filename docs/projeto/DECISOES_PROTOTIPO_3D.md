# Myths' Valley — Decisões do protótipo 3D

> **Objetivo:** entregar uma demonstração jogável para Windows em dois finais de semana, usando Godot, modelos produzidos no Tripo e animações humanas do Mixamo.
> **Princípio:** concluir uma experiência pequena de ponta a ponta antes de ampliar o número de sistemas, personagens ou cenários.

| Campo | Registro |
| --- | --- |
| Data | 23/09/2026 |
| Versão deste documento | 1.5 |
| Responsável pelo produto | Ramon Santos |
| Repositório | `acentauric/myths-valley` |
| Caminho deste documento | `docs/projeto/DECISOES_PROTOTIPO_3D.md` |
| Branch proposta | `prototype/myths-valley-3d` |
| Janela de produção planejada | 26–27/09 e 03–04/10/2026 |
| Meta interna de conclusão | 04/10/2026, com build e materiais de apresentação prontos |
| Meta de submissão usada no planejamento | 05/10/2026; confirmar prazo, horário, fuso e requisitos no formulário oficial |
| Estado | Registro de decisões de trabalho e validações pendentes; não comprova implementação |

> **Atualização de 29/09/2026 — o recorte vigente está no board.** Depois deste
> documento, o autor decidiu que o 3D vira o jogo completo e que a migração do
> 2D é a prioridade ([MIGRACAO_2D_3D.md](MIGRACAO_2D_3D.md)). O plano virou
> issues no GitHub, e o marco **Jam 04/10** (#1–#6) é o que entra na demo.
> Três itens deste documento ficaram **fora** desse marco e estão no
> **Pós-jam**: a conversa por LLM com memória (§7 e §10, hoje a #32, "prioridade
> a confirmar"), o plantio (§9, 27/09, hoje a #8) e o save ligado (§10, hoje a
> #7). Se algum deles precisar voltar para a jam, a decisão é do Ramon, e
> o marco da issue muda junto — este documento não passa por cima do board.

Este documento se aplica ao **protótipo 3D da jam**. Não substitui o GDD completo nem autoriza remover funcionalidades da versão 2D. As escolhas expressas por Ramon são requisitos; os números reduzidos de conteúdo e a ordem de implementação são o recorte técnico proposto para cumprir o prazo.

### Registro do primeiro teste local — 23/09/2026

Foi criado um projeto Godot independente em `prototipo_3d/project.godot`, dentro da branch `prototype/myths-valley-3d`. A configuração da raiz permanece como referência executável da base 2D. O atalho `JOGAR_3D.cmd` abre a cena 3D; instruções em [COMO_JOGAR_3D.md](../experiencia/COMO_JOGAR_3D.md).

Este teste usa o personagem fornecido em `medieval+character+3d+model.zip`: FBX texturizado, 65 ossos e nenhum clipe de animação. O controlador usa altura de 1,78 m, movimento, corrida, colisão e câmera em terceira pessoa. Um animador procedural fornece movimento provisório dos ossos. Isso ainda não valida o pipeline completo de clipes Mixamo ou a exportação Windows distribuível.

Engine executada: `4.7.2.stable.official.ed1daf0bf`; Forward+ iniciado na NVIDIA GeForce GTX 1660 Ti with Max-Q Design. O ambiente pequeno de teste inclui vila, horta e costa com formas simples. Os demais sistemas de gameplay deste documento permanecem como trabalho planejado. O protótipo tem diretório de usuário próprio (`MythsValleyPrototype3D`); o passeio inicial não persiste progresso.

Foi corrigida a visibilidade de partes do torso habilitando as duas faces do material na instância. O defeito foi reproduzido na pose original e deixou de aparecer no comparativo com faces duplas. O FBX original permanece intacto. Testes locais cobrem importação, textura, escala, movimento, corrida, chão, colisão, câmera, reinício e reconhecimento dos três locais do passeio.

Impacto no plano: a estrutura `assets/`, `scenes/`, `scripts/` e `tools/` deste primeiro teste está sob `prototipo_3d/`. A organização evita inicializar os autoloads legados durante a validação do personagem. A integração de regras 2D será avaliada sistema a sistema. A licença de redistribuição do modelo deve ser confirmada antes de publicar seus arquivos.

### Registro da integração de animações — 23/09/2026

O segundo arquivo fornecido, `medieval+character+3d+model.glb`, reúne o personagem, o mesmo esqueleto de 65 ossos e 11 clipes exportados no Tripo. O protótipo passou a usar esse GLB. `idle`, `walk` e `run` são escolhidos automaticamente pela velocidade; oito gestos podem ser acionados pelas teclas 1–8 e são interrompidos quando o personagem volta a andar.

O arquivo foi validado com animações no lugar, deixando deslocamento e colisões sob responsabilidade do `CharacterBody3D`. O teste integrado agora confere os nomes dos clipes e a troca entre gestos e locomoção, além das validações anteriores. O passo a passo de uso, reexportação e mapeamento está em [COMO_JOGAR_3D.md](../experiencia/COMO_JOGAR_3D.md).

### Integração do Tripo com Codex — 23/09/2026

O projeto passou a declarar um servidor MCP `tripo` em `.codex/config.toml`, executado pelo Tripo CLI oficial. Isso permite solicitar ao Codex modelos baseados em texto ou imagem, acompanhar tarefas e gerar personagens com rig e animações preset. A instalação local e o fluxo de promoção de assets estão descritos em [TRIPO_MCP.md](../ferramentas/TRIPO_MCP.md).

Credenciais permanecem no perfil local do Tripo em `%USERPROFILE%\.tripo`; nenhuma chave deve entrar no repositório. Saídas experimentais ficam em `.assets-raw/tripo/` e só são promovidas a `prototipo_3d/assets/` depois de revisão de qualidade, licença e adequação ao Godot. As operações de geração e animação consomem créditos da conta do integrante que as executar.

### Primeira casa gerada e integrada — 24/09/2026

O fluxo semiautomático Tripo Studio → GLB → Godot foi validado com a casa de
Carro Quebrado. Uma imagem limpa em perspectiva 3/4 foi criada a partir da
referência fornecida, enviada ao Tripo Studio e processada no modelo H3.1. A
geração consumiu 65 créditos; a tarefa registrada é
`fef21312-d4d3-4b81-aefe-6ec4368759af`.

O GLB foi exportado com texturas 2K e otimizado com glTF Transform 4.5.0. A
versão de jogo reduziu o arquivo de aproximadamente 64,8 MB para 13 MB e a
geometria de 1.915.732 para 273.548 triângulos. O protótipo substitui pela casa
importada a construção procedural à direita da praça, mantendo escala automática,
apoio no terreno e colisão simples. O original pesado permanece em
`.assets-raw/tripo/casas/`, fora do Git; origem e condições de uso estão em
`prototipo_3d/assets/prototipo_3d/casas/ORIGEM.md`.

## 1. Objetivo e critérios de prioridade

Produzir uma experiência de aproximadamente **10–15 minutos**, com personagem controlável em terceira pessoa, uma pequena região explorável, um ciclo de farming concluível e um NPC com conversa por LLM e memória.

Ordem de prioridade definida:

1. Velocidade de desenvolvimento.
2. Qualidade gráfica.
3. Capacidade de expansão técnica.

A referência visual é **My Time at Evershine**, especialmente a imagem compartilhada: personagens estilizados, vegetação, iluminação agradável e composição de uma vila. A referência orienta a direção artística; não é compromisso de reproduzir a escala ou o acabamento integral daquele jogo na jam.

A equipe ainda será formada. Quantidade de integrantes, experiência e disponibilidade efetiva precisam ser confirmadas antes de distribuir o trabalho.

## 2. Requisitos definidos pelo produto

| Tema | Decisão |
| --- | --- |
| Plataforma | Windows; Steam como destino posterior, sem integração obrigatória nesta jam. |
| Navegador, mobile e consoles | Fora do escopo. |
| Modo de jogo | Single-player; sem multiplayer ou arquitetura de rede para gameplay. |
| Câmera | Terceira pessoa. |
| Mundo | Uma região com vila, fazenda, floresta e praia, representada de forma compacta na demo. |
| Construção pelo jogador | Não haverá construção, posicionamento livre de edificações ou sistema de obras. Compra de itens permanece na visão. |
| NPCs | Rotinas simples: casa, praça, pequenas interações e reação ao jogador. |
| IA generativa | Conversa e memória de NPCs; IA também auxilia o desenvolvimento. |
| Produção 3D | Tripo para praticamente todos os modelos de personagens, casas, objetos, equipamentos e vegetação. |
| Animação humana | Mixamo. |
| Modelagem manual | Não depender de Blender, retopologia ou modelagem manual para concluir a entrega. |
| Construção do cenário | Manual, dentro da engine; sem geração procedural complexa. |
| População desejada | Referência de 1–20 NPCs simultâneos e faixa semelhante para animais; não é quantidade mínima da demo nem garantia de desempenho. |
| Linguagem | Sem preferência prévia; favorecer produtividade com IA e integração com a base existente. |
| Prazo | Dois finais de semana de game jam, não um projeto de produção de vários anos. |

A visão de gameplay inclui plantio, criação de animais, coleta, mineração, pesca, crafting, economia, loja, combate, exploração, quests, NPCs, amizade e história principal. **A visão completa não deve ser confundida com o conjunto comprometido para quatro dias de produção.**

## 3. Decisão de engine e stack

### 3.1. Manter Godot nesta jam

**Decisão de trabalho: manter Godot Standard e GDScript; não migrar para Unity ou Unreal durante o protótipo.**

Motivo: aproveitar o contexto do projeto e avaliar o reaproveitamento das regras de inventário, relógio, missões, venda, oficina, afinidade e salvamento, em vez de somar uma migração de engine ao trabalho de construir a apresentação 3D.

Na consulta ao repositório em 23/09/2026, o `README.md` declara **Godot 4.7.2**, e o `project.godot` registra a linha **4.7**, renderer **GL Compatibility** e os autoloads citados. Isso documenta o estado declarado do projeto, não uma execução ou teste da instalação local. [R1] [R2]

Antes de iniciar, confirmar o executável realmente utilizado, testar uma exportação e registrar a versão exata. Todos os integrantes devem usar essa mesma versão e seus templates de exportação correspondentes. Não atualizar a engine no meio da jam sem necessidade comprovada.

### 3.2. Stack proposta

| Camada | Escolha | Condição ou limite |
| --- | --- | --- |
| Engine | Godot Standard, versão validada da base atual | Sem migração de engine. |
| Código do jogo | GDScript | Regras simples, tipadas quando útil, com pequenos módulos. |
| Renderer 3D | Forward+ | Adoção condicionada a teste no computador-alvo e na build Windows. |
| Personagem | `CharacterBody3D` | Movimento e colisão simples; sem sistema avançado de locomoção. |
| Câmera | `SpringArm3D` + `Camera3D` | Terceira pessoa com tratamento de obstáculos. |
| Animação | Mixamo + `AnimationPlayer`/`AnimationTree` | Conjunto pequeno de animações humanas validado na engine. |
| Navegação de NPCs | `NavigationRegion3D` + `NavigationAgent3D` | Rotas entre pontos e máquina de estados simples. |
| Modelos estáticos | Tripo → GLB → Godot | Validar escala, materiais, pivô e colisão. |
| Personagens humanos | Tripo → FBX → Mixamo → FBX → Godot | Validar rig, animações e materiais antes de produzir novos personagens. |
| Terreno | Geometria simples, montada manualmente | Terrain3D é opcional e depende de teste de compatibilidade/exportação. |
| Vegetação | Peças reutilizáveis; `MultiMeshInstance3D` quando apropriado | Objetos interativos continuam com estado e colisão próprios. |
| Interface | `Control` e recursos nativos do Godot | Reaproveitar regras de UI sem assumir que o layout 2D funcionará sem ajustes. |
| Dados e save | Recursos/dados simples e JSON local | Save exclusivo do protótipo 3D, sem sobrescrever o 2D. |
| Serviço de diálogo | TypeScript em Cloudflare Workers | Serviço pequeno; sem chave do provedor no cliente. |
| Provedor/modelo LLM | A definir por teste | Avaliar latência, custo e qualidade em português; não fixar um modelo sem teste. |
| Versionamento | Git/GitHub | Branch do protótipo; worktree local recomendado. |
| Entrega | Build Windows empacotada em ZIP | Entregar todos os arquivos necessários, não somente o executável. |

Esses componentes são escolhas de implementação, não dependências já instaladas ou funcionalidades já prontas.

### 3.3. Renderer e terreno

Forward+ é a primeira opção a testar para a apresentação 3D desktop. Sua adequação depende do hardware, e a troca de renderer pode exigir ajustes de cena, luz e ambiente. O projeto atual está em Compatibility; a mudança deve ocorrer apenas na branch do protótipo. [R2] [T1]

Começar com terreno simples. Não tornar Terrain3D obrigatório antes de validar a combinação **versão da engine + versão do addon + renderer + exportação Windows**.

Se um addon bloquear a primeira cena jogável, seguir sem ele. Não mudar toda a versão da engine apenas para acomodar uma ferramenta opcional.

## 4. Escopo da demonstração

### 4.1. Núcleo da entrega

| Sistema | Recorte proposto para a jam |
| --- | --- |
| Exploração | Uma área compacta ligando fazenda, pequena praça, trecho de mata e vista/acesso limitado à praia. |
| Personagem | Andar, correr e interagir, com câmera funcional. Pulo não é requisito do percurso principal. |
| Farming | Uma ou duas culturas: preparar, plantar, regar, crescer e colher. |
| Tempo | Crescimento acelerado ou avanço ao dormir; evitar espera longa para concluir a demo. |
| Coleta | Poucos recursos necessários ao ciclo principal. |
| Inventário | Adicionar, selecionar e consumir itens; feedback visível. |
| Loja e economia | Uma moeda, uma loja, poucos produtos; comprar sementes e vender a colheita. |
| Crafting | Uma receita relacionada à missão. |
| História | Uma missão principal curta, com aproximadamente três etapas e encerramento claro. |
| NPCs | Três personagens relevantes como meta de conteúdo inicial, não vinte. |
| Amizade | Um valor simples de afinidade e reação a uma ação do jogador. |
| LLM e memória | Um NPC com conversa livre, contexto do jogo e lembrança persistida. |
| Save | Fechar e reabrir preservando o progresso essencial e a memória demonstrada. |

### 4.2. Extensões condicionais

Mineração simplificada pode reutilizar a interação de coleta, com uma rocha e um recurso. **Animais, pesca e combate entram somente depois de o percurso principal estar completo e estável.**

Uma eventual criação de animais deve começar com uma única espécie e uma interação curta, como alimentar e receber um produto. Não incluir reprodução, genética ou simulação complexa.

Esses adiamentos pertencem ao recorte da jam. Não representam exclusão definitiva das mecânicas da visão do produto.

### 4.3. Fora do escopo

Sem multiplayer, construção pelo jogador, mundo aberto extenso, geração procedural complexa, sistemas de estações completos, romance, customização extensa, interiores numerosos, integração Steam, IA autônoma para toda a população, voz sintética ou banco vetorial obrigatório.

Não iniciar uma reescrita geral da base, um framework genérico de RPG ou uma arquitetura para funcionalidades não usadas na demo.

### 4.4. Exemplo de percurso jogável

**Proposta narrativa, ainda não roteiro aprovado:** chegar ao vale → conhecer um morador → receber sementes → cultivar um ingrediente → preparar um presente → entregá-lo → conversar novamente e perceber que o morador lembra da ajuda e de algo contado antes.

Essa proposta conecta farming, coleta, crafting, economia, história, amizade e memória. O tema divulgado na página local do Tripothon é **“A Gift for ____”**; a relação final com ele deve ser explicitada na apresentação. [E1]

## 5. Pipeline de assets

### 5.1. Validar um asset completo antes de produzir em volume

Primeiro teste obrigatório: um personagem gerado no Tripo, animado no Mixamo, importado no Godot e funcionando em uma build Windows fora do editor.

O teste deve verificar exportação disponível na conta, textura, escala, orientação, rig, deformação, animação e arquivo final distribuível. Uma imagem do modelo no Tripo não valida esse pipeline.

### 5.2. Personagens humanos

Fluxo: **Tripo → FBX → Mixamo → FBX animado → Godot**.

Gerar em pose neutra, preferencialmente T-pose, com membros distinguíveis e sem ferramentas fundidas às mãos. Evitar, na primeira validação, capas muito complexas ou acessórios que ocultem as articulações. A documentação do Mixamo descreve limitações de pose, geometria e grandes acessórios no auto-rig. [T3]

Ferramentas e objetos de mão devem ser assets separados. Validar parado, andando e correndo antes de aprovar o personagem. Regenerar ou simplificar um modelo problemático, em vez de depender de reparo manual no Blender.

O Godot documenta suporte a FBX por `ufbx` e recomenda glTF para intercâmbio 3D. Isso não dispensa conferir materiais, esqueleto e animações no resultado importado. [T2]

### 5.3. Objetos estáticos

Fluxo preferencial: **Tripo → GLB → Godot**. GLB é a variante binária de glTF aceita pela engine. [T2]

Para cada asset, revisar tamanho em relação ao personagem, pivô, orientação, textura, material e colisão. Usar colisões simples quando forem suficientes. Importar o modelo em uma cena reutilizável, mantendo configurações de gameplay separadas do arquivo gerado.

### 5.4. Animais

Mixamo é o pipeline humano: o auto-rig e a biblioteca descritos pela Adobe são para humanoides bípedes, não uma solução geral para animais de fazenda. [T3]

Caso animais entrem na demo, testar uma alternativa de rig/animação, como os recursos disponíveis na conta Tripo, e validar o resultado na engine. Não comprometer a entrega com um animal animado antes desse teste.

### 5.5. Vegetação, consistência e orçamento visual

Produzir poucas variantes de árvores, arbustos, pedras e plantas para reutilização. Não gerar a floresta inteira como uma única malha. Separar decoração de recursos interativos.

Começar com texturas de 1K–2K como orçamento de trabalho, não como exigência universal. Não utilizar 8K por padrão. Medir o resultado visual e o consumo antes de aumentar resolução ou densidade.

Registrar origem, ferramenta, arquivo exportado e condições de uso de cada asset. Não presumir direitos de redistribuição dos arquivos brutos só porque o modelo foi gerado ou baixado.

## 6. Arquitetura e reaproveitamento da base 2D

**Separar regras de jogo de sua apresentação espacial.** Reaproveitar somente o que passar no teste de integração, sem prometer conversão automática de 2D para 3D.

| Tratamento | Exemplos |
| --- | --- |
| Avaliar reaproveitamento | Catálogo, inventário, preços, receitas, relógio, estado de missões e afinidade. |
| Implementar para 3D | Movimento, câmera, detecção de interação, colisões, navegação e animações. |
| Adaptar e testar | HUD, diálogos, salvamento, coordenadas e dependências de cenas/autoloads 2D. |

Não carregar autoloads ou telas legadas apenas por existirem. Revisar suas dependências antes de habilitá-los na nova cena. Alterações em `project.godot`, renderer e cena inicial ficam na branch do protótipo.

Estrutura incremental sugerida, sem mover desnecessariamente os diretórios atuais:

```text
assets/prototipo_3d/       # Modelos e texturas aprovados
scenes/prototipo_3d/       # Mundo, personagem, NPCs e interações
scripts/prototipo_3d/      # Comportamentos específicos de 3D
data/prototipo_3d/         # Dados exclusivos da demo, quando necessários
services/npc-gateway/      # Serviço de diálogo; não exportar como recurso do jogo
docs/projeto/DECISOES_PROTOTIPO_3D.md
```

O save deve usar um caminho próprio, por exemplo `user://prototipo_3d/save_v1.json`, com versão de formato explícita. **Branch e worktree não isolam automaticamente o diretório de save do aplicativo.** Evitar que as duas versões leiam ou sobrescrevam o mesmo arquivo.

A resolução de UI e as configurações herdadas de pixel art também devem ser revistas na branch 3D; não assumir que o perfil visual da versão 2D atende ao novo protótipo.

## 7. NPCs, LLM e memória

### 7.1. Responsabilidades

**O código define os fatos do mundo. O LLM produz a fala do personagem sobre esses fatos.**

Rotinas como casa → praça → casa usam navegação e uma máquina de estados. Conversas de ambientação entre NPCs podem ser roteirizadas. O LLM não controla deslocamento, economia, conclusão de quests ou entrega de itens.

A conversa livre não pode ser uma dependência para concluir a missão principal.

### 7.2. Comunicação

```text
Jogador
  → UI de diálogo no Godot
  → requisição HTTPS assíncrona
  → serviço TypeScript em Cloudflare Workers
  → API do modelo escolhido
  → validação da resposta
  → texto apresentado no jogo
```

Guardar a chave do provedor como secret no serviço, nunca no projeto distribuído, no executável ou no repositório. Workers oferece secrets para valores sensíveis. [T4]

O serviço deverá validar tamanho e formato de entrada, limitar respostas, impor timeout, limitar chamadas e estabelecer um teto de gasto. Um segredo escondido dentro do jogo não deve ser tratado como autenticação segura do serviço.

Não confiar no conteúdo enviado pelo cliente como instrução administrativa. Não transformar texto do modelo em código executável ou comandos de gameplay.

### 7.3. Memória mínima

Usar três componentes por NPC: fatos relevantes registrados pelo jogo, resumo curto da relação e uma pequena janela de conversa recente. Persistir o necessário no save local.

Exemplo de estrutura de dados, não contrato obrigatório de API:

```json
{
  "npc_id": "morador_01",
  "afinidade": 1,
  "fatos_do_jogo": ["presente_entregue"],
  "resumo_da_relacao": "O jogador ajudou na primeira colheita.",
  "conversa_recente": []
}
```

Fatos confirmados e resumos gerados devem permanecer distinguíveis. Um resumo do modelo não pode alterar o estado de uma missão. Evitar enviar todo o livro ou todo o histórico em cada chamada.

Não há banco vetorial, servidor de save ou infraestrutura de agentes obrigatórios na jam. O provedor do modelo, o orçamento e a política de retenção precisam ser definidos antes do teste público.

### 7.4. Falhas e dados

Em caso de timeout, indisponibilidade ou falta de internet, apresentar diálogos escritos previamente e indicar que a conversa livre está indisponível. A interface não deve congelar e a missão deve continuar concluível.

Avisar que a conversa livre usa um serviço online. Evitar solicitar dados pessoais reais; não registrar conversas completas em logs de produção por padrão. Manter uma opção para reiniciar a memória da demo.

## 8. Git: branch, não fork, para esta etapa

### 8.1. Decisão

Manter o protótipo no mesmo repositório, em **`prototype/myths-valley-3d`**, preservando a linha 2D em `main`. Branches isolam linhas de desenvolvimento dentro de um repositório; forks são repositórios separados, ligados a um original. [G1] [G2]

```text
acentauric/myths-valley
├── main                         # Linha 2D preservada
└── prototype/myths-valley-3d     # Integração da demo 3D
```

Essa decisão evita criar agora outro espaço de issues e colaboração apenas para experimentar o 3D. **Não há obrigação de fazer merge da demo inteira de volta na main.**

Após a jam, decidir entre integrar o resultado, encerrar o experimento ou separar o 3D em um produto/repositório próprio. Não manter duas linhas de produto divergentes indefinidamente sem revisar essa estratégia.

Um fork pode fazer sentido para colaboração externa sem acesso de escrita ou para uma derivação com manutenção independente. Não é necessário apenas para obter outra pasta no computador. [G2] [G3]

### 8.2. Worktree recomendado

Usar uma segunda pasta local para trabalhar no 3D sem alternar a pasta aberta no editor do 2D. `git worktree` permite manter branches diferentes em diretórios de trabalho separados, compartilhando o mesmo repositório Git. [G3]

```text
pasta-de-projetos/
├── myths-valley/                 # Editor/IDE da versão 2D
└── myths-valley-3d/              # Editor/IDE da branch do protótipo
```

Worktree complementa a branch; não a substitui. Apontar o editor e a sessão de desenvolvimento assistido por IA para a pasta correta antes de fazer alterações.

### 8.3. Procedimento sugerido

**Não executado por este documento.** Os comandos abaixo supõem um clone existente, remoto chamado `origin`, branch remota `main` e permissão de escrita.

Antes de começar, verificar `git status --short` e `git remote -v`. Fazer commit e publicar na `main` quaisquer alterações 2D que devam compor a base. O comando abaixo parte da **main remota publicada**, não de arquivos locais não commitados ou de commits locais ainda não enviados.

Na pasta do clone existente, executar cada comando somente após o anterior concluir sem erro:

```bash
git fetch origin
git worktree add -b prototype/myths-valley-3d ../myths-valley-3d origin/main
git -C ../myths-valley-3d branch --show-current
git -C ../myths-valley-3d push -u origin prototype/myths-valley-3d
```

Se a branch ou a pasta já existir, inspecionar antes de continuar. Não usar opções de força para sobrescrever trabalho.

Antes do primeiro commit 3D, registrar a base com uma tag anotada, depois de conferir que o `HEAD` ainda corresponde à base desejada:

```bash
git -C ../myths-valley-3d tag -a baseline-2d-pre-3d-20260923 -m "Base 2D anterior ao prototipo 3D"
git -C ../myths-valley-3d push origin baseline-2d-pre-3d-20260923
```

Copiar este arquivo para `../myths-valley-3d/docs/projeto/DECISOES_PROTOTIPO_3D.md`. Depois:

```bash
git -C ../myths-valley-3d add docs/projeto/DECISOES_PROTOTIPO_3D.md
git -C ../myths-valley-3d commit -m "docs: registrar decisoes do prototipo 3D"
git -C ../myths-valley-3d push
```

Sem necessidade de manter os dois projetos abertos ao mesmo tempo, também é possível trabalhar somente com uma branch na pasta atual. Fechar o editor antes de alternar a branch reduz o risco operacional de editar a versão errada.

### 8.4. Trabalho em equipe e assets binários

Usar branches pequenas por tarefa, derivadas da branch 3D, e PRs com destino a **`prototype/myths-valley-3d`**, não automaticamente a `main`. Definir um responsável pela integração e evitar edição simultânea da mesma cena por várias pessoas.

Não versionar caches `.godot/`, builds, credenciais ou arquivos temporários. Manter fontes necessárias, cenas, scripts e configurações de importação apropriadas à versão da engine. [G4]

Avaliar/configurar Git LFS antes de adicionar muitos modelos e texturas binários. LFS armazena ponteiros no Git e os conteúdos em armazenamento separado; todos precisam conseguir obter os arquivos reais. Conferir configuração e quotas da conta antes de adotá-lo. [G5]

Guardar rascunhos, gerações rejeitadas e renders pesados fora do conjunto de assets aprovados. Não enviar arquivos brutos ao repositório público sem verificar suas condições de distribuição.

## 9. Plano dos dois finais de semana

| Data | Trabalho principal | Resultado de saída |
| --- | --- | --- |
| Sábado, 26/09 | Validar Tripo → Mixamo → Godot; personagem, câmera, colisão e cenário básico | Build Windows com personagem animado, controlável fora do editor. |
| Domingo, 27/09 | Plantio, inventário, loja e missão curta | Percurso principal concluível, mesmo com arte provisória. |
| Sábado, 03/10 | Composição visual, NPCs, rotina, LLM e memória | Experiência identificável como Myths' Valley, com conversa e lembrança testadas. |
| Domingo, 04/10 | Correções, desempenho, save, teste externo e materiais | Build final empacotada, walkthrough e painel de assets. |

Este é um plano de trabalho condicionado à disponibilidade da equipe, hardware e acesso às ferramentas. Se o percurso principal não estiver pronto em 27/09, o segundo fim de semana começa por concluí-lo. Não acrescentar pesca, combate ou população extra nesse cenário.

Frentes de trabalho propostas: integração/gameplay; assets/composição; NPCs/diálogo/testes. Uma pessoa pode acumular frentes, mas isso exige redimensionar o conteúdo.

## 10. Definição de pronto

### Produto

- [ ] O jogo abre em uma máquina de teste sem depender do editor Godot.
- [ ] O jogador entende o objetivo, movimenta-se e conclui a missão principal.
- [ ] Plantar, colher, comprar/vender e executar a receita não bloqueiam a progressão.
- [ ] A câmera e as colisões funcionam no percurso completo.
- [ ] Os NPCs essenciais estão acessíveis e suas rotinas não bloqueiam interações.
- [ ] Pelo menos um NPC demonstra conversa por LLM e memória em teste online.
- [ ] Sem internet, o jogo informa a limitação e continua concluível com falas roteirizadas.
- [ ] Save e retomada preservam os estados essenciais sem afetar o save 2D.

### Técnica e entrega

- [ ] A versão exata de Godot, os templates e as dependências foram registrados.
- [ ] O desempenho foi medido no computador de referência; não apenas estimado.
- [ ] A build não contém chaves, credenciais ou arquivos do backend desnecessários.
- [ ] Timeout, limites de uso e teto de gasto do diálogo estão configurados.
- [ ] Um integrante diferente de quem integrou a build testou o pacote final.
- [ ] A versão entregue tem commit/tag identificável e instruções de execução.
- [ ] A relação de assets e créditos acompanha a entrega conforme necessário.

## 11. Pacote de apresentação e conferência do evento

Preparar como pacote de trabalho: build jogável Windows, instruções curtas, gravação real do percurso, painel visual de assets e registro do pipeline Tripo → engine. Um build log público é material adicional, não dependência técnica do jogo.

**Não tratar este documento como regulamento do Tripothon.** Antes de submeter, conferir no formulário vigente: prazo/fuso, formato e acesso aos arquivos, duração de vídeo, categorias, uso de ferramentas e regras para projetos/código anteriores ao evento.

A página local consultada confirma o tema e orienta registrar/submeter online e selecionar São Paulo para o Demo Day. A página central não forneceu texto legível nesta verificação; por isso o prazo e a lista formal de entregáveis permanecem itens de conferência, e não exigências revalidadas por este arquivo. [E1] [E2]

Se houver reaproveitamento permitido, identificar claramente o que já existia na base 2D e o que foi produzido para o protótipo. Não afirmar elegibilidade sem verificar as regras aplicáveis.

## 12. Pendências que podem mudar o plano

| Pendência | Impacto |
| --- | --- |
| Pessoas confirmadas, experiência e horas disponíveis | Define divisão de trabalho e volume de conteúdo. |
| GPU, RAM e computador mínimo de referência | Define renderer, vegetação e orçamento visual. |
| Versão real da engine e exportação Windows | Bloqueio técnico antes de produzir em volume. |
| Exportação, texturas e condições de uso da conta Tripo | Bloqueio do pipeline de assets. |
| Primeiro humano aprovado no Mixamo/Godot | Confirma viabilidade do pipeline sem Blender. |
| Terrain3D, apenas se necessário | Exige teste de compatibilidade; não bloqueia o terreno simples. |
| Provedor/modelo LLM e orçamento | Define serviço, limites e qualidade do diálogo. |
| Roteiro final e relação com o tema | Define missão e materiais de apresentação. |
| Formulário/regras atuais da competição | Define submissão e possibilidade de reaproveitamento. |

**Regra para mudanças:** registrar a alteração neste documento e seu impacto no prazo. Funcionalidade nova deve substituir esforço equivalente ou permanecer fora do compromisso da jam.

## 13. Referências consultadas

As referências técnicas sustentam compatibilidades e conceitos; a seleção da stack e o recorte de escopo são decisões deste projeto. Consultas realizadas em 23/09/2026.

### Estado do projeto

- **[R1]** `README.md` da branch `main`: declaração de Godot 4.7.2 e contexto do projeto. Caminho relativo: `../README.md`.
- **[R2]** `project.godot` da branch `main`: renderer Compatibility, linha 4.7 e autoloads. Caminho relativo: `../project.godot`.
- Na consulta inicial, a branch `main` remota apontava para `b5071c0284075e14b22c3537e2ddc6986087eb39`.
- A base efetiva do protótipo foi criada em `badf62cefe2115990f7a608cc993bb945c9089e8`, depois de integrar e publicar as mudanças locais e remotas da linha 2D. Esse commit está marcado pela tag anotada `baseline-2d-pre-3d-20260923`.

### Documentação técnica

- **[T1]** Godot — Overview of renderers. `https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html`
- **[T2]** Godot — Available 3D formats. `https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html`
- **[T3]** Adobe — Mixamo FAQ. `https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html`
- **[T4]** Cloudflare Workers — Secrets. `https://developers.cloudflare.com/workers/configuration/secrets/`

### Versionamento

- **[G1]** GitHub — Branches. `https://docs.github.com/en/pull-requests/reference/branches`
- **[G2]** GitHub — Forks. `https://docs.github.com/en/pull-requests/reference/forks`
- **[G3]** Git — git-worktree. `https://git-scm.com/docs/git-worktree`
- **[G4]** Godot — Version control systems. `https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html`
- **[G5]** GitHub — About Git Large File Storage. `https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-git-large-file-storage`

### Evento

- **[E1]** Tripothon S1 — página local do Demo Day de São Paulo. `https://luma.com/88qs1nnw`
- **[E2]** Tripothon S1 — página central indicada pela organização; consultar o formulário e regulamento antes da entrega. `https://developers.tripo3d.ai/en/events/tripothon-s1`
