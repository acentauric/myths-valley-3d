# RODAR OS PORTÕES DO VALE 3D, com teto de tempo e sem matar nada que não seja meu.
#
#   .\tools\prototipo_3d\testar.ps1                 # a bateria inteira
#   .\tools\prototipo_3d\testar.ps1 -Teste cadeia_das_missoes
#
#
# POR QUE ESTE ARQUIVO EXISTE
#
# Os portões deste projeto moram em tests/ e usam a raiz atual.
#
# Enquanto não havia este script, a bateria do vale era rodada teste a teste,
# à mão. É justamente onde a regra mais cara deste trabalho se perde:
#
#     NUNCA MATAR PROCESSO DO GODOT POR NOME.
#
# `taskkill /F /IM Godot_v4.7.2-stable_win64.exe` mata por nome de imagem, e
# esse é o binário do EDITOR. Já fechou o editor aberto do outro lado da mesa
# no meio do trabalho, mais de uma vez, levando junto cena não salva. Aqui se
# mata só por PID, e só PID que este script levantou.
#
# O runner usa teto de tempo em vez de processo pendurado,
# `$processo.Handle` tocado antes de o processo morrer, stdout e stderr em
# arquivos separados, e `-clike` para "FALHA:" não casar com "Falhas: 0".

param(
	[string]$Teste = "",
	# Argumentos opcionais do portao, por exemplo --falsificar.
	[string[]]$ArgumentosTeste = @(),
	# Simula quadros de 1/60 s sem esperar o relogio de parede (opcional).
	[switch]$QuadrosFixos,
	[switch]$ComJanela,
	[switch]$Compatibility,
	[string]$Godot = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe",
	# O vale monta o mundo inteiro antes de qualquer pergunta, e a cadeia das
	# missões ainda joga os nove passos. Quem passar disto está preso.
	[int]$TetoSegundos = 420
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8

$ErrorActionPreference = "Stop"
$raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Push-Location $raiz

$saida = Join-Path $env:TEMP ("testar3d-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $saida | Out-Null
$semBom = New-Object System.Text.UTF8Encoding($false)

function Ler-Log([string]$arquivo) {
	if (-not (Test-Path -LiteralPath $arquivo)) { return "" }
	$fluxo = [IO.File]::Open($arquivo, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
	$leitor = New-Object IO.StreamReader($fluxo, $semBom)
	try { return $leitor.ReadToEnd() } finally { $leitor.Dispose() }
}

function Encerrar-Teste($processo) {
	if ($processo.HasExited) { return }
	try { & taskkill /F /T /PID $processo.Id 2>&1 | Out-Null } catch {
		# quit(1) pode encerrar entre a leitura do erro e o taskkill.
		if (-not $processo.HasExited) { throw }
	}
	$processo.WaitForExit(5000) | Out-Null
}

# OS QUE NÃO SÃO PORTÃO.
#
# `ordem_da_visita` é uma RÉGUA: ele mede quanto o jogador anda na ordem de
# hoje e imprime o número. Não há resposta certa — o número é para ser lido e
# comparado depois de mexer na ordem das visitas. Portão que não pode reprovar
# não é portão, e deixá-lo na bateria ensina a ignorar a bateria.
$REGUAS = @("ordem_da_visita")

# QUEM PRECISA DE MAIS TEMPO, E POR QUE. O teto geral e de 420 s e serve a
# quase tudo. O `agua_rasa` nao: ele atravessa o bracinho de mar a pe, e o
# vigor novo (correr custa vigor) deixou a travessia mais lenta, entao o
# orcamento dele subiu para 14000 + 16000 quadros de fisica -- perto de 500 s
# de relogio. Cortar o orcamento faria o portao dizer "nao da pe" quando o que
# falta e distancia; cortar o teto faz o portao TRAVAR sem medir nada. O que
# custa caro e o tempo, e e o que se da.
$TETO_DO_PORTAO = @{
	"agua_rasa" = 700
}

$quais = @()
if ($Teste -ne "") {
	$quais = @($Teste -replace "\.gd$", "")
} else {
	$quais = Get-ChildItem (Join-Path $raiz "tests") -Filter "*.gd" |
		Sort-Object Name | ForEach-Object { $_.BaseName } |
		Where-Object { $REGUAS -notcontains $_ }
}


# PRÉ-VOO: TODO AUTOLOAD REGISTRADO TEM DE ESTAR VERSIONADO.
#
# Este bloco existe por um defeito que passou pela bateria inteira de verde.
# O `project.godot` registrava
#
#     Mochila="*res://scripts/ui/mochila.gd"
#
# e o arquivo estava só na máquina de quem rodou o
# `sincronizar-compartilhado.ps1` — nunca entrou no `git add`. Aqui tudo
# passava; quem clonasse a branch pegava um autoload apontando para arquivo
# que não existe, e autoload que não carrega impede o Godot de subir o projeto
# INTEIRO. Foi assim que o protótipo saiu do ar para o autor, duas vezes.
#
# Nenhum portão dentro do Godot pega isto: rodando aqui o arquivo existe. A
# pergunta não é "o arquivo existe?", é "o arquivo existe PARA QUEM CLONAR?" —
# e quem responde isso é o git, não o motor. Por isso mora no runner.
$projeto = Join-Path $raiz "project.godot"
$faltando = @()
foreach ($linha in [IO.File]::ReadAllLines($projeto, $semBom)) {
	if ($linha -notmatch '^\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*"\*?res://(.+)"\s*$') { continue }
	$relativo = $Matches[1]
	if ($relativo -notmatch '\.(gd|tscn)$') { continue }
	$disco = Join-Path $raiz $relativo
	if (-not (Test-Path $disco)) {
		$faltando += "$relativo (nao existe no disco)"
		continue
	}
	# `ls-files` SEM `--error-unmatch`, de propósito: aquele reclama no STDERR
	# quando o caminho não é conhecido, e redirecionar stderr de um .exe no
	# PowerShell 5.1 embrulha a linha num ErrorRecord que, com
	# `ErrorActionPreference = Stop`, derruba o script inteiro. É a armadilha
	# que o cabeçalho do runner do 2D já descreve, e eu pisei nela aqui.
	#
	# Assim ele sai com 0 nos dois casos e responde pelo STDOUT: o caminho,
	# se é versionado; nada, se não é.
	$conhecido = & git -C $raiz ls-files -- $relativo
	if ([string]::IsNullOrWhiteSpace(($conhecido -join ""))) {
		$faltando += "$relativo (existe aqui, mas nao esta versionado)"
	}
}
if ($faltando.Count -gt 0) {
	Write-Host "PRE-VOO REPROVADO: autoload registrado sem arquivo versionado"
	foreach ($f in $faltando) { Write-Host ("         " + $f) }
	Write-Host "quem clonar esta branch pega um projeto que nao abre."
	Pop-Location
	exit 1
}

# O Godot pode terminar uma importacao com 0 mesmo recebendo ponteiros LFS.
# Confira os binarios antes de abrir a engine, para um clone sem assets
# reprovar com uma instrucao util em vez de dezenas de recursos quebrados.
$ponteiros = @()
foreach ($arquivo in @(git ls-files -- assets | Where-Object { $_ -match '\.(glb|fbx|wav)$' })) {
	$caminho = Join-Path $raiz $arquivo
	if (-not (Test-Path -LiteralPath $caminho)) { continue }
	$fluxo = [IO.File]::OpenRead($caminho)
	try {
		$cabeca = New-Object byte[] 7
		$lidos = $fluxo.Read($cabeca, 0, $cabeca.Length)
		if ($lidos -eq 7 -and [Text.Encoding]::ASCII.GetString($cabeca) -eq 'version') {
			$ponteiros += $arquivo
		}
	} finally { $fluxo.Dispose() }
}
if ($ponteiros.Count -gt 0) {
	Write-Host "LFS PENDENTE: execute git lfs pull antes da bateria."
	foreach ($arquivo in $ponteiros) { Write-Host ("         " + $arquivo) }
	Remove-Item -LiteralPath $saida
	Pop-Location
	exit 1
}

$reprovados = 0
$appDataAnterior = $env:APPDATA
try {
	foreach ($nome in $quais) {
		# Cada teste recebe saves e preferencias descartaveis.
		$perfil = Join-Path $saida ("perfil-" + $nome)
		[IO.Directory]::CreateDirectory($perfil) | Out-Null
		$env:APPDATA = $perfil
		$log = Join-Path $saida "$nome.txt"
		$erros = "$log.err"
		$argumentosGodot = @("--path", ".", "--script", "res://tests/$nome.gd")
		if (-not $ComJanela) { $argumentosGodot = @("--headless") + $argumentosGodot }
		if ($Compatibility) { $argumentosGodot += @("--rendering-method", "gl_compatibility") }
		if ($QuadrosFixos) { $argumentosGodot += @("--fixed-fps", "60") }
		if ($ArgumentosTeste.Count -gt 0) {
			$argumentosGodot += @("--") + $ArgumentosTeste
		}

		$processo = Start-Process -FilePath $Godot -PassThru -WindowStyle Hidden `
			-WorkingDirectory $raiz `
			-ArgumentList $argumentosGodot `
			-RedirectStandardOutput $log -RedirectStandardError $erros

		$null = $processo.Handle

		$teto = if ($TETO_DO_PORTAO.ContainsKey($nome)) { $TETO_DO_PORTAO[$nome] } else { $TetoSegundos }
		$tempo = [Diagnostics.Stopwatch]::StartNew()
		$travou = $false
		while (-not $processo.WaitForExit(500)) {
			if ((Ler-Log $erros) -match "Parse Error|Compile Error|SCRIPT ERROR|Failed loading resource") {
				Encerrar-Teste $processo
				break
			}
			if ($tempo.Elapsed.TotalSeconds -ge $teto) {
				$travou = $true
				break
			}
		}
		if ($travou) {
			Encerrar-Teste $processo
			Write-Host ("TRAVOU   {0,-24} passou de {1}s sem terminar" -f $nome, $teto)
			$reprovados++
			continue
		}

		$processo.WaitForExit()
		$dito = Ler-Log $log
		$reclamado = Ler-Log $erros
		$texto = $dito + $reclamado
		$linhas = $dito -split "`n"

		$falhas = @($linhas | Where-Object { $_ -clike "FALHA:*" })
		if ($texto -match "Parse Error|Compile Error|SCRIPT ERROR|Failed loading resource") {
			Write-Host ("ERRO     {0,-24} erro de script ou recurso" -f $nome)
			Write-Host ("         " + ((($texto -split "`n") | Where-Object { $_ -match "Parse Error|Compile Error|SCRIPT ERROR|Failed loading resource" } | Select-Object -First 2) -join "`n         "))
			$reprovados++
		} elseif ($processo.ExitCode -ne 0 -or $falhas.Count -gt 0) {
			Write-Host ("FALHOU   {0,-24} saiu com {1}" -f $nome, $processo.ExitCode)
			foreach ($f in $falhas) { Write-Host ("         " + $f.Trim()) }
			if ($falhas.Count -eq 0) {
				$motivos = ($reclamado -split "`n") | Where-Object { $_ -cmatch "FALHA:|_FALHOU:" } | Select-Object -First 2
				foreach ($motivo in $motivos) { Write-Host ("         " + $motivo.Trim()) }
			}
			$reprovados++
		} else {
			# O RESUMO É A ÚLTIMA LINHA DO TESTE, não a última linha do processo.
			#
			# No vale, o Godot despeja no stdout as queixas de desligamento —
			# "34 RID allocations ... were leaked at exit", que todo teste que
			# monta a cena solta e que não são defeito de ninguém. A "última
			# linha" virava essa, e a bateria inteira reportava vazamento de RID
			# em vez de dizer o que cada portão tinha medido.
			#
			# Todo portão daqui termina com "<NOME>_OK: <o que passou>". É essa
			# linha que se procura; o resto é rede de segurança.
			$resumo = ($linhas | Where-Object { $_ -cmatch "_OK\b" } | Select-Object -Last 1)
			if (-not $resumo) {
				Write-Host ("INCOMPLETO {0,-24} terminou sem confirmar o fim do portao" -f $nome)
				$reprovados++
				continue
			}
			Write-Host ("ok       {0,-24} {1}" -f $nome, $resumo.Trim())
		}
	}
} finally {
	$env:APPDATA = $appDataAnterior
	$temporarios = [IO.Path]::GetFullPath($env:TEMP).TrimEnd("\") + "\"
	$alvo = [IO.Path]::GetFullPath($saida)
	if (-not $alvo.StartsWith($temporarios, [StringComparison]::OrdinalIgnoreCase)) {
		throw "A pasta de testes saiu do diretorio temporario."
	}
	# O cache de shaders pode ultrapassar MAX_PATH no Windows/PowerShell 5.1.
	# O alvo normalizado ja foi conferido dentro de TEMP acima.
	if ($reprovados -gt 0) {
		Write-Host ("logs e perfil isolado da falha: " + $alvo)
	} else {
		$limpou = $false
		for ($tentativa = 0; $tentativa -lt 3; $tentativa++) {
			try {
				Remove-Item -LiteralPath ("\\?\" + $alvo) -Recurse -Force
				$limpou = $true
				break
			} catch {
				# O renderer pode demorar a soltar o cache depois de o console sair.
				Start-Sleep -Milliseconds 100
			}
		}
		if (-not $limpou) { Write-Host ("perfil temporario ainda em uso: " + $alvo) }
	}
	Pop-Location
}

# SEM ACENTO NAS LINHAS DE RESUMO, de propósito.
#
# O PowerShell 5.1 lê .ps1 sem BOM na página de código da máquina, e acento
# sai embaralhado no console. Pôr BOM aqui seria divergir do resto de
# `tools\`, que também não tem — e o resumo da bateria é justamente a linha
# que precisa ser legível.
Write-Host ""
if ($reprovados -gt 0) {
	Write-Host ("" + $reprovados + " portao(oes) do vale reprovado(s) de " + $quais.Count)
	Write-Host ("reguas fora da bateria (rode a mao): " + ($REGUAS -join ", "))
	exit 1
}
Write-Host ("os " + $quais.Count + " portoes do vale passaram")
Write-Host ("reguas fora da bateria (rode a mao): " + ($REGUAS -join ", "))
