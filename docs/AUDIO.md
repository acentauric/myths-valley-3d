# Áudio

O autoload [audio.gd](../scripts/autoload/audio.gd) reúne música, narração, efeitos e ambiente. A direção narrativa, o catálogo novo e a proveniência estão em [ESTRATEGIA_SONORA.md](ESTRATEGIA_SONORA.md). A chave ElevenLabs permanece no ambiente ou `.env`, nunca no jogo exportado; ver [CHAVES.md](CHAVES.md).

## Catálogo

| Grupo | Ativos |
|---|---|
| Entrada atual | `musica/tema_reconcavo.ogg` — Maré de chegada, 177 s em loop |
| Entradas preservadas | `tema_introducao.wav` (também existe fonte MP3), `tema_menu.mp3`, `tema_menu_2.mp3` |
| Roçado | `musica/tema_rocado.mp3` — trilha original de 45 s |
| Natureza da entrada | `ambiente/mare_mansa.ogg`, `ambiente/aves_reconcavo.ogg` |
| Interface nova | `menu_mover_madeira`, `menu_confirma_madeira`, `menu_voltar_madeira` |
| Interface original | `menu_mover`, `menu_confirma` |
| Passos | `passo_grama`, `passo_terra`, `passo_areia`, `passo_madeira`, `passo_agua`, `corrida` |
| Portas e trabalho | `porta_abrir`, `porta_fechar`, `machado`, `arvore_cai`, `picareta`, `arar`, `plantar`, `regar`, `colher`, `pegar`, `dormir` |
| Narração | `narracao/boas_vindas.mp3` — voz BDM · Nelson Silvestre · Narrador (`hOLl3246BMBsdy0qtYLb`), `eleven_multilingual_v2` |

Todos os caminhos partem de `assets/audio/`; efeitos individuais são MP3 em `efeitos/`. As vozes de Pedro e dos demais personagens continuam em texto. Novas falas devem esperar o fechamento do roteiro.

## Preferências e uso

`user://audio.cfg` persiste independentemente dos slots. O menu usa as APIs abaixo; nunca atribui preferências de som a partir de um save.

| API de `Audio` | Comportamento |
|---|---|
| `definir_som_ativo(bool)`, `alternar_som()` | Mute global persistente |
| `definir_musica_menu(1..4)` | Escolhe e toca a faixa; 1..3 originais, 4 nova |
| `obter_caminho_musica_menu()` | Resolve a seleção com fallback para a introdução original |
| `definir_efeitos_menu(1..2)` | Original ou Madeira & papel |
| `definir_ambiente_menu(0..3)` | Desligado, mar, aves ou ambos |
| `definir_volume_musica/efeitos/ambiente(float)` | Volume normalizado de 0 a 1; limites aplicados na API |
| `iniciar_ambiente_menu()`, `parar_ambiente_menu()` | Controla as duas camadas sem duplicar players |
| `testar_efeito_menu(nome = "menu_confirma")` | Prévia do pacote escolhido |
| `testar_ambiente_menu(opcao = -1)` | Prévia de 6 s; restaura ambiente anterior e preserva preferências |
| `tocar_musica(caminho = MUSICA_ROCADO)` | Toca em loop com transição suave; roçado encerra o ambiente do menu |
| `parar_musica()` | Cancela transição e interrompe a faixa |
| `narrar_abertura()`, `parar_narracao()` | Narração não bloqueante; não espera o áudio terminar |
| `efeito("arar")` | Efeito pelo nome; `menu_mover/confirma/voltar` respeitam o pacote |
| `passo(terreno, correndo)` | Canal independente, pequena variação de tom |

Volumes públicos: `volume_musica`, `volume_efeitos`, `volume_ambiente`, `volume_vozes` (falas dos NPCs; `volume_vozes_db()` para tocadores 3D), `volume_narracao` (narração da travessia). As vozes e a narração foram normalizadas em -18 LUFS (pico -1,5 dB) com `ffmpeg loudnorm`; novos áudios de fala devem seguir o mesmo nível. Camadas do ambiente com volume próprio sobre o geral (`volume_camadas`, chaves em `CAMADAS_AMBIENTE`: `aves`, `mar`, `riacho`, `fogueira`, `mata`); ajuste com `definir_volume_camada()` e leia com `volume_camada_db()`. Ficam em AJUSTAR, aba Sons do vale. Seleções públicas: `musica_menu_opcao`, `efeitos_menu_opcao`, `ambiente_menu_opcao`. Use os setters para aplicar e salvar alterações.

O passo é acionado por distância andada; `scripts/mundo/terreno.gd` identifica o chão. UI, passos e efeitos do mundo têm canais distintos. Assets ausentes geram aviso e não interrompem o jogo.

## Geração e preparação

`tools/elevenlabs/elevenlabs.ps1` usa o leitor seguro compartilhado. Música tem modelo explícito `music_v2` e opção `-Instrumental`; efeitos têm modelo `eleven_text_to_sound_v2` e opção `-Loop`.

```powershell
# Pacote de introdução; arquivos existentes são preservados.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/elevenlabs/gerar-introducao.ps1

# Reprocessar masters locais a partir das fontes já geradas.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/elevenlabs/gerar-introducao.ps1 -PrepararNovamente

# Importar no motor após produzir os arquivos.
C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
```

O gerador original de efeitos continua em `tools/elevenlabs/gerar-efeitos.ps1`. Fontes novas, prompts e manifesto ficam em `assets/audio/fontes/introducao_2026/`, excluídos da importação por `.gdignore`.

## Teste isolado

```powershell
$env:APPDATA = Join-Path $PWD 'scratch/audio-validation/appdata'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/elevenlabs/testar-audio.gd
```

Execute em uma sessão de terminal dedicada: a variável muda só essa sessão e mantém as preferências pessoais intactas. O teste verifica o diretório antes de qualquer gravação.

## Evolução

Ambiente dinâmico por região e horário, motivos dos capítulos 6 e 7 e narração dos momentos-chave ainda são etapas futuras. O ambiente novo desta revisão pertence às telas de entrada.
