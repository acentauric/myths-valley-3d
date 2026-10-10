# OS TESTES DO VALE 3D: unidade em segundos quando pedida; o vale montado UMA vez, num Godot só, antes da main.
#
#   .\tools\prototipo_3d\testar.ps1                  # rápido: os testes de unidade (GUT), em segundos
#   .\tools\prototipo_3d\testar.ps1 -Completo        # unidade + a suíte do vale + os isolados
#   .\tools\prototipo_3d\testar.ps1 -Push            # ao levar a develop para a main: árvore limpa e -Completo
#   .\tools\prototipo_3d\testar.ps1 -Teste casa,regras_missoes   # pelo nome (caso da suíte ou teste de unidade)
#   .\tools\prototipo_3d\testar.ps1 -Completo -Longos            # também a partida inteira e as réguas
#   .\tools\prototipo_3d\testar.ps1 -Completo -Paralelo 3        # a suíte dividida em 3 Godots (3 montagens do vale)
#   .\tools\prototipo_3d\testar.ps1 -Teste pier_sem_queda -Extra --falsificar   # a falsificação tem de reprovar
#   .\tools\prototipo_3d\testar.ps1 -Explicar        # só diz o que rodaria
#
#
# O FLUXO (#242, decisões do autor de 09 e 10/10/2026)
#
# O trabalho entra na develop, que é fluida: lá não há bateria obrigatória, e teste
# roda quando o autor pedir (o modo rápido, que são os testes de unidade: regras,
# dados, cálculos, telas sem o vale, tudo num Godot headless). A main só recebe a
# develop quando o autor decidir, e só aí a bateria completa (-Push) é obrigatória:
# nunca por commit, por issue ou por lote.
#
# A ANTIGA BATERIA abria um Godot por portão (~230), e quase todos montavam o
# vale inteiro do zero: de 1 a 3 horas, 4 a 6 Godots em paralelo, CPU a 100%, e
# um "fecho de dependências" que, mudando uma tradução, disparava 200 portões.
# Agora são três peças, e nenhuma depende de análise de quem foi afetado:
#
#   1. UNIDADE (tests/unidade/test_*.gd, GUT 9.7 em addons/gut): um Godot,
#      sem vale, segundos. Cada teste começa com os autoloads como num Godot
#      recém-aberto (tests/unidade/base.gd).
#   2. A SUÍTE DO VALE (tests/suite/rodar.gd): um Godot que monta o vale uma
#      vez por estilo e roda todos os casos de integração em sequência
#      (tests/*.gd, `extends "res://tests/suite/caso.gd"`). Entre um caso e
#      outro os autoloads e o user:// voltam ao estado de logo depois da
#      montagem. Ver tests/suite/caso.gd.
#   3. OS ISOLADOS: o caso que precisa de um Godot novo (`const ISOLADO := true`)
#      roda num processo só dele, um de cada vez.
#
# O caso que reprova na suíte roda DE NOVO sozinho, num Godot novo. Reprovou
# sozinho também: defeito. Passou sozinho: é contaminação de um caso anterior,
# a bateria aponta e conta como verde, e o certo é consertar quem contamina ou
# declarar o caso ISOLADO.
#
# Texto e tradução não disparam nada: o modo rápido roda a unidade inteira (o
# `idiomas` inclusive) em segundos, e o completo só roda antes da main.
#
# O PUSH: árvore limpa, e o conteúdo (a árvore do HEAD) já verde nesta máquina
# com este Godot, ou -Completo verde agora. O verde fica em
# .godot/testar3d/verde.json, pela árvore do commit e não pelo commit: um
# rebase que não muda conteúdo não pede outra bateria.
#
# O PAINEL AO VIVO: toda rodada escreve .godot/testar3d/bateria.log e sobe o
# painel (tools/prototipo_3d/painel_bateria.py) em http://127.0.0.1:8765/,
# salvo com -SemPainel.
#
#
#     NUNCA MATAR PROCESSO DO GODOT POR NOME.
#
# `taskkill /F /IM Godot_v4.7.2-stable_win64.exe` mata por nome de imagem, e esse
# é o binário do EDITOR. Já fechou o editor aberto do outro lado da mesa no meio do
# trabalho, mais de uma vez, levando junto cena não salva. Aqui se mata só por PID,
# e só PID que este script levantou.

