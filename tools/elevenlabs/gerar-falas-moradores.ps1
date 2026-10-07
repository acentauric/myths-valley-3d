# Gera as vozes pt-BR dos moradores do 3D (ElevenLabs, modelo eleven_v3).
#
# Lê data/npcs_3d.json: o guia (Pedro) e cada morador com "voz" ({id, nome, modelo}) têm
# listas de falas, e cada fala ({texto, tts?, audio}) com "audio" preenchido vira
# assets/audio/vozes/<audio>.mp3. "audio" vazio = a fala não tem voz (só o balão): o nome
# do arquivo é decisão do arquivo de dados, e este script nunca gasta crédito com fala sem
# nome. A convenção dos nomes é <id>_<tipo>_<n> (n a partir de 1), com o tipo da lista:
#
#   falas            fala            a conversa do E (no Pedro, o primeiro encontro: pedro_saudacao_<n>)
#   saudacoes        saudacao        o cumprimento de quem passa
#   saudacoes_noite  saudacao_noite  o cumprimento de quem passa, de noite
#   falas_noite      fala_noite      a conversa do E, de noite
#   falas_depois     depois          só o guia: o que o Pedro diz depois do tutorial (pedro_depois_<n>)
#   anoitecer        (um só)         só o guia: o aviso do entardecer
#
# "tts" é o que a voz lê, com marcações de interpretação do v3 entre colchetes ([whispers],
# [laughs]...); sem ele, lê o "texto" do balão. Só o português tem voz: texto_en, texto_es e
# texto_zh aparecem no balão e a voz segue em português. Normaliza cada arquivo em -18 LUFS,
# como as outras vozes.
#
# Uso:  .\tools\elevenlabs\gerar-falas-moradores.ps1 [-Morador padre] [-Forcar] [-SoContar] [-Limite 1]
#   -SoContar  lista o que geraria e quantas letras (crédito) custa, sem chamar a API.
#   -Forcar    gera de novo também o que já existe (trocou a voz de alguém no arquivo).
#   -Limite N  para depois de N falas geradas (uma primeira, para ouvir a voz antes do lote).
# Precisa do ffmpeg e do ffprobe no PATH. A chave só vem de tools/comum/chaves.ps1 e nunca é impressa.

param(
    [string] $Morador = "",
    [switch] $Forcar,
    [switch] $SoContar,
    [int] $Limite = 0
)

. "$PSScriptRoot\elevenlabs.ps1"

$raiz = (Resolve-Path "$PSScriptRoot\..\..").Path
$dados = Get-Content "$raiz\data\npcs_3d.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$pasta = "$raiz\assets\audio\vozes"
$bruto = Join-Path $env:TEMP "mv_falas_brutas"
if (-not $SoContar) { New-Item -ItemType Directory -Force $bruto | Out-Null }

# As listas do arquivo que têm voz (o "anoitecer" do guia é um objeto só, tratado à parte).
$listas = @("falas", "saudacoes", "saudacoes_noite", "falas_noite", "falas_depois")
# Falhas seguidas que param a rodada: voz que não existe, crédito acabado e chave errada se repetem.
$maximo_de_falhas_seguidas = 3

$pessoas = @($dados.guia) + @($dados.moradores)
$feitas = 0
$letras = 0
$falhas = 0
$seguidas = 0

