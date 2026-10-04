# As capas dos cordeis: uma xilogravura por folheto, gerada no OpenAI.
#
#     .\tools\openai\gerar-capas-cordeis.ps1 -Estimar              # so o plano e o custo, sem gastar
#     .\tools\openai\gerar-capas-cordeis.ps1 [-Somente peso_falso,moleque_do_pier] [-Qualidade medium] [-Forcar]
#
# GERACAO PAGA: so com pedido explicito, depois de o custo estimado (-Estimar)
# ter sido mostrado e aceito. As cenas e o estilo moram em capas_cordeis.json,
# ao lado deste arquivo. A chave vem do .env pela Get-Chave; nunca e passada
# por argumento nem impressa.
#
# As imagens caem em .assets-raw/cordeis/<id>.png (fora do Git). Depois de
# conferidas, o tools/openai/promover_capas.gd as leva para
# assets/prototipo_3d/cordeis/<id>.jpg (768x1152): o folheto e o barbante do
# vale passam a usa-las sozinhos.

param(
    [switch] $Estimar,
    [string[]] $Somente,
    [ValidateSet("low", "medium", "high")][string] $Qualidade = "",
    [switch] $Forcar
)

$ErrorActionPreference = "Stop"
$raiz = Resolve-Path "$PSScriptRoot\..\.."
$plano = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot "capas_cordeis.json") | ConvertFrom-Json
if (-not $Qualidade) { $Qualidade = $plano.qualidade }
$saida = Join-Path $raiz ".assets-raw\cordeis"

$ids = @($plano.capas.PSObject.Properties.Name)
if ($Somente) { $ids = @($ids | Where-Object { $Somente -contains $_ }) }
$faltam = @($ids | Where-Object { $Forcar -or -not (Test-Path (Join-Path $saida "$_.png")) })
$preco = [double]($plano.preco_estimado_usd.$Qualidade)
$total = $preco * $faltam.Count

Write-Output ("Modelo {0}, {1}, qualidade {2}: {3} capa(s) a gerar, de {4} pedida(s)." -f $plano.modelo, $plano.tamanho, $Qualidade, $faltam.Count, $ids.Count)
Write-Output ("Custo estimado: US$ {0:N3} por capa, US$ {1:N2} no total." -f $preco, $total)
foreach ($id in $faltam) { Write-Output ("  - {0}" -f $id) }
if ($Estimar -or $faltam.Count -eq 0) { return }

. "$PSScriptRoot\openai.ps1"
foreach ($id in $faltam) {
    $descricao = "{0} Scene: {1}" -f $plano.estilo, $plano.capas.$id
    $destino = Join-Path $saida "$id.png"
    Write-Output ("Gerando {0}..." -f $id)
    $uso = New-OpenAIImagem -Descricao $descricao -Destino $destino -Modelo $plano.modelo -Tamanho $plano.tamanho -Qualidade $Qualidade
    if ($uso) { Write-Output ("  ok: {0} ({1} tokens de saida)" -f $destino, $uso.output_tokens) } else { Write-Output ("  ok: {0}" -f $destino) }
}
