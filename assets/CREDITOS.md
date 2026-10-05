# Créditos dos assets do jogo 3D

Os registros de origem acompanham os modelos e suas fontes de produção.

## Moldura da seleção de idioma e dos painéis internos

`ui/moldura_idioma.svg` adapta os filetes e a talha de acanto da home do
próprio Myths' Valley, definidos em `resources/views/components/moldura.blade.php`
e `resources/views/layouts/site.blade.php` do projeto do site. Os cantos são
preservados em nove fatias; a identidade compartilhada usa o mesmo desenho no
menu e nos painéis internos. Não há dependência de fontes ou de recursos remotos.

## Áudio (gerado por IA)

| Pasta | O que tem |
|-------|-----------|
| `audio/narracao/` | Narração de abertura, voz **BDM · Nelson Silvestre · Narrador** — a voz do narrador do próprio projeto |
| `audio/musica/` | Trilha do roçado, 45s em loop |
| `audio/efeitos/` | arar, regar, colher, pegar, dormir |

Gerado no ElevenLabs. Ver [docs/sistemas/AUDIO.md](../docs/sistemas/AUDIO.md).

## Modelos 3D do protótipo (gerados no Tripo Studio)

| Arquivo (em `assets/prototipo_3d/`) | O que é | Registro |
|---|---|---|
| `personagem/medieval_character_animated.glb` | personagem jogável, rig e 12 clipes | `personagem/ORIGEM.md` |
| `casas/casa_carro_quebrado_tripo.glb` | casa de Carro Quebrado (imagem → 3D) | `casas/ORIGEM.md` |
| `arvores/pau_brasil_tripo.glb` | pau-brasil (imagem → 3D) | `arvores/ORIGEM.md` |
| `arvores/mangueira_tripo.glb`, `jaqueira_tripo.glb`, `cajueiro_tripo.glb`, `coqueiro_tripo.glb` | árvores do Recôncavo (texto → 3D, 26/09/2026) | `arvores/ORIGEM.md` |
| `construcoes/capela_tripo.glb`, `construcoes/poco_tripo.glb` | capela colonial e poço de pedra (texto → 3D, 26/09/2026) | `construcoes/ORIGEM.md` |

Gerados na conta Tripo do projeto (plano Max no momento da geração). A
[ajuda oficial](https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially)
concede uso comercial a planos pagos; conferir as condições vigentes antes de
publicar. Cada `ORIGEM.md` guarda a tarefa Tripo, contagem de triângulos e a
redução aplicada. Texturas de chão (`materiais/terra_batida_v1.png`,
`chao_praca_v1.png`, `areia_praia_v1.png`, `base_arvore_v1.png`) são procedurais,
geradas por script do projeto.