foreach ($m in $pessoas) {
    if ($Morador -and $m.id -ne $Morador) { continue }
    if (-not $m.voz) { continue }

    $entradas = @()
    foreach ($lista in $listas) {
        $itens = $m.$lista
        if (-not $itens) { continue }
        foreach ($item in @($itens)) { $entradas += $item }
    }
    if ($m.anoitecer) { $entradas += $m.anoitecer }

    foreach ($f in $entradas) {
        $nome = [string]$f.audio
        if ($nome -eq "") { continue }
        if ($Limite -gt 0 -and $feitas -ge $Limite) { break }
        $destino = "$pasta\$nome.mp3"
        if ((Test-Path $destino) -and -not $Forcar) { "ja existe: $nome"; continue }
        $texto = if ($f.tts) { [string]$f.tts } else { [string]$f.texto }

        if ($SoContar) {
            "{0}: {1} letras ({2})" -f $nome, $texto.Length, $m.voz.nome
            $letras += $texto.Length
            $feitas++
            continue
        }

        $arquivo = "$bruto\$nome.mp3"
        $gerou = $false
        for ($tentativa = 1; $tentativa -le 3 -and -not $gerou; $tentativa++) {
            try {
                New-ElevenNarracao -Texto $texto -VozId $m.voz.id -Destino $arquivo -Modelo $m.voz.modelo -Estabilidade 0.5 | Out-Null
                $gerou = $true
            } catch {
                $estado = 0
                if ($_.Exception.Response) { $estado = [int]$_.Exception.Response.StatusCode }
                # O corpo do erro diz a causa (a chave nunca vai nele). O 401 `quota_exceeded` é o crédito, ou o
                # TETO DA CHAVE de API (definido no painel do ElevenLabs), que acabou: repetir não adianta.
                $detalhe = ""
                if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $detalhe = [string]$_.ErrorDetails.Message; if ($detalhe.Length -gt 300) { $detalhe = $detalhe.Substring(0, 300) } }
                Write-Warning ("{0}: tentativa {1} falhou ({2} {3}) {4}" -f $nome, $tentativa, $estado, $_.Exception.Message, $detalhe)
                if ($detalhe -match "quota_exceeded") { throw "Parei: acabou o credito (ou o teto da chave de API): amplie no painel do ElevenLabs e rode de novo; so gera o que falta." }
                # 4xx (menos o 429 de excesso de pedidos) não se resolve repetindo.
                if ($estado -ge 400 -and $estado -lt 500 -and $estado -ne 429) { break }
                Start-Sleep -Seconds (5 * $tentativa * $tentativa)
            }
        }
        if ($gerou) {
            & ffmpeg -y -loglevel error -i $arquivo -af loudnorm=I=-18:TP=-1.5:LRA=11 -ar 44100 -b:a 128k $destino
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path $destino)) { $gerou = $false; Write-Warning "$nome`: o ffmpeg nao normalizou o arquivo" }
        }
        if (-not $gerou) {
            $falhas++
            $seguidas++
            if ($seguidas -ge $maximo_de_falhas_seguidas) { throw "Parei: $seguidas falhas seguidas (ultima: $nome). Veja os avisos acima." }
            continue
        }
        $seguidas = 0
        $segundos = & ffprobe -v error -show_entries format=duration -of csv=p=0 $destino
        "{0}: {1:N1} s ({2}, {3} letras)" -f $nome, [double]$segundos, $m.voz.nome, $texto.Length
        $feitas++
        $letras += $texto.Length
        Start-Sleep -Milliseconds 300
    }
}

if ($SoContar) {
    "a gerar: {0} fala(s), {1} letras" -f $feitas, $letras
} else {
    "geradas: {0} fala(s), {1} letras, {2} falha(s)" -f $feitas, $letras, $falhas
    # Quem declarou `voz_pendente` e agora tem todos os áudios: a marca sai do arquivo (o portão
    # tests/vozes_dos_moradores.gd reprova a que sobrar). Os mp3 novos ainda precisam do import.
    foreach ($m in $pessoas) {
        if (-not $m.voz_pendente) { continue }
        $falta = 0
        foreach ($lista in $listas) {
            foreach ($item in @($m.$lista)) {
                if ($item -and $item.audio -and -not (Test-Path "$pasta\$($item.audio).mp3")) { $falta++ }
            }
        }
        if ($falta -eq 0) { "{0}: todos os audios existem; tire o voz_pendente de data/npcs_3d.json" -f $m.id }
        else { "{0}: ainda faltam {1} audio(s)" -f $m.id, $falta }
    }
    "depois: Godot --headless --editor --import --path . (cria o .import dos mp3 novos)"
}