param(
	[string[]]$Teste = @(),
	[switch]$Completo,
	[switch]$Push,
	[switch]$Longos,
	[switch]$Explicar,
	[switch]$SemPainel,
	# Argumentos a mais para os casos da suíte, como a falsificação: -Teste pier_sem_queda -Extra --falsificar
	[string[]]$Extra = @(),
	[int]$Porta = 8765,
	# Divide a suíte em N Godots (cada um monta o vale uma vez), equilibrados pelo tempo da
	# última rodada. O padrão é um Godot só, como pede a #242; 2 ou 3 cortam o tempo pela metade ou mais.
	[int]$Paralelo = 1,
	[string]$Godot = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe",
	# Sem saída nova por tanto tempo, o Godot travou num laço (o anfitrião escreve a cada 15 s).
	[int]$SilencioSegundos = 600,
	# Onde o Godot roda. Só muda para testar o próprio runner numa cópia.
	[string]$Projeto = ""
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$ErrorActionPreference = "Stop"
$raiz = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot "..") "..")).Path
if ($Projeto -eq "") { $Projeto = $raiz }
Push-Location $raiz
$noWindows = ($PSVersionTable.PSEdition -eq "Desktop") -or $IsWindows
$semBom = New-Object System.Text.UTF8Encoding($false)
$relogioTotal = [Diagnostics.Stopwatch]::StartNew()
if ($Push) { $Completo = $true }

