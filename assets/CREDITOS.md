# Créditos dos assets do jogo 3D

Os registros de origem acompanham os modelos e suas fontes de produção.

## Moldura da seleção de idioma e dos painéis internos

`ui/moldura_idioma.svg` adapta os filetes e a talha de acanto da home do
próprio Myths' Valley, definidos em `resources/views/components/moldura.blade.php`
e `resources/views/layouts/site.blade.php` do projeto do site. Os cantos são
preservados em nove fatias; a identidade compartilhada usa o mesmo desenho no
menu e nos painéis internos. Não há dependência de fontes ou de recursos remotos.

## Vídeo do lobby (gerado por IA)

| Arquivo (em `assets/prototipo_3d/identidade/video/`) | O que é |
|---|---|
| `carregamento_sobrevoo.ogv` | sobrevoo do vale em laço sem emenda, 21 s, 1280×720; fundo do lobby (menu) na build do Tripothon, no lugar do vale 3D |

Gerado com a API do LTX (Lightricks) a partir das pinturas do próprio projeto
(pinturas feitas com `gpt-image-2` para o jogo),
sem trilha de áudio, e convertido para Theora/Ogg para o Godot tocar. A
cinemática de abertura do mesmo lote ficou só no site. As versões em MP4 e os
originais em 1080p ficam fora do Git, em `.assets-raw/ltx/saida/`.

## Áudio (gerado por IA)

| Pasta | O que tem |
|-------|-----------|
| `audio/narracao/` | Narração de abertura, voz **BDM · Nelson Silvestre · Narrador** — a voz do narrador do próprio projeto |
| `audio/narracao/travessia/` | Narração da travessia (introdução), um trecho por legenda: ElevenLabs Text to Speech (Eleven v3), voz **BDM · Nelson Silvestre · Narrador**, cortada pelos tempos do Whisper da OpenAI (`tools/elevenlabs/gerar-travessia.ps1`, `alinhar_travessia.py`) |
| `audio/musica/tema_travessia.mp3` | Tema da travessia, 90 s instrumental, ElevenLabs Music (`tools/elevenlabs/gerar-travessia.ps1`) |
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
geradas por script do projeto; `grama_terra_mata_v1.png` e `estrada_terra_ocre_v1.png` não:
foram geradas pela ferramenta integrada de imagem (`materiais/ORIGEM.md`).

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

### Lote da casa e dos marcos (03/10/2026)

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/moveis/{cama,mesa,banco_tosco,bau,barril,cantareira,fogao_barro,jirau,oratorio,rede}_tripo.glb` | a mobília da casa herdada, Tripo Studio (texto → 3D + Malha Smart) | `moveis/ORIGEM.md` e `tools/tripo/lote_2026-10-03.json` |
| `assets/prototipo_3d/aderecos/{mastro_pano,fitas_gameleira}_tripo.glb` | os mastros com pano branco do terreiro e as fitas da gameleira, Tripo Studio | `aderecos/ORIGEM.md` e `tools/tripo/lote_2026-10-03.json` |

### Lote do saveiro, das casas e do cemitério (03/10/2026)

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/aderecos/tronco_caido_tripo.glb` | o tronco caído do cemitério, Tripo Studio (texto → 3D + Malha Smart) | `aderecos/ORIGEM.md` e `tools/tripo/lote_2026-10-03b.json` |
| `assets/prototipo_3d/construcoes/capelinha_tripo.glb` | a capelinha pobre do cemitério, Tripo Studio | `construcoes/ORIGEM.md` e `tools/tripo/lote_2026-10-03b.json` |
| `assets/prototipo_3d/moveis/{rede_de_pesca,remos,ervas_secando,pilao,gamela}_tripo.glb` | o que diz quem mora na casa do Pedro e na da Zefa, Tripo Studio | `moveis/ORIGEM.md` e `tools/tripo/lote_2026-10-03b.json` |
| `assets/prototipo_3d/personagens/quirino_tripo.glb` | o mestre Quirino, Tripo Studio (texto → 3D, Malha Smart, Auto Rig e animações prontas) | `personagens/ORIGEM.md` e `tools/tripo/lote_2026-10-03b.json` |

