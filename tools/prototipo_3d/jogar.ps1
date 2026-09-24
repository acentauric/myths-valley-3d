param(
    [string]$Godot = 'C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe',
    [switch]$Compatibility
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if (-not (Test-Path -LiteralPath $Godot)) {
    throw 'Godot nao encontrado. Execute com -Godot CAMINHO_DO_GODOT.exe.'
}
$importArgs = @('--headless', '--path', ('"' + $projectRoot + '"'), '--editor', '--import')
$importProcess = Start-Process -FilePath $Godot -ArgumentList $importArgs -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -Wait
if ($importProcess.ExitCode -ne 0) { throw 'A importacao de recursos falhou. Consulte a saida do Godot.' }
$gameArgs = @('--path', ('"' + $projectRoot + '"'))
if ($Compatibility) { $gameArgs += @('--rendering-method', 'gl_compatibility') }
$game = Start-Process -FilePath $Godot -ArgumentList $gameArgs -WorkingDirectory $projectRoot -WindowStyle Normal -PassThru
Write-Output ('Myths Valley 3D iniciado. PID: ' + $game.Id)
