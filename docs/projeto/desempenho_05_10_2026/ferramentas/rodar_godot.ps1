param(
    [Parameter(Mandatory = $true)][string]$Nome,
    [Parameter(Mandatory = $true)][string]$Script,
    [string[]]$Opcoes = @(),
    [int]$Teto = 900,
    [string]$Perfil = "",
    [string[]]$Motor = @(),
    [string]$Binario = ""
)
# Roda o Godot com janela (GPU de verdade) num perfil isolado, grava a saida em
# medicoes\<Nome>.log e, se passar do teto, encerra SO o PID que levantou.
$ErrorActionPreference = 'Stop'
$repo = 'C:\VIRTUALENVS\myths-valley\myths-valley-3D'
$godot = 'C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe'
if ($Binario) { $godot = $Binario }
$saida = Join-Path $PSScriptRoot 'medicoes'
[IO.Directory]::CreateDirectory($saida) | Out-Null
$log = Join-Path $saida "$Nome.log"
$err = Join-Path $saida "$Nome.err.log"
$anterior = $env:APPDATA
if ($Perfil) {
    [IO.Directory]::CreateDirectory($Perfil) | Out-Null
    $env:APPDATA = $Perfil
}
try {
    $lista = @('--path', ('"' + $repo + '"')) + $Motor + @('--script', ('"' + $Script + '"'))
    if ($Opcoes.Count -gt 0) { $lista += '--'; $lista += $Opcoes }
    $p = Start-Process -FilePath $godot -ArgumentList $lista -WorkingDirectory $repo `
        -RedirectStandardOutput $log -RedirectStandardError $err -PassThru -WindowStyle Normal
} finally {
    $env:APPDATA = $anterior
}
$relogio = [Diagnostics.Stopwatch]::StartNew()
while (-not $p.HasExited -and $relogio.Elapsed.TotalSeconds -lt $Teto) { Start-Sleep -Milliseconds 500 }
if (-not $p.HasExited) {
    & taskkill /F /T /PID $p.Id | Out-Null
    Write-Output ("TRAVOU {0}: passou do teto de {1} s (PID {2} encerrado)" -f $Nome, $Teto, $p.Id)
} else {
    Write-Output ("FIM {0}: exit={1} em {2} s" -f $Nome, $p.ExitCode, [int]$relogio.Elapsed.TotalSeconds)
}
