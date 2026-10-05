# Guarda o desenho anterior antes de a geração passar por cima dele.
#
#     . "$PSScriptRoot\arquivo.ps1"
#     Arquivar "assets\sprites\gerados\construcoes\venda.png" "venda"
#
# NADA É APAGADO, NUNCA. Arte gerada custa geração e custa sorte: a mesma
# semente com o mesmo texto não devolve o mesmo desenho, então uma peça que
# saiu boa e foi sobrescrita não volta mais. Guardar é mais barato que gerar de
# novo e torcer.
#
# Por isso a versão nunca é pulada: se `venda.png` já está guardado, o desenho
# atual vai para `venda_2.png`, depois `venda_3.png`. A primeira tentativa de
# escrever isto pulava quando o nome já existia — e teria jogado fora
# justamente a segunda versão de uma peça, que é a que costuma ser a boa.
#
# Os lotes anteriores ficam cada um no seu canto, nomeados pelo que são:
#   gerados/isometrico/      o primeiro lote, com três planos
#   gerados/antes_da_vista/  o que havia antes desta passada de perspectiva

$ARQUIVO_PADRAO = "assets\sprites\gerados\antes_da_vista"


function Arquivar([string] $Destino, [string] $Nome, [string] $Pasta = "") {
    if (-not (Test-Path $Destino)) { return }
    if ($Pasta -eq "") { $Pasta = $ARQUIVO_PADRAO }
    New-Item -ItemType Directory -Force $Pasta | Out-Null

    $guardado = Join-Path $Pasta "$Nome.png"
    $n = 1
    while (Test-Path $guardado) {
        $n++
        $guardado = Join-Path $Pasta "${Nome}_$n.png"
    }
    Copy-Item $Destino $guardado
    Write-Host "  guardado: $guardado"
}