### Lote Tripo e vozes do protótipo 3D (26/09/2026)

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/{arvores,construcoes,casas,aderecos,personagens,itens}/*_tripo.glb` | 68 modelos do Tripo Studio (texto → 3D, retopologia Malha Smart) | `ORIGEM.md` de cada pasta e `tools/tripo/lote_2026-09-26.json` |
| `assets/audio/vozes/*.mp3` | saudações dos moradores e narrações do Pedro, ElevenLabs Text to Speech (Eleven v3), vozes da biblioteca em português do Brasil: Weverton (Pedro), Borges (Benedito), Katiuscia (Zefa), Matheus – Energetic and Dynamic (Cosme), Matheus Santos (Tonho), Ana Alice (Filó), Ana Dias (Candinha), Matheus – Clear, Calm and Confident (Damião) | `docs/mundo/VALE_VIVO_3D.md` |
| `assets/audio/ambiente/{mata_dia,mata_noite,riacho,fogueira}.mp3` | loops de 24 s gerados no ElevenLabs Sound Effects | `docs/mundo/VALE_VIVO_3D.md` |
| `assets/audio/efeitos/{corrida_*,passo_agua_funda,passo_nado}.mp3` | corrida por tipo de chão, passo na água funda e braçada, ElevenLabs Sound Effects (27/09/2026) | `tools/elevenlabs/gerar-efeitos-3d.ps1` |

Os textos das vozes saem de `data/dialogos/aldeoes.json` e `pedro.json`; os áudios
são produzidos com ElevenLabs Text to Speech.

Em 03/10/2026, o responsável confirmou que as falas e vozes do jogo foram
produzidas pela equipe de forma generativa para o projeto. Os nomes acima
registram as vozes utilizadas na geração dos áudios.

### Dados geográficos do protótipo 3D

| Arquivo | Fonte | Registro |
| --- | --- | --- |
| `data/mapas/bom_jesus_dos_pobres_batimetria.bin` | derivado da carta náutica **DHN 1108** (Baía de Todos os Santos — Porto de São Roque e proximidades, 1:15.000), Diretoria de Hidrografia e Navegação da Marinha do Brasil | `assets/prototipo_3d/mar/ORIGEM.md` |

A carta original não é redistribuída (fica em `.assets-raw/`); o jogo leva só a grade
de profundidade derivada. Conferir as condições de uso das cartas da DHN antes de
publicar.

### Lote do lugar (28/09/2026)

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/{arvores,construcoes,aderecos}/{coqueiro,castanhola,aroeira,igreja,pedras_praia,pedra_mare,bote,canoa_amarela}_tripo.glb` | 8 modelos do Tripo Studio (texto → 3D + Malha Smart) descrevendo os elementos reais de Bom Jesus dos Pobres a partir de fotos do lugar: a igreja, os coqueiros, as castanholas, as pedras da praia e do recife, e os barcos sem letreiro | `ORIGEM.md` de cada pasta |
| `assets/prototipo_3d/arvores/{mangue,piacava,ingazeiro,clusia,pitangueira,jenipapeiro,sub_bosque}_tripo.glb` | 7 espécies da vegetação local de Saubara (manguezal, restinga, beira de rio), Tripo Studio | `arvores/ORIGEM.md` |
| `assets/audio/musica/musica_{manha,tarde,noite,mata}.mp3` | músicas por período do dia e da mata fechada, ElevenLabs Music (instrumental) | `tools/elevenlabs/gerar-musicas-periodos.ps1` |
| `assets/audio/{efeitos,ambiente}/…` (bem-te-vi, sussurros da mata, passos v2, lama, poça, tubarão) | efeitos novos do ElevenLabs Sound Effects | `tools/elevenlabs/gerar-sons-vale.ps1` |

### Identidade visual do protótipo 3D (28/09/2026)

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/identidade/{logo_myths_valley.png,capa_dia.webp,capa_noite.webp,rosa_dos_ventos.png,moldura_retabulo.png}` | logotipo em talha dourada, capas pintadas de dia e de noite, a rosa dos ventos e a moldura de talha (NinePatch do menu) da identidade "Crônica do Recôncavo", OpenAI `gpt-image-2` | `identidade/ORIGEM.md` |
| `assets/fonts/Cinzel-Variavel.ttf` | fonte Cinzel, © The Cinzel Project Authors | SIL OFL 1.1, `assets/fonts/OFL-Cinzel.txt` |
| `assets/fonts/CormorantGaramond-{Variavel,Italico-Variavel}.ttf` | fonte Cormorant Garamond, © the Cormorant Project Authors | SIL OFL 1.1, `assets/fonts/OFL-CormorantGaramond.txt` |

As fontes vêm do repositório do Google Fonts e permitem uso comercial (OFL). Os termos da
OpenAI concedem ao usuário os direitos sobre as imagens geradas; conferir as condições
vigentes antes de publicar.


## Fontes e interface

As fontes Cinzel e Cormorant Garamond acompanham os textos OFL em
`assets/fonts/`. Almendra é de Ana Sanfelippo, sob SIL OFL 1.1.
`assets/fonts/miva.ttf` é uma fonte original criada pela equipe; em
03/10/2026, o responsável confirmou que seus direitos pertencem ao projeto.
Ícones reutilizados da interface e catálogo foram produzidos no PixelLab.

### Tubarao e protagonista animado (04/10/2026)

| Arquivo | Fonte | Creditos Studio | Registro |
| --- | --- | ---: | --- |
| `assets/prototipo_3d/mar/tubarao_tripo.glb` | Tripo Studio, modelo original do tubarao-touro, malha Quad e rig de criatura | 105 | `assets/prototipo_3d/mar/ORIGEM.md` |
| `assets/prototipo_3d/personagens/viajante_tripo.glb` | Tripo Studio, modelo preexistente `modelo 3d de personagem` com rig Mixamo e 13 animacoes | 20 | `assets/prototipo_3d/personagens/ORIGEM.md` |

Total consumido: 125 creditos Studio, autorizado pelo responsavel.
