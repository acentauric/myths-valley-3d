# Licenças dos assets — auditoria para a #42

Levantamento de 09/10/2026 (documental: feito sobre os `ORIGEM.md`, `LEIAME.md`,
`assets/CREDITOS.md`, as licenças em `assets/fonts/` e os manifestos do
repositório; **nenhum termo foi reconsultado na web nem em conta de provedor**
e nenhum asset foi gerado). O build já está público (Builds 9, 9B e 10), então
cada linha "a comprovar" é risco de um build que já circula.

Legenda de **Prova**: o que existe no repositório hoje. "Declaração" quer dizer
só texto do próprio projeto, sem arquivo do provedor.

## Quadro por fonte

| Fonte | Onde está | Licença / base | Uso comercial | Redistribuir dentro do jogo | Atribuição exigida | Prova hoje | Situação |
|---|---|---|---|---|---|---|---|
| Cinzel | `assets/fonts/Cinzel-Variavel.ttf` | SIL OFL 1.1 | Sim | Sim (embutida; sem vender a fonte isolada) | Manter o aviso de copyright e o texto da OFL | `assets/fonts/OFL-Cinzel.txt` | **Comprovada** |
| Cormorant Garamond | `assets/fonts/CormorantGaramond-*.ttf` | SIL OFL 1.1 | Sim | Sim, idem | Idem | `assets/fonts/OFL-CormorantGaramond.txt` | **Comprovada** |
| Almendra Bold | `assets/fonts/Almendra-Bold.ttf` | SIL OFL 1.1 (Ana Sanfelippo), segundo `CREDITOS.md` | Sim | Sim | Aviso de copyright e OFL | Só declaração; **não há `OFL-Almendra.txt`** | **A comprovar** (copiar o texto da OFL da fonte) |
| Miva | `assets/fonts/miva.ttf` | Fonte própria da equipe | Sim | Sim | Não | Declaração do responsável em 03/10/2026 (`CREDITOS.md`) | Declarada; sem arquivo |
| Godot Engine 4.7.2 | binário do export | MIT | Sim | Sim | Aviso MIT e lista de terceiros do Godot no pacote | Nada no repositório | **A comprovar** (incluir licenças do Godot no build, em Sobre/créditos ou arquivo) |
| Addon `godot_mcp` 0.6.0 | `addons/godot_mcp/` | MIT, auditado no commit 00264f0 (`docs/ferramentas/GODOT_MCP.md`) | Sim | Só ferramenta de editor; conferir se fica fora do export | Aviso MIT | **Sem arquivo LICENSE na pasta** | **A comprovar** (copiar o LICENSE; excluir do export) |
| Tripo Studio / API (GLBs `*_tripo.glb`: árvores, construções, casas, aderecos, móveis, personagens, animais, peixes, itens, mar) | `assets/prototipo_3d/**` | Termos do Tripo: plano pago concede uso comercial; plano Max no momento da geração | Sim, **se** a licença sobreviver ao cancelamento da assinatura | Sim, embutido no jogo | A confirmar nos termos vigentes | `ORIGEM.md` de cada pasta (tarefa, faces, textura); `tools/tripo/lote_*.json`; e-mail de ativação do plano Max (não está no repositório); extrato de créditos de 05–06/10 | **A comprovar** (suporte do Tripo: validade pós-cancelamento, `ASSETS_TRIPO.md`; guardar a resposta) |
| Personagem jogável `medieval_character_animated.glb` | `assets/prototipo_3d/personagem/` | **Sem licença** ("nenhum dos arquivos veio acompanhado de licença"); origem: projeto próprio do Tripo Studio, exportado em 23–26/09 | Provavelmente igual ao Tripo, mas não provado | Idem | Idem | Só o `ORIGEM.md` (com SHA-256) | **Bloqueio da #42**: provar a origem no Studio ou trocar pelo `viajante_tripo.glb` (#55) |
| Viajante, tubarão e moradores com rig | `personagens/viajante_tripo.glb`, `mar/tubarao_tripo.glb`, `personagens/*_tripo.glb` | Tripo Studio, rig e animações do próprio Tripo | Idem Tripo | Idem | Idem | `ORIGEM.md` + `CREDITOS.md` (créditos gastos) | Cobertos pela linha Tripo |
| Animações Mixamo | `assets/prototipo_3d/personagens/mixamo/*.res` | Termos do Mixamo/Adobe: livres em projetos, inclusive comerciais; **proíbem redistribuir como arquivos soltos** | Sim | Só incorporadas e redirecionadas (os FBX ficam fora do repositório) | Não exigida | `mixamo/LEIAME.md`, `data/mixamo_uso.json` | **A comprovar** (cópia dos termos vigentes da Adobe; confirmar que `.res` redirecionado conta como incorporado) |
| ElevenLabs: vozes, narração, músicas e efeitos | `assets/audio/{vozes,narracao,musica,efeitos,ambiente}`, `assets/audio/fontes/introducao_2026` | Termos do ElevenLabs conforme o plano da conta na geração; vozes da biblioteca (Weverton, Manoel Lopes, Edna, Matheus etc.) e a voz "BDM · Nelson Silvestre · Narrador" | Depende do plano pago e da licença de **cada voz da biblioteca** | Embutidas no jogo, sim, se o plano permitir | Conferir (voz de biblioteca pode exigir) | `CREDITOS.md`, `tools/elevenlabs/*.ps1`, `fontes/introducao_2026/manifesto.json`; declaração do responsável em 03/10/2026 | **A comprovar** (plano ativo na data da geração, termos das vozes de biblioteca, autorização da voz Nelson Silvestre) |
| OpenAI `gpt-image-1/2`: capas, logotipo, moldura, rosa, cordéis, ícones HUD | `assets/prototipo_3d/{identidade,cordeis}`, `assets/sprites/icones` | Termos da OpenAI: a saída pertence ao usuário, sujeita às políticas | Sim | Sim | Não | `ORIGEM.md` + `tools/openai/*.json` (prompts) | **A comprovar** (guardar cópia dos termos vigentes; sem cópia, só a menção em `CREDITOS.md`) |
| LTX (Lightricks): vídeo do lobby | `assets/prototipo_3d/identidade/video/carregamento_sobrevoo.ogv` | Termos da API LTX | Conferir | Conferir | Conferir | Só texto em `CREDITOS.md` | **A comprovar** (não há `ORIGEM.md` próprio nem termos arquivados) |
| Whisper (OpenAI) | usado só para cortar a narração | Termos da OpenAI | Sim | Nada embutido | Não | `CREDITOS.md` | Sem risco (ferramenta) |
| PixelLab: itens, moradores, talentos (39), luva | `assets/sprites/{itens,moradores,talentos,cofre}` | Termos do PixelLab conforme o plano | Conferir plano | Conferir | Conferir | `CREDITOS.md`, `cofre/REGISTRO.tsv` | **A comprovar** (termos e plano ativo) |
| Carta náutica DHN 1108 | `data/mapas/bom_jesus_dos_pobres_batimetria.bin` (derivado) | Carta da Marinha do Brasil; a grade é obra derivada | Conferir | Só a grade derivada; a carta fica em `.assets-raw` | Citar a fonte (DHN) | `mar/ORIGEM.md`, `CREDITOS.md` | **A comprovar** (condições de uso das cartas da DHN) |
| Latido do Caramelo | `assets/audio/animais/caramelo_latido.wav` | CC0 1.0, Brandon Morris (HaelDB), OpenGameArt | Sim | Sim | Não exigida (cortesia) | `animais/ORIGEM.md` (URL, SHA-256, conferida 07/10) | **Comprovada** |
| Moldura de idioma | `assets/ui/moldura_idioma.svg` | Adaptação do site do próprio projeto | Sim | Sim | Não | `CREDITOS.md` | Própria |
| Texturas de chão, shaders, cursores, `ceu`, `fauna` | `assets/prototipo_3d/{materiais,ceu,fauna}`, `identidade/cursores` | Procedurais (scripts do projeto), exceto `grama_terra_mata_v1.png` e `estrada_terra_ocre_v1.png` (ferramenta de imagem integrada) | Sim / conferir as duas | Sim | Não | `materiais/ORIGEM.md` | As duas texturas geradas entram na linha "a comprovar" da ferramenta de imagem |
| Código GDScript, dados, textos | `scripts/`, `data/` | Do projeto | — | — | — | Não há arquivo `LICENSE` na raiz | Decidir a licença do repositório (público) |