### As luvas de couro (04/10/2026)

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/itens/luvas_de_couro_tripo.glb` | a luva de couro do encaixe das Mãos, Tripo Studio (texto → 3D + Malha Smart) | `itens/ORIGEM.md` e `tools/tripo/lote_2026-10-04.json` |
| `assets/sprites/itens/luvas_de_couro.png` | o ícone de 32 px das luvas na mochila, PixelLab (Pixflux, no estilo dos itens do 2D) | `tools/pixellab/gerar-luvas.ps1` e `assets/sprites/cofre/REGISTRO.tsv` |

### Texturas do chão do vale (05/10/2026)

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/materiais/{grama_baixa,capim_seco,folhico_mata,terra_batida_varrida,barro_vermelho,pedrisco,areia_restinga,lama_mangue,terra_arada}_v1.png` e `terreiro_varrido_v1.png` | as nove camadas do chão em shader (grama, capim seco, folhiço, terra batida, barro, pedrisco, areia de restinga, lama de mangue, terra arada) e o decalque do terreiro derivado da terra batida, OpenAI `gpt-image-2`, pós-processadas (contínuas, com a altura no alfa) | `materiais/ORIGEM.md`, `tools/openai/texturas_chao.json` e `docs/mundo/SOLO_E_FRANJAS.md` |