function Ler-Arquivo([string]$arquivo) {
	if (-not (Test-Path -LiteralPath $arquivo)) { return "" }
	$fluxo = [IO.File]::Open($arquivo, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
	$leitor = New-Object IO.StreamReader($fluxo, $semBom)
	try { return $leitor.ReadToEnd() } finally { $leitor.Dispose() }
}

function Git-Saida([string[]]$argumentos) {
	# No 5.1, stderr de .exe vira ErrorRecord e, com Stop, derruba o script.
	$antes = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try { $saida = & git -c core.quotepath=false @argumentos 2>$null } finally { $ErrorActionPreference = $antes }
	if ($LASTEXITCODE -ne 0) { return $null }
	return @($saida)
}


# ---------------------------------------------------------------------------
# PRÉ-VOO: autoload versionado, LFS baixado, Godot presente.
#
# O `project.godot` já registrou um autoload com o arquivo só na máquina de quem
# rodou o sincronizador: quem clonasse pegava um projeto que não abre. E o Godot
# termina com 0 mesmo recebendo ponteiros LFS.

$faltando = @()
$secao = ""
foreach ($linha in [IO.File]::ReadAllLines((Join-Path $raiz "project.godot"), $semBom)) {
	if ($linha -match '^\s*\[(.+)\]\s*$') { $secao = $Matches[1]; continue }
	if ($secao -ne "autoload") { continue }
	if ($linha -notmatch '^\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*"\*?res://([^"]+\.(gd|tscn))"\s*$') { continue }
	$relativo = $Matches[1]
	if (-not (Test-Path (Join-Path $raiz $relativo))) { $faltando += "$relativo (nao existe no disco)"; continue }
	if ([string]::IsNullOrWhiteSpace(((& git -C $raiz ls-files -- $relativo) -join ""))) { $faltando += "$relativo (existe aqui, mas nao esta versionado)" }
}
if ($faltando.Count -gt 0) {
	Write-Host "PRE-VOO REPROVADO: autoload registrado sem arquivo versionado"
	foreach ($f in $faltando) { Write-Host ("         " + $f) }
	Pop-Location; exit 1
}
$ponteiros = @()
foreach ($arquivo in @(git ls-files -- assets | Where-Object { $_ -match '\.(glb|fbx|wav)$' })) {
	$caminho = Join-Path $raiz $arquivo
	if (-not (Test-Path -LiteralPath $caminho)) { continue }
	$fluxo = [IO.File]::OpenRead($caminho)
	try {
		$cabeca = New-Object byte[] 7
		if ($fluxo.Read($cabeca, 0, 7) -eq 7 -and [Text.Encoding]::ASCII.GetString($cabeca) -eq 'version') { $ponteiros += $arquivo }
	} finally { $fluxo.Dispose() }
}
if ($ponteiros.Count -gt 0) {
	Write-Host "LFS PENDENTE: execute git lfs pull antes dos testes."
	foreach ($arquivo in ($ponteiros | Select-Object -First 5)) { Write-Host ("         " + $arquivo) }
	Pop-Location; exit 1
}
if (-not (Test-Path -LiteralPath $Godot)) {
	Write-Host "GODOT NAO ENCONTRADO: $Godot"
	Write-Host "         passe o executavel console com -Godot <caminho>"
	Pop-Location; exit 1
}
$itemGodot = Get-Item -LiteralPath $Godot
$motor = $itemGodot.Name + ":" + $itemGodot.Length

$pastaCache = Join-Path $raiz ".godot/testar3d"
[IO.Directory]::CreateDirectory($pastaCache) | Out-Null
$arquivoVerde = Join-Path $pastaCache "verde.json"


# ---------------------------------------------------------------------------
# O PUSH: árvore limpa, e o conteúdo já verde ou verde agora.

$arvoreHead = $null
if ($Push) {
	# Doc, .uid e .import não contam: o editor reescreve os dois últimos sozinho.
	$sujos = @(Git-Saida @("status", "--porcelain=v1", "-uall") | Where-Object { $_ -and $_.Length -gt 3 } | ForEach-Object { $_.Substring(3).Trim('"') } |
		Where-Object { $_ -notmatch '\.(uid|import|md)$' -and $_ -notmatch '^docs/' -and $_ -notmatch '_tripo_[^/]*\.(png|jpe?g)$' })
	if ($sujos.Count -gt 0) {
		Write-Host ("PUSH: ha " + $sujos.Count + " arquivo(s) fora de commit: " + (($sujos | Select-Object -First 3) -join ", "))
		Write-Host "         o push envia commits: commite ou guarde (git stash) e rode de novo."
		Pop-Location; exit 1
	}
	$arvoreHead = Git-Saida @("rev-parse", "HEAD^{tree}") | Select-Object -First 1
	if (Test-Path -LiteralPath $arquivoVerde) {
		try { $verde = (Ler-Arquivo $arquivoVerde) | ConvertFrom-Json } catch { $verde = $null }
		if ($null -ne $verde -and $verde.arvore -eq $arvoreHead -and $verde.motor -eq $motor) {
			Write-Host ("PUSH OK: este conteudo ja passou na bateria completa nesta maquina (" + $verde.quando + ")")
			Pop-Location; exit 0
		}
	}
}


# ---------------------------------------------------------------------------
# O PLANO.

$saida = Join-Path ([IO.Path]::GetTempPath()) ("testar3d-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $saida | Out-Null
$arquivoLog = Join-Path $pastaCache "bateria.log"
[IO.File]::WriteAllText($arquivoLog, "", $semBom)

function Diz([string]$linha) {
	Write-Host $linha
	[IO.File]::AppendAllText($arquivoLog, $linha + "`n", $semBom)
}

# Um Godot com perfil descartável (saves e preferências), stdout e stderr em arquivos.
function Iniciar-Godot([string]$nome, [string[]]$argumentos) {
	$perfil = Join-Path $saida ("perfil-" + $nome)
	[IO.Directory]::CreateDirectory($perfil) | Out-Null
	$log = Join-Path $saida "$nome.txt"
	$anterior = @($env:APPDATA, $env:XDG_DATA_HOME, $env:XDG_CONFIG_HOME, $env:TESTAR3D_PERFIL_DESCARTAVEL)
	$env:APPDATA = $perfil; $env:XDG_DATA_HOME = $perfil; $env:XDG_CONFIG_HOME = $perfil; $env:TESTAR3D_PERFIL_DESCARTAVEL = "1"
	try {
		$opcoes = @{
			FilePath = $Godot; PassThru = $true; WorkingDirectory = $Projeto
			# `--path .`, e não o caminho inteiro: no 5.1 o -ArgumentList não põe aspas
			# em argumento com espaço.
			ArgumentList = (@("--headless", "--path", ".") + $argumentos)
			RedirectStandardOutput = $log; RedirectStandardError = "$log.err"
		}
		if ($noWindows) { $opcoes["WindowStyle"] = "Hidden" }
		$processo = Start-Process @opcoes
	} finally { $env:APPDATA = $anterior[0]; $env:XDG_DATA_HOME = $anterior[1]; $env:XDG_CONFIG_HOME = $anterior[2]; $env:TESTAR3D_PERFIL_DESCARTAVEL = $anterior[3] }
	$null = $processo.Handle
	return @{ nome = $nome; processo = $processo; log = $log }
}

function Encerrar([object]$execucao) {
	$p = $execucao.processo
	if ($p.HasExited) { return }
	try {
		if ($noWindows) { & taskkill /F /T /PID $p.Id 2>&1 | Out-Null } else { Stop-Process -Id $p.Id -Force }
	} catch { if (-not $p.HasExited) { throw } }
	$p.WaitForExit(5000) | Out-Null
}

# Espera o Godot terminar, repassando ao log as linhas que `filtro` aceita.
# Godot calado por $SilencioSegundos travou num laço: sai por PID.
function Acompanhar([object]$execucao, [scriptblock]$filtro) {
	$lidas = 0
	$silencio = [Diagnostics.Stopwatch]::StartNew()
	$calou = $false
	while ($true) {
		$acabou = $execucao.processo.HasExited
		$linhas = (Ler-Arquivo $execucao.log) -split "`n"
		# A última linha pode estar pela metade enquanto o processo escreve.
		$prontas = if ($acabou) { $linhas.Count } else { $linhas.Count - 1 }
		for ($i = $lidas; $i -lt $prontas; $i++) {
			$l = $linhas[$i].TrimEnd("`r")
			if (& $filtro $l) { Diz $l }
		}
		if ($prontas -gt $lidas) { $lidas = $prontas; $silencio.Restart() }
		if ($acabou) { break }
		if ($silencio.Elapsed.TotalSeconds -ge $SilencioSegundos) { $calou = $true; Encerrar $execucao; continue }
		Start-Sleep -Milliseconds 500
	}
	$execucao.processo.WaitForExit()
	return @{ codigo = $execucao.processo.ExitCode; calou = $calou; texto = (Ler-Arquivo $execucao.log); erro = (Ler-Arquivo ($execucao.log + ".err")) }
}

# Como Acompanhar, para vários Godots ao mesmo tempo (a suíte dividida com -Paralelo).
function Acompanhar-Varios([object[]]$execucoes, [scriptblock]$filtro) {
	$lidas = @{}; $silencio = @{}; $calou = @{}
	foreach ($e in $execucoes) { $lidas[$e.nome] = 0; $silencio[$e.nome] = [Diagnostics.Stopwatch]::StartNew(); $calou[$e.nome] = $false }
	while ($true) {
		$vivos = 0
		foreach ($e in $execucoes) {
			$acabou = $e.processo.HasExited
			$linhas = (Ler-Arquivo $e.log) -split "`n"
			$prontas = if ($acabou) { $linhas.Count } else { $linhas.Count - 1 }
			for ($i = $lidas[$e.nome]; $i -lt $prontas; $i++) {
				$l = $linhas[$i].TrimEnd("`r")
				if (& $filtro $l) { Diz $l }
			}
			if ($prontas -gt $lidas[$e.nome]) { $lidas[$e.nome] = $prontas; $silencio[$e.nome].Restart() }
			if (-not $acabou) {
				$vivos++
				if ($silencio[$e.nome].Elapsed.TotalSeconds -ge $SilencioSegundos) { $calou[$e.nome] = $true; Encerrar $e }
			}
		}
		if ($vivos -eq 0) { break }
		Start-Sleep -Milliseconds 500
	}
	foreach ($e in $execucoes) { $e.processo.WaitForExit() }
	return $calou
}

$linhaDaSuite = { param($l) $l -match '^\[\s*\d+/\d+\]|^\s{9}\S|^\s+\.\.\. rodando:|^suite:|^vale montado|^caso inexistente' }

# O que existe de cada lado.
$unidades = @(Get-ChildItem (Join-Path $raiz "tests/unidade") -Filter "test_*.gd" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.BaseName })
$pedidos = @()
foreach ($t in $Teste) { foreach ($parte in ($t -split ',')) { if ($parte.Trim() -ne "") { $pedidos += ($parte.Trim() -replace '\.gd$', '') } } }
$unidadesPedidas = @()
$casosPedidos = @()
foreach ($p in $pedidos) {
	if ($unidades -contains $p) { $unidadesPedidas += $p }
	elseif ($unidades -contains "test_$p") { $unidadesPedidas += "test_$p" }
	elseif (Test-Path (Join-Path $raiz "tests/$p.gd")) { $casosPedidos += $p }
	else { Write-Host "teste inexistente: $p"; Pop-Location; exit 1 }
}

# A IMPORTAÇÃO: num `--script` o Godot não importa nada, e recurso novo sem
# cache (ou class_name novo fora do cache de classes) faria o caso não abrir.
# Importa quando o conteúdo mudou desde a última importação desta máquina.
$carimbo = Join-Path $pastaCache "importado.txt"
$estadoAgora = ((Git-Saida @("rev-parse", "HEAD")) -join "") + "|" + ((Git-Saida @("status", "--porcelain=v1", "-uall")) -join "|") + "|" + $motor
$hashAgora = [BitConverter]::ToString([Security.Cryptography.SHA1]::Create().ComputeHash($semBom.GetBytes($estadoAgora))).Replace("-", "")
$precisaImportar = (-not (Test-Path -LiteralPath (Join-Path $raiz ".godot/global_script_class_cache.cfg"))) -or ((Ler-Arquivo $carimbo).Trim() -ne $hashAgora)

$rodarUnidade = $Completo -or ($pedidos.Count -eq 0) -or ($unidadesPedidas.Count -gt 0)
$rodarSuite = $Completo -or ($casosPedidos.Count -gt 0)

$plano = $null

function Importar {
	Diz "importando (o conteudo mudou desde a ultima importacao)..."
	$imp = Iniciar-Godot "importacao" @("--editor", "--import")
	if (-not $imp.processo.WaitForExit(900000)) { Encerrar $imp; Diz "aviso: a importacao passou de 15 min e foi encerrada" }
	[IO.File]::WriteAllText($carimbo, $hashAgora, $semBom)
	$script:precisaImportar = $false
}

if ($precisaImportar -and -not $Explicar -and ($rodarSuite -or $rodarUnidade)) { Importar }

if ($rodarSuite) {
	$argsPlano = @("--script", "res://tests/suite/rodar.gd", "--", "--listar")
	if ($casosPedidos.Count -gt 0) { $argsPlano += ("--casos=" + ($casosPedidos -join ",")) }
	if ($Longos) { $argsPlano += "--longos" }
	$exec = Iniciar-Godot "plano" $argsPlano
	$r = Acompanhar $exec { param($l) $false }
	$linhaPlano = ($r.texto -split "`n") | Where-Object { $_.StartsWith("PLANO:") } | Select-Object -First 1
	if (-not $linhaPlano) {
		Diz "a suite nao abriu: o anfitriao nao imprimiu o plano"
		foreach ($l in (($r.erro -split "`n") | Where-Object { $_ -match 'ERROR' } | Select-Object -First 5)) { Diz ("         " + $l.Trim()) }
		Pop-Location; exit 1
	}
	$plano = $linhaPlano.Substring(6) | ConvertFrom-Json
	foreach ($n in @($plano.inexistentes)) { if ($n) { Write-Host "caso inexistente: $n"; Pop-Location; exit 1 } }
}

$nUnidade = if ($rodarUnidade) { 1 } else { 0 }
$nSuite = if ($null -ne $plano) { @($plano.nomes).Count } else { 0 }
$isolados = if ($null -ne $plano -and $casosPedidos.Count -eq 0) { @($plano.isolados | Where-Object { $_ }) } else { @() }
$fora = if ($null -ne $plano) { @($plano.fora_da_suite | Where-Object { $_ }) } else { @() }
$total = $nUnidade + $nSuite + $isolados.Count + $fora.Count

$modo = if ($Push) { "push (completo)" } elseif ($Completo) { "completo" } elseif ($pedidos.Count -gt 0) { "pelo nome" } else { "rapido (unidade)" }
Diz ("bateria: " + $total + " etapa(s), modo " + $modo)
if ($rodarUnidade) {
	$quais = if ($unidadesPedidas.Count -gt 0) { $unidadesPedidas -join ", " } else { "" + $unidades.Count + " arquivo(s) de teste" }
	Diz ("  unidade (GUT, um Godot): " + $quais)
}
if ($nSuite -gt 0) { Diz ("  suite do vale (um Godot): " + $nSuite + " caso(s)") }
if ($isolados.Count -gt 0) { Diz ("  isolados (um Godot cada): " + ($isolados -join ", ")) }
if ($fora.Count -gt 0) { Diz ("  fora da suite (SceneTree propria): " + ($fora -join ", ")) }
if ($null -ne $plano -and @($plano.longos_deixados | Where-Object { $_ }).Count -gt 0) { Diz ("  longos, so com -Longos: " + (@($plano.longos_deixados) -join ", ")) }
if ($Explicar) { Pop-Location; exit 0 }


# ---------------------------------------------------------------------------
# O PAINEL.

if (-not $SemPainel) {
	$ocupada = $false
	try { $c = New-Object Net.Sockets.TcpClient; $c.Connect("127.0.0.1", $Porta); $c.Close(); $ocupada = $true } catch { }
	$python = Get-Command python -ErrorAction SilentlyContinue
	if (-not $ocupada -and $null -ne $python) {
		$painel = Join-Path $PSScriptRoot "painel_bateria.py"
		$opcoesPainel = @{ FilePath = $python.Source; ArgumentList = @("`"$painel`"", "`"$arquivoLog`"", "$Porta", "`"Bateria do vale`""); PassThru = $true }
		if ($noWindows) { $opcoesPainel["WindowStyle"] = "Hidden" }
		$null = Start-Process @opcoesPainel
	}
	if ($ocupada -or $null -ne $python) { Write-Host ("painel ao vivo: http://127.0.0.1:" + $Porta + "/") }
}


# ---------------------------------------------------------------------------
# A EXECUÇÃO.

$feitos = 0
$reprovados = New-Object Collections.Generic.List[string]
$contaminados = New-Object Collections.Generic.List[string]
$errosFatais = "Parse Error|Compile Error|SCRIPT ERROR|Failed loading resource"
$relogio = [Diagnostics.Stopwatch]::new()

try {
	# 1. UNIDADE
	if ($rodarUnidade) {
		$relogio.Restart()
		$argsGut = @("--script", "res://addons/gut/gut_cmdln.gd", "-gconfig=res://.gutconfig.json", "-gexit")
		if ($unidadesPedidas.Count -gt 0) { $argsGut = @("--script", "res://addons/gut/gut_cmdln.gd", "-gconfig=res://.gutconfig.json", "-gexit", "-gdir=", ("-gtest=" + (($unidadesPedidas | ForEach-Object { "res://tests/unidade/$_.gd" }) -join ","))) }
		$exec = Iniciar-Godot "unidade" $argsGut
		$r = Acompanhar $exec { param($l) $false }
		$feitos++
		$segundos = [Math]::Round($relogio.Elapsed.TotalSeconds)
		$texto = $r.texto
		$nTestes = if ($texto -match '(?m)^Tests\s+(\d+)') { [int]$Matches[1] } else { 0 }
		$nFalhas = if ($texto -match '(?m)^Failing( Tests)?\s+(\d+)') { [int]$Matches[2] } else { 0 }
		$nAsserts = if ($texto -match '(?m)^Asserts\s+(\d+)') { [int]$Matches[1] } else { 0 }
		$falhasGut = @(($texto -split "`n") | Where-Object { $_ -match '^\s*\[Failed\]|^res://tests/unidade/\S+\.gd$|^\s*- test_' } | ForEach-Object { $_.Trim() } | Select-Object -First 12)
		$fatal = ($r.erro + $texto) -match 'Parse Error|Compile Error'
		if ($r.codigo -eq 0 -and $nFalhas -eq 0 -and $nTestes -gt 0 -and -not $r.calou -and -not $fatal) {
			Diz ("[{0,3}/{1}] ok       {2,-26} {3,4}s  {4} testes, {5} conferencias, 0 falhas" -f $feitos, $total, "unidade", $segundos, $nTestes, $nAsserts)
		} else {
			$status = if ($r.calou) { "TRAVOU" } elseif ($fatal) { "NAO ABRE" } else { "FALHOU" }
			Diz ("[{0,3}/{1}] {2,-8} {3,-26} {4,4}s  {5} testes, {6} falha(s), saiu com {7}" -f $feitos, $total, $status, "unidade", $segundos, $nTestes, $nFalhas, $r.codigo)
			foreach ($f in $falhasGut) { Diz ("         " + $f) }
			if ($fatal) { foreach ($l in ((($r.erro + $texto) -split "`n") | Where-Object { $_ -match 'Parse Error|Compile Error' } | Select-Object -First 3)) { Diz ("         " + $l.Trim()) } }
			$reprovados.Add("unidade")
		}
	}

	# 2. A SUÍTE DO VALE
	$reprovadosNaSuite = @()
	if ($nSuite -gt 0) {
		# Um caso que DERRUBA o Godot (crash do motor) não leva a suíte junto: ele
		# reprova, e um Godot novo continua do caso seguinte. Até 5 quedas.
		$restantes = @($plano.nomes)
		$vistos = @()
		$rodada = 0
		# Lê o resultado de uma rodada da suíte: quem rodou, quem reprovou, quem precisou do vale novo.
		function Ler-Resultado([string]$pasta, [string]$rotulo) {
			$arquivo = Join-Path $pasta "resultado.json"
			if (-not (Test-Path -LiteralPath $arquivo)) { return }
			Copy-Item -LiteralPath $arquivo -Destination (Join-Path $pastaCache ($rotulo + ".json")) -Force
			$res = $null
			try { $res = (Ler-Arquivo $arquivo) | ConvertFrom-Json } catch { return }
			foreach ($c in $res.casos) {
				$script:vistos += $c.nome
				if ($c.contaminado) { $contaminados.Add($c.nome) }
				# O caso do vale que reprovou já rodou de novo com o vale montado do zero: reprovou duas vezes.
				# Reprovou na suíte (mesmo depois do vale novo): a palavra final é de um Godot novo, só dele.
				if ($c.status -ne "ok") { $script:reprovadosNaSuite += $c.nome }
			}
		}
		foreach ($velho in @(Get-ChildItem -LiteralPath $pastaCache -Filter "suite-*.json" -ErrorAction SilentlyContinue)) {
			# Os tempos da rodada anterior equilibram a divisão; lidos antes de serem trocados.
			if ($null -eq $tempos) { $tempos = @{} }
			try { foreach ($c in ((Ler-Arquivo $velho.FullName) | ConvertFrom-Json).casos) { $tempos[$c.nome] = [double]$c.segundos } } catch { }
		}
		if ($Paralelo -gt 1 -and $restantes.Count -gt 1) {
			if ($null -eq $tempos) { $tempos = @{} }
			$cestos = @(); $somas = @()
			for ($k = 0; $k -lt $Paralelo; $k++) { $cestos += , (New-Object Collections.Generic.List[string]); $somas += 0.0 }
			$resto = @($plano.casos | Sort-Object { if ($tempos.ContainsKey($_.nome)) { -$tempos[$_.nome] } else { -20.0 } })
			foreach ($c in $resto) {
				$menor = 0
				for ($k = 1; $k -lt $Paralelo; $k++) { if ($somas[$k] -lt $somas[$menor]) { $menor = $k } }
				$cestos[$menor].Add($c.nome); $somas[$menor] += $(if ($tempos.ContainsKey($c.nome)) { $tempos[$c.nome] } else { 20.0 })
			}
			Diz ("suite dividida em " + $Paralelo + " Godots: " + (($cestos | ForEach-Object { "" + $_.Count + " casos" }) -join ", "))
			$execucoes = @(); $base = $feitos
			for ($k = 0; $k -lt $Paralelo; $k++) {
				if ($cestos[$k].Count -eq 0) { continue }
				$pastaK = Join-Path $saida ("suite-p" + $k)
				$argsK = @("--script", "res://tests/suite/rodar.gd", "--", "--perfil-descartavel", ("--saida=" + $pastaK.Replace('\', '/')), ("--deslocamento=" + $base), ("--total=" + $total), ("--casos=" + ($cestos[$k] -join ",")))
				if ($Longos) { $argsK += "--longos" }
				$argsK += $Extra
				$execucoes += (Iniciar-Godot ("suite-p" + $k) $argsK)
				$base += $cestos[$k].Count
			}
			$null = Acompanhar-Varios $execucoes $linhaDaSuite
			for ($k = 0; $k -lt $Paralelo; $k++) { Ler-Resultado (Join-Path $saida ("suite-p" + $k)) ("suite-p" + $k) }
			# O que um Godot que caiu não rodou segue no laço de baixo, um Godot de cada vez.
			$restantes = @(@($plano.nomes) | Where-Object { $vistos -notcontains $_ })
			$rodada = 1
		}
		while ($restantes.Count -gt 0) {
			$rodada++
			$pastaSuite = Join-Path $saida ("suite-" + $rodada)
			$argsSuite = @("--script", "res://tests/suite/rodar.gd", "--", "--perfil-descartavel", ("--saida=" + $pastaSuite.Replace('\', '/')), ("--deslocamento=" + ($feitos + $vistos.Count)), ("--total=" + $total))
			if ($rodada -gt 1 -or $casosPedidos.Count -gt 0) { $argsSuite += ("--casos=" + ($restantes -join ",")) }
			if ($Longos) { $argsSuite += "--longos" }
			$argsSuite += $Extra
			$exec = Iniciar-Godot ("suite-" + $rodada) $argsSuite
			$r = Acompanhar $exec $linhaDaSuite
			# O último resultado fica no cache: tempo de cada caso e quem precisou do vale novo.
			Ler-Resultado $pastaSuite ("suite-" + $rodada)
			$restantes = @(@($plano.nomes) | Where-Object { $vistos -notcontains $_ })
			if ($restantes.Count -eq 0) { break }
			# Saiu antes de acabar: quem rodava agora é o primeiro dos que faltam.
			$culpado = $restantes[0]
			$porque = if ($r.calou) { "ficou calado " + $SilencioSegundos + " s e foi encerrado" } else { "caiu (saiu com " + $r.codigo + ")" }
			Diz ("[{0,3}/{1}] NAO ABRE {2,-26} {3,4}s  o Godot da suite {4}" -f ($feitos + $vistos.Count + 1), $total, $culpado, 0, $porque)
			foreach ($l in (($r.erro -split "`n") | Where-Object { $_ -match ($errosFatais + '|signal \d+|GDScript backtrace|^\s+\[\d+\] .*\.gd:') } | Select-Object -Last 4)) { Diz ("         " + $l.Trim()) }
			$reprovados.Add($culpado)
			$vistos += $culpado
			$restantes = @($restantes | Select-Object -Skip 1)
			if ($rodada -ge 6) {
				Diz ("o Godot da suite caiu " + $rodada + " vezes; " + $restantes.Count + " caso(s) nao rodaram")
				foreach ($n in $restantes) { $reprovados.Add($n) }
				break
			}
		}
		$feitos += $nSuite
	}

	# 3. OS ISOLADOS, um Godot cada (e o que reprovou na suíte, de novo, sozinho).
	function Rodar-Sozinho([string]$nome, [int]$numero) {
		$argsCaso = @("--script", "res://tests/suite/rodar.gd", "--", "--perfil-descartavel", ("--saida=" + (Join-Path $saida ("sozinho-" + $nome)).Replace('\', '/')), ("--casos=" + $nome))
		$argsCaso += $Extra
		if ($numero -gt 0) { $argsCaso += @(("--deslocamento=" + ($numero - 1)), ("--total=" + $total)) }
		$filtro = if ($numero -gt 0) { $linhaDaSuite } else { { param($l) $l -match '^\s{9}\S' } }
		$exec = Iniciar-Godot ("sozinho-" + $nome) $argsCaso
		$r = Acompanhar $exec $filtro
		$linha = (($r.texto -split "`n") | Where-Object { $_ -match '^\[\s*\d+/\d+\]' } | Select-Object -Last 1)
		$ok = ($r.codigo -eq 0 -and $linha -match '^\[\s*\d+/\d+\]\s+ok\s')
		if ($numero -le 0) {
			$resumo = if ($linha) { ($linha -replace '^\[\s*\d+/\d+\]\s+', '').Trim() } else { "nao terminou (saiu com " + $r.codigo + ")" }
			Diz ("         sozinho: " + $resumo)
		}
		return $ok
	}
	foreach ($nome in $isolados) {
		$feitos++
		if (-not (Rodar-Sozinho $nome $feitos)) { $reprovados.Add($nome) }
	}
	if ($reprovadosNaSuite.Count -gt 0) {
		Diz ""
		Diz ("repetindo sozinho, num Godot novo, o que reprovou na suite: " + ($reprovadosNaSuite -join ", "))
		foreach ($nome in $reprovadosNaSuite) {
			if (Rodar-Sozinho $nome 0) { $contaminados.Add($nome) } else { $reprovados.Add($nome) }
		}
	}

	# 4. FORA DA SUÍTE: portão que ainda é uma SceneTree própria (herda de uma ferramenta).
	foreach ($nome in $fora) {
		$feitos++
		$relogio.Restart()
		$exec = Iniciar-Godot ("fora-" + $nome) @("--script", "res://tests/$nome.gd")
		$r = Acompanhar $exec { param($l) $false }
		$segundos = [Math]::Round($relogio.Elapsed.TotalSeconds)
		$linhas = $r.texto -split "`n"
		$falhas = @($linhas | Where-Object { $_ -clike "FALHA:*" } | ForEach-Object { $_.Trim() })
		$resumo = ($linhas | Where-Object { $_ -cmatch "_OK" } | Select-Object -Last 1)
		if ($null -eq $resumo) { $resumo = "" }
		$resumo = $resumo.Trim(); if ($resumo.Length -gt 110) { $resumo = $resumo.Substring(0, 107) + "..." }
		if (($r.texto + $r.erro) -match $errosFatais) {
			Diz ("[{0,3}/{1}] NAO ABRE {2,-26} {3,4}s  erro de script" -f $feitos, $total, $nome, $segundos)
			foreach ($l in ((($r.texto + $r.erro) -split "`n") | Where-Object { $_ -match $errosFatais } | Select-Object -First 2)) { Diz ("         " + $l.Trim()) }
			$reprovados.Add($nome)
		} elseif ($r.calou -or $r.codigo -ne 0 -or $falhas.Count -gt 0) {
			$status = if ($r.calou) { "TRAVOU" } else { "FALHOU" }
			Diz ("[{0,3}/{1}] {2,-8} {3,-26} {4,4}s  saiu com {5}" -f $feitos, $total, $status, $nome, $segundos, $r.codigo)
			foreach ($f in ($falhas | Select-Object -First 8)) { Diz ("         " + $f) }
			$reprovados.Add($nome)
		} else {
			Diz ("[{0,3}/{1}] ok       {2,-26} {3,4}s  {4}" -f $feitos, $total, $nome, $segundos, $resumo)
		}
	}
} finally {
	$temporarios = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
	$alvo = [IO.Path]::GetFullPath($saida)
	if ($alvo.StartsWith($temporarios, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $alvo -Recurse -Force -ErrorAction SilentlyContinue }
}

# SEM ACENTO NAS LINHAS DE RESUMO, de propósito: o PowerShell 5.1 lê .ps1 sem BOM
# na página de código da máquina, e acento sai embaralhado no console.
Diz ""
$minutos = [Math]::Round($relogioTotal.Elapsed.TotalMinutes, 1)
if ($contaminados.Count -gt 0) {
	Diz ("aviso: reprovaram no estado deixado por um caso anterior e passaram com o vale novo ou num Godot so deles: " + ($contaminados -join ", "))
	Diz "         contam como verdes; o certo e o caso anterior devolver o que mexe (ou este se declarar const ISOLADO := true)"
}
if ($reprovados.Count -gt 0) {
	Diz ("" + $reprovados.Count + " etapa(s) reprovado(s) de " + $total + " em " + $minutos + " min: " + ($reprovados -join ", "))
	if ($Push) { Diz "PUSH: reprovado; nada vai para a main assim" }
	Pop-Location; exit 1
}
Diz ("BATERIA OK: as " + $total + " etapas passaram em " + $minutos + " min")
if ($Completo -and $pedidos.Count -eq 0) {
	$arvore = if ($null -ne $arvoreHead) { $arvoreHead } else { Git-Saida @("rev-parse", "HEAD^{tree}") | Select-Object -First 1 }
	$limpo = @(Git-Saida @("status", "--porcelain=v1") | Where-Object { $_ -and $_.Substring(3) -notmatch '\.(uid|import|md)$' }).Count -eq 0
	if ($limpo -and $arvore) {
		[IO.File]::WriteAllText($arquivoVerde, (@{ arvore = $arvore; motor = $motor; quando = (Get-Date).ToString("s") } | ConvertTo-Json), $semBom)
	}
}
if ($Push) { Diz "PUSH OK: a bateria completa passou" }
Pop-Location
