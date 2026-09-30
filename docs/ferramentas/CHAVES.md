# Chaves de API

Todas as chaves ficam em **um único arquivo `.env` na raiz do projeto**, que
está no `.gitignore` e nunca é versionado.

```
# .env
PIXELLAB_API_KEY=...
ELEVENLABS_API_KEY=...
OPENAI_API_KEY=...
LTX_API_KEY=...
```

| Chave | Quem usa |
|---|---|
| `PIXELLAB_API_KEY` | `tools/pixellab/` — sprites, tiles e cenas |
| `ELEVENLABS_API_KEY` | `tools/elevenlabs/` — fala, efeitos e música |
| `OPENAI_API_KEY` | Reservada; nenhum script a lê ainda. Quem for usá-la passa por `Get-Chave` como as outras |
| `LTX_API_KEY` | `tools/ltx/gerar_video_menu.py` — o vídeo do menu. Esse script lê o `.env` por conta própria (é Python), mas o formato é o mesmo |

Formato: `NOME=valor`, uma por linha, sem aspas. Linhas começando com `#` são
comentário.

## Como os scripts leem

`tools/comum/chaves.ps1` expõe `Get-Chave`, que procura **primeiro a variável de
ambiente** de mesmo nome e depois o `.env`. Assim dá para usar variável de
ambiente em CI sem mexer em código.

A chave nunca é passada por argumento de linha de comando (ficaria no histórico
do shell), nunca é impressa e nunca entra em log.

## Conferir que não vazou

```powershell
git check-ignore -v .env    # deve responder que está ignorado
git status --short          # o .env NÃO pode aparecer
```

Se desconfiar que vazou, revogue no painel do serviço e gere outra.

## Nota sobre escopo

A chave do ElevenLabs deste projeto é restrita: `/v1/voices`, a síntese de fala,
os efeitos sonoros e a música funcionam, mas `/v1/user` e `/v1/models` devolvem
401. Por isso não dá para consultar a cota pela API — acompanhe pelo painel.

## Nota sobre os scripts PowerShell

Os `.ps1` deste projeto são gravados em **UTF-8 com BOM**. O PowerShell 5.1 do
Windows lê arquivo sem BOM como ANSI, e aí qualquer acento nos comentários
quebra o parser com erro de string não terminada.
