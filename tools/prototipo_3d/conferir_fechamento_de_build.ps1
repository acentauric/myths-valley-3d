# CONFERIR O FECHAMENTO DE UMA BUILD CONTRA OS LIMITES DO ATUALIZADOR (#231)
#
#   .\tools\prototipo_3d\conferir_fechamento_de_build.ps1 -Zip D:\myths-valley-builds\MythsValley3D-...-windows.zip
#   .\tools\prototipo_3d\conferir_fechamento_de_build.ps1 -Zip <zip> -Registrar   # grava a build em data/atualizador_builds.json
#
# O atualizador (scripts/autoload/atualizacao.gd) recusa o zip acima de MAX_ZIP e o jogo extraido acima de
# MAX_EXTRAIDO. Em outubro de 2026 esses limites eram de uma build de 360 MB, o jogo passou de 1 GB, e a Build 9
# nao ofereceu a 10 sem dizer nada. Esta conferencia roda ao fechar a build e diz, antes de publicar:
#
#   1. ERRO (saida 1): o zip ou o executavel desta build passa dos limites do codigo atual. Quem a instalar nao
#      se atualiza para a seguinte, e a propria build seria recusada por um atualizador igual a ela.
#   2. AVISO: o dobro do tamanho ja passaria dos limites; hora de subi-los antes da proxima.
#   3. AVISO: a build ANTERIOR (data/atualizador_builds.json) tem limites menores que esta build. Quem a tem NAO
#      vai ver esta atualizacao; o site precisa dizer "baixe esta build pelo site uma vez".
#
# O MythsValley3D.exe e lido pelo indice do zip: nada e extraido.

param(
    [Parameter(Mandatory = $true)][string]$Zip,
    [switch]$Registrar
)

$ErrorActionPreference = 'Stop'
$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Ler-Limite([string]$texto, [string]$nome) {
    # "const MAX_ZIP := 4 * 1024 * 1024 * 1024" -> produto dos fatores
    $m = [regex]::Match($texto, "const $nome := ([0-9 *]+)")
    if (-not $m.Success) { throw "nao achei $nome em scripts/autoload/atualizacao.gd" }
    $produto = [long]1
    foreach ($fator in $m.Groups[1].Value.Split('*')) { $produto *= [long]($fator.Trim()) }
    return $produto
}

function Em-GB([long]$bytes) { return ('{0:N2} GB' -f ($bytes / 1GB)) }

if (-not (Test-Path -LiteralPath $Zip)) { throw "zip inexistente: $Zip" }
$zipBytes = (Get-Item -LiteralPath $Zip).Length

Add-Type -AssemblyName System.IO.Compression.FileSystem
$arquivo = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Zip).Path)
try {
    $exe = $arquivo.Entries | Where-Object { $_.Name -eq 'MythsValley3D.exe' } | Select-Object -First 1
    if ($null -eq $exe) { throw 'o zip nao traz MythsValley3D.exe' }
    $exeBytes = [long]$exe.Length
} finally { $arquivo.Dispose() }

$codigo = Get-Content -Raw -Encoding UTF8 (Join-Path $raiz 'scripts\autoload\atualizacao.gd')
$maxZip = Ler-Limite $codigo 'MAX_ZIP'
$maxExtraido = Ler-Limite $codigo 'MAX_EXTRAIDO'
$historico = Get-Content -Raw -Encoding UTF8 (Join-Path $raiz 'data\historico_3d.json') | ConvertFrom-Json
$build = [int]$historico.build_numero

Write-Host ("Build {0}: zip {1}, executavel {2}. Limites do atualizador deste codigo: zip {3}, jogo extraido {4}." -f `
    $build, (Em-GB $zipBytes), (Em-GB $exeBytes), (Em-GB $maxZip), (Em-GB $maxExtraido))

$erros = 0
if ($zipBytes -gt $maxZip) {
    Write-Host ("ERRO: o zip ({0}) passa do MAX_ZIP ({1}): o atualizador desta propria build o recusaria." -f (Em-GB $zipBytes), (Em-GB $maxZip)) -ForegroundColor Red
    $erros++
}
if ($exeBytes -gt $maxExtraido) {
    Write-Host ("ERRO: o executavel ({0}) passa do MAX_EXTRAIDO ({1}): o atualizador desta propria build o recusaria." -f (Em-GB $exeBytes), (Em-GB $maxExtraido)) -ForegroundColor Red
    $erros++
}
if ($erros -eq 0 -and ($zipBytes * 2 -gt $maxZip -or $exeBytes * 2 -gt $maxExtraido)) {
    Write-Host 'AVISO: o dobro desta build ja passaria dos limites; suba MAX_ZIP e MAX_EXTRAIDO antes da proxima.' -ForegroundColor Yellow
}

# A build anterior: os limites que ELA embutiu decidem se ela enxerga esta.
$caminho = Join-Path $raiz 'data\atualizador_builds.json'
$registro = Get-Content -Raw -Encoding UTF8 $caminho | ConvertFrom-Json
$anteriores = @($registro.builds.PSObject.Properties | Where-Object { [int]$_.Name -lt $build } | Sort-Object { [int]$_.Name })
if ($anteriores.Count -gt 0) {
    $anterior = $anteriores[-1]
    $limites = $anterior.Value
    if ($zipBytes -gt [long]$limites.max_zip -or $exeBytes -gt [long]$limites.max_extraido) {
        Write-Host ("AVISO: a Build {0} (zip ate {1}, jogo ate {2}) nao consegue se atualizar para esta: quem a tem precisa baixar a Build {3} pelo site uma vez. Confira o aviso na pagina Jogar." -f `
            $anterior.Name, (Em-GB ([long]$limites.max_zip)), (Em-GB ([long]$limites.max_extraido)), $build) -ForegroundColor Yellow
    } else {
        Write-Host ("A Build {0} enxerga esta (limites {1} / {2})." -f $anterior.Name, (Em-GB ([long]$limites.max_zip)), (Em-GB ([long]$limites.max_extraido)))
    }
} else {
    Write-Host 'Sem build anterior no registro: nada a avisar.'
}

if ($Registrar -and $erros -eq 0) {
    $entrada = [ordered]@{
        zip_bytes = $zipBytes; exe_bytes = $exeBytes; max_zip = $maxZip; max_extraido = $maxExtraido
        nota = ''
    }
    $registro.builds | Add-Member -NotePropertyName ([string]$build) -NotePropertyValue ([pscustomobject]$entrada) -Force
    $json = $registro | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($caminho, $json + "`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Build $build registrada em data/atualizador_builds.json."
}

exit $(if ($erros -gt 0) { 1 } else { 0 })
