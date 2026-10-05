# As texturas de chao do vale: uma imagem por camada do shader do terreno, gerada no OpenAI.
#
#     .\tools\openai\gerar-texturas-chao.ps1 -Estimar                       # so o plano e o custo, sem gastar
#     .\tools\openai\gerar-texturas-chao.ps1 [-Somente grama_baixa,lama_mangue] [-SemiRealista] [-Qualidade medium] [-Forcar]
#     .\tools\openai\gerar-texturas-chao.ps1 -Cliente <outro checkout>\tools\openai\openai.ps1
#
# GERACAO PAGA: so com pedido explicito, depois de o custo estimado (-Estimar)
# ter sido mostrado e aceito. Os prompts moram em texturas_chao.json, ao lado
# deste arquivo: todos comecam pelo mesmo preambulo (vista de cima, ladrilho,
# luz difusa, ~3 x 3 m de chao), pintado a mao como os modelos do Tripo.
# -SemiRealista troca pelo preambulo semi-realista e grava <id>_semi_realista.png:
# foi o lado B do A/B da grama baixa, que o pintado venceu (05/10/2026).
# A chave vem do .env pela Get-Chave; nunca e passada por argumento nem impressa.
# Num worktree sem .env, -Cliente aponta o openai.ps1 do checkout que tem o .env.
#
# As imagens caem em .assets-raw/openai/texturas_chao/<id>.png (fora do Git).
# Depois de conferidas, o tools/materiais/preparar_textura_chao.py as leva para
# assets/prototipo_3d/materiais/<id>_v1.png (1024 px, continua, altura no alfa).

param(
    [switch] $Estimar,
    [string[]] $Somente,
    [switch] $SemiRealista,
    [ValidateSet("low", "medium", "high")][string] $Qualidade = "",
    [switch] $Forcar,
    [string] $Cliente = ""
)

$ErrorActionPreference = "Stop"
$raiz = Resolve-Path "$PSScriptRoot\..\.."
$plano = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot "texturas_chao.json") | ConvertFrom-Json
if (-not $Qualidade) { $Qualidade = $plano.qualidade }
if (-not $Cliente) { $Cliente = Join-Path $PSScriptRoot "openai.ps1" }
$saida = Join-Path $raiz ".assets-raw\openai\texturas_chao"
$sufixo = if ($SemiRealista) { "_semi_realista" } else { "" }
$preambulo = if ($SemiRealista) { $plano.preambulo_semi_realista } else { $plano.preambulo }

$ids = @($plano.texturas.PSObject.Properties.Name)
if ($Somente) { $ids = @($ids | Where-Object { $Somente -contains $_ }) }
$faltam = @($ids | Where-Object { $Forcar -or -not (Test-Path (Join-Path $saida "$_$sufixo.png")) })
$preco = [double]($plano.preco_estimado_usd.$Qualidade)
$total = $preco * $faltam.Count

Write-Output ("Modelo {0}, {1}, qualidade {2}: {3} textura(s) a gerar, de {4} pedida(s)." -f $plano.modelo, $plano.tamanho, $Qualidade, $faltam.Count, $ids.Count)
Write-Output ("Custo estimado: US$ {0:N3} por textura, US$ {1:N2} no total." -f $preco, $total)
foreach ($id in $faltam) { Write-Output ("  - {0}{1}" -f $id, $sufixo) }
if ($Estimar -or $faltam.Count -eq 0) { return }

. $Cliente
foreach ($id in $faltam) {
    $descricao = "{0} {1}" -f $preambulo, $plano.texturas.$id
    $destino = Join-Path $saida "$id$sufixo.png"
    Write-Output ("Gerando {0}{1}..." -f $id, $sufixo)
    $uso = New-OpenAIImagem -Descricao $descricao -Destino $destino -Modelo $plano.modelo -Tamanho $plano.tamanho -Qualidade $Qualidade
    if ($uso) { Write-Output ("  ok: {0} ({1} tokens de saida)" -f $destino, $uso.output_tokens) } else { Write-Output ("  ok: {0}" -f $destino) }
}
