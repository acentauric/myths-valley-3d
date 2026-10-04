# O icone das LUVAS DE COURO, a primeira peca do encaixe das Maos.
#
#     .\tools\pixellab\gerar-luvas.ps1 [-Forcar]
#
# "No campo maos do inventario, nao e para armas, mas sim para luvas." E,
# perguntado se gerava: "sobre a luva, pode gerar". Icone de item de 32x32,
# transparente, pelo Pixflux (o endpoint mais barato), no MESMO estilo dos
# itens do 2D (`gerar-itens-da-mata.ps1` de la: o gibao e o patua). Vai para
# assets/sprites/itens/, de onde o Catalogo le todo icone. O cofre guarda a
# geracao com o texto que a pediu (assets/sprites/cofre/, ver cofre.ps1).
#
# O cliente (pixellab.ps1, cofre.ps1, arquivo.ps1) e o do 2D, copiado: este
# repositorio nao depende do checkout de la. A chave vem do .env pela
# Get-Chave e nunca e impressa.

param([switch] $Forcar)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/pixellab.ps1"

$raiz = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $raiz
# CAMINHO ABSOLUTO, e a pasta do PROCESSO na raiz: o cliente grava com
# [IO.File]::WriteAllBytes, que resolve caminho relativo contra a pasta do
# processo, e nao contra a do Set-Location. Na primeira rodada a imagem foi
# paga e se perdeu assim (o processo estava na pasta de cima).
[System.IO.Directory]::SetCurrentDirectory($raiz)
$destino = Join-Path $raiz 'assets/sprites/itens/luvas_de_couro.png'

$estilo = 'native 32 by 32 pixel art item icon for a rural Bahia Brazil 1887 farming game, centered, transparent background, single color black outline, basic shading, low detail, muted ochre and earth palette, no text'
$descricao = 'a pair of worn brown tanned leather work gloves with stitched seams and short cuffs, one lying slightly over the other'

if ((Test-Path -LiteralPath $destino) -and -not $Forcar) {
    Write-Host "  ja existe: luvas_de_couro"
    exit 0
}
$antes = (Get-PixelLabSaldo).subscription.generations
$uso = New-PixelLabImagem -Descricao ($descricao + ', ' + $estilo) -Destino $destino `
    -Largura 32 -Altura 32 -Visao 'side' -Contorno 'single color black outline' `
    -Sombreado 'basic shading' -Detalhe 'low detail' -Semente 241001 -SemFundo
$depois = (Get-PixelLabSaldo).subscription.generations
Write-Host ("  ok: luvas_de_couro (saldo {0} -> {1})" -f $antes, $depois)
