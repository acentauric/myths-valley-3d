# CONFERIR O ICONE DO EXECUTAVEL EXPORTADO (#230)
#
#   .\tools\prototipo_3d\conferir_icone_do_exe.ps1 -Exe build\windows\MythsValley3D.exe
#
# A exportacao sem o rcedit configurado termina sem erro e deixa o ".exe" com o icone generico do Godot
# (docs/ferramentas/EXPORTAR_WINDOWS.md). Aqui o icone embutido no executavel e comparado, pixel a pixel
# em 32x32, com o icone do jogo (assets/prototipo_3d/identidade/icone/icone.ico). Saida 0 se parecem, 1 se
# nao. Nao abre o jogo: so le o recurso de icone do arquivo.

param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Referencia = '',
    [double]$Limite = 18.0
)

$ErrorActionPreference = 'Stop'
$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if ($Referencia -eq '') { $Referencia = Join-Path $raiz 'assets\prototipo_3d\identidade\icone\icone.ico' }
if (-not (Test-Path -LiteralPath $Exe)) { throw "executavel inexistente: $Exe" }
Add-Type -AssemblyName System.Drawing

function Bitmap-Do-Icone([System.Drawing.Icon]$icone, [int]$lado) {
    $quadro = New-Object System.Drawing.Icon($icone, $lado, $lado)
    $fundo = New-Object System.Drawing.Bitmap($lado, $lado, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($fundo)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 40, 40, 40))   # transparente vira cinza: a comparacao e do que se ve
    $g.DrawIcon($quadro, (New-Object System.Drawing.Rectangle(0, 0, $lado, $lado)))
    $g.Dispose()
    return $fundo
}

$lado = 32
$doExe = [System.Drawing.Icon]::ExtractAssociatedIcon((Resolve-Path -LiteralPath $Exe).Path)
if ($null -eq $doExe) { throw 'o executavel nao tem icone' }
$doJogo = New-Object System.Drawing.Icon((Resolve-Path -LiteralPath $Referencia).Path)
$a = Bitmap-Do-Icone $doExe $lado
$b = Bitmap-Do-Icone $doJogo $lado
$soma = 0.0
for ($x = 0; $x -lt $lado; $x++) {
    for ($y = 0; $y -lt $lado; $y++) {
        $p = $a.GetPixel($x, $y); $q = $b.GetPixel($x, $y)
        $soma += [math]::Abs($p.R - $q.R) + [math]::Abs($p.G - $q.G) + [math]::Abs($p.B - $q.B)
    }
}
$diferenca = $soma / ($lado * $lado * 3)
Write-Host ("Diferenca media por canal entre o icone de {0} e o do jogo: {1:N1} (limite {2:N1})." -f (Split-Path $Exe -Leaf), $diferenca, $Limite)
if ($diferenca -gt $Limite) {
    Write-Host 'REPROVADO: o icone do executavel nao e o do jogo. rcedit ausente ou mal apontado? Veja docs/ferramentas/EXPORTAR_WINDOWS.md.' -ForegroundColor Red
    exit 1
}
Write-Host 'O executavel traz o icone do Myths'' Valley.'
exit 0