### O saveiro da chegada (05/10/2026)

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/aderecos/saveiro_tripo.glb` | o saveiro do mestre Quirino, em que o jogador chega ao vale, Tripo Studio (texto → 3D + Malha Smart) | `aderecos/ORIGEM.md` e `tools/tripo/lote_2026-10-05.json` |

<!-- level-design-2026-10-05:inicio -->

### O level design do vale (05/10/2026)

Lotes gerados na noite de 05/10/2026 pela ponte do Playwright MCP com a extensão do Chrome
(`tools/tripo/lote_studio.js` e `tools/tripo/lote_producao.js`): 125 gerações (55 créditos),
158 retopologias Malha Smart (40) e 42 rigs (20) — 14.035 créditos, conferidos no extrato
da carteira do Studio; animações prontas e exportações não custaram crédito. Uso comercial:
plano pago no momento da geração.

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/personagens/{beata,carpinteiro,guarda,lavadeira,marisqueira,menina,menino,mercador,mestre_saveiro,padre,pescador,quituteira,rendeira,sacristao}_tripo.glb` | os moradores sem fala do arraial e quem faltava (vigário, vendeiro, guarda, sacristão, beata, pescador, marisqueira, lavadeira, rendeira, quituteira, carpinteiro, crianças, saveirista), Tripo Studio (texto → 3D em pose T, Malha Smart, rig Mixamo e animações prontas) | `personagens/ORIGEM.md` e `tools/tripo/lote_2026-10-05_level_design.json` |
| `assets/prototipo_3d/animais/{bode,boi,cabra,cachorro_caramelo,cachorro_deitado,cachorro_malhado,caititu,capivara,cavalo,filhote_caramelo,galinha,galinha_dangola,galo,garca,gato_amarelo,gato_malhado,gato_preto,jararaca,jumento,leitao,onca_pintada,onca_preta,pato,pavao,pavao_leque,pavoa,peru,pintinho,porco,tatu,urubu}_tripo.glb` | os bichos de quintal, da mata e do rio, Tripo Studio (texto → 3D, Malha Smart; quadrúpedes com o rig do Studio e o andar pronto, aves paradas animadas pelo jogo) | `animais/ORIGEM.md` e `tools/tripo/lote_2026-10-05_fauna_itens.json` e `tools/tripo/lote_2026-10-05_level_design.json` |
| `assets/prototipo_3d/peixes/{acara,baiacu,budiao,cavala,garoupa,moreia,piaba,raia,raia_pintada,robalo,sardinha,sargentinho,sororoca,tainha,traira,tubarao,xareu}_tripo.glb` | os peixes, as raias e o tubarão, Tripo Studio (texto → 3D, Malha Smart; nadam por shader) | `peixes/ORIGEM.md` e `tools/tripo/lote_2026-10-05_fauna_itens.json` e `tools/tripo/lote_2026-10-05_level_design.json` |
| `assets/prototipo_3d/arvores/{abobora_rasteira,algodoeiro_praia,angico,bromelia,canteiro_couve,cedro,gameleira,goiabeira,heliconia,jatoba,jequitiba,latada_maracuja,licurizeiro,mamoeiro,massaranduba,pe_de_fumo,pe_de_mandioca,pe_de_milho,pe_de_pimenta,quiabeiro,samambaia,sapucaia,taboa,touceira_bambu,touceira_cana}_tripo.glb` | a flora do paisagismo por zonas, as espécies da mata atlântica e a gameleira, Tripo Studio (texto → 3D, Malha Smart) | `arvores/ORIGEM.md` e `tools/tripo/lote_2026-10-05_level_design.json` e `tools/tripo/lote_2026-10-05_paisagismo.json` |
| `assets/prototipo_3d/arvores/{aroeira_leve,aroeira_longe,bananeira_leve,bananeira_longe,cajueiro_leve,cajueiro_longe,castanhola_leve,castanhola_longe,clusia_leve,coqueiro_leve,coqueiro_longe,dendezeiro_leve,dendezeiro_longe,embauba_longe,ingazeiro_leve,ingazeiro_longe,ipe_amarelo_leve,ipe_roxo_leve,jaqueira_leve,jaqueira_longe,jenipapeiro_leve,jenipapeiro_longe,mangue_leve,mangue_longe,mangueira_leve,mangueira_longe,mata_alta_longe,mata_larga_longe,pau_brasil_leve,piacava_leve,piacava_longe,pitangueira_leve}_tripo.glb` | as versões leves e de longe das árvores que já existiam, refeitas pela Retopologia do Tripo Studio sobre o projeto original de cada uma | `arvores/ORIGEM.md` e `tools/tripo/lote_2026-10-05_lod.json` |
| `assets/prototipo_3d/construcoes/{cadeia,casa_farinha,casa_meia_agua,casa_palha,casa_paroquial,casa_pescador,casa_taipa_azul,casa_taipa_ocre,casa_taipa_rosa,casa_taipa_verde,casa_varanda,sobrado}_tripo.glb` | as casas novas dos moradores e a casa de farinha, Tripo Studio (texto → 3D, Malha Smart, textura 2K) | `construcoes/ORIGEM.md` e `tools/tripo/lote_2026-10-05_level_design.json` e `tools/tripo/lote_2026-10-05_moradores.json` |
| `assets/prototipo_3d/aderecos/{barraca_feira,canoa_em_obra,carro_de_boi,cerca_varas,chiqueiro,cocho,estaleiro_fumo,forno_barro,galinheiro,lavadouro_pedra,monjolo,penedo_lapa,porteira,sacos_farinha,varal_bambu,varal_estacas}_tripo.glb` | varais, quintal, roça e trabalho (galinheiro, chiqueiro, cocho, pedra de lavar, canoa em obra, cerca de varas, porteira, carro de boi, monjolo, forno de barro, estaleiro de fumo, sacos de farinha, barraca de feira) e o penedo com lapa das onças, Tripo Studio | `aderecos/ORIGEM.md` e `tools/tripo/lote_2026-10-05_level_design.json` e `tools/tripo/lote_2026-10-05_moradores.json` e `tools/tripo/lote_2026-10-05_paisagismo.json` |
| `assets/prototipo_3d/itens/{balde,enxada,mandioca,picareta,rolo_fumo,tabuleiro,trouxa_roupa,vara_pescar,vassoura_piacava}_tripo.glb` | objetos de ofício e itens de mão (trouxa de roupa, tabuleiro, vassoura de piaçava, rolo de fumo, e a enxada, o balde, a vara, a picareta e a mandioca refeitos), Tripo Studio | `itens/ORIGEM.md` e `tools/tripo/lote_2026-10-05_fauna_itens.json` e `tools/tripo/lote_2026-10-05_moradores.json` e `tools/tripo/lote_2026-10-05_paisagismo.json` |

<!-- level-design-2026-10-05:fim -->

### A ponte do rio grande, caída e de pé (06/10/2026)

Gerados no Tripo Studio pela ponte do Playwright MCP (ver `docs/ferramentas/TRIPO_PLAYWRIGHT.md`): Modelo HD H3.1 (55 créditos cada) e Retopologia Malha Smart (40 cada), 190 créditos ao todo, autorizados pelo autor em 06/10. Uso comercial: plano pago no momento da geração.

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/construcoes/{ponte,ponte_caida}_tripo.glb` | a ponte de madeira do rio grande de pé (substitui a de 26/09) e a mesma ponte caída, que o vão mostra até a obra `ponte_levantar`, Tripo Studio (texto → 3D, Malha Smart, textura 2K) | `construcoes/ORIGEM.md` e `tools/tripo/lote_2026-10-06_ponte.json` |

### Capas dos cordéis (03/10/2026)

| Arquivos | O que são | Registro |
| --- | --- | --- |
| `assets/prototipo_3d/cordeis/*.jpg` | as dez capas em xilogravura dos cordéis, OpenAI `gpt-image-2` | `cordeis/ORIGEM.md` e `tools/openai/capas_cordeis.json` |

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