## O que falta comprovar (lista de ação)

Ordem por risco para o build público:

1. **Personagem jogável** sem licença: provar a origem no Tripo Studio (projeto
   próprio, plano pago) ou trocar pelo viajante (#55). Bloqueia o aceite da #42.
2. **Tripo após cancelar a assinatura**: resposta do suporte, por escrito,
   arquivada em `docs/projeto/`.
3. **ElevenLabs**: plano na data de cada lote, termos de cada voz de biblioteca e
   autorização da voz "Nelson Silvestre".
4. **OpenAI, LTX e PixelLab**: arquivar os termos vigentes (data e texto) e o plano
   usado na geração.
5. **Carta DHN 1108**: condições de uso e forma de citação.
6. **Mixamo**: termos da Adobe arquivados; confirmar a leitura sobre `.res`.
7. **Almendra e `godot_mcp`**: acrescentar os arquivos de licença; tirar o addon do export.
8. **Godot**: incluir o aviso MIT e as licenças de terceiros no pacote.
9. **Licença do repositório** (código e dados), por ser público.
10. Pacote da submissão (#40): ver `docs/projeto/TRIAGEM_TRIPOTHON.md`.

O que não puder ser provado sai do build ou é trocado, como pede a issue.
As atribuições para o pacote e para a tela de créditos estão em
[`assets/ATRIBUICOES.md`](../../assets/ATRIBUICOES.md).

## Critérios de aceite da #42

- [ ] Cada item com a licença conferida e a fonte anotada em `assets/CREDITOS.md`:
  este documento levanta; a conferência das linhas "A comprovar" é humana.
- [ ] O que não puder ser publicado sai ou é trocado: depende dos itens 1–3.
- [ ] Créditos no pacote da submissão (#40): o texto está pronto em `ATRIBUICOES.md`;
  falta incluí-lo no pacote e na tela de créditos do jogo.
