# RODAR OS PORTÕES DO VALE 3D, com teto de tempo e sem matar nada que não seja meu.
#
#   .\prototipo_3d\tools\prototipo_3d\testar.ps1                 # a bateria inteira
#   .\prototipo_3d\tools\prototipo_3d\testar.ps1 -Teste cadeia_das_missoes
#
#
# POR QUE ESTE ARQUIVO EXISTE
#
# O `tools\comum\testar.ps1` roda os portões do jogo 2D: ele varre
# `tools\gdscript\testar_*.gd` e chama o Godot na RAIZ do repositório. Os do
# vale são outro projeto — moram em `prototipo_3d\tests\`, sem o prefixo
# `testar_`, e pedem `--path prototipo_3d`. Chamar um pelo outro não funciona.
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
# O resto é o mesmo do runner do 2D, pelas mesmas razões — que estão
# comentadas lá e não vou repetir: teto de tempo em vez de processo pendurado,
# `$processo.Handle` tocado antes de o processo morrer, stdout e stderr em
# arquivos separados, e `-clike` para "FALHA:" não casar com "Falhas: 0".

param(
	[string]$Teste = "",
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

# OS QUE NÃO SÃO PORTÃO.
#
# `ordem_da_visita` é uma RÉGUA: ele mede quanto o jogador anda na ordem de
# hoje e imprime o número. Não há resposta certa — o número é para ser lido e
# comparado depois de mexer na ordem das visitas. Portão que não pode reprovar
# não é portão, e deixá-lo na bateria ensina a ignorar a bateria.
$REGUAS = @("ordem_da_visita")

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

$reprovados = 0
try {
	foreach ($nome in $quais) {
		$log = Join-Path $saida "$nome.txt"
		$erros = "$log.err"

		$processo = Start-Process -FilePath $Godot -PassThru -NoNewWindow `
			-WorkingDirectory $raiz `
			-ArgumentList @("--headless", "--path", ".", "--script", "res://tests/$nome.gd") `
			-RedirectStandardOutput $log -RedirectStandardError $erros

		$null = $processo.Handle

		if (-not $processo.WaitForExit($TetoSegundos * 1000)) {
			& taskkill /F /T /PID $processo.Id 2>&1 | Out-Null
			$processo.WaitForExit(5000) | Out-Null
			Write-Host ("TRAVOU   {0,-24} passou de {1}s sem terminar" -f $nome, $TetoSegundos)
			$reprovados++
			continue
		}

		$dito = if (Test-Path $log) { [IO.File]::ReadAllText($log, $semBom) } else { "" }
		$reclamado = if (Test-Path $erros) { [IO.File]::ReadAllText($erros, $semBom) } else { "" }
		$texto = $dito + $reclamado
		$linhas = $dito -split "`n"

		$falhas = @($linhas | Where-Object { $_ -clike "FALHA:*" })
		if ($texto -match "Parse Error|Compile Error") {
			Write-Host ("NAO ABRE {0,-24} o script não compilou" -f $nome)
			Write-Host ("         " + ((($texto -split "`n") | Where-Object { $_ -match "Parse Error|Compile Error" } | Select-Object -First 2) -join "`n         "))
			$reprovados++
		} elseif ($processo.ExitCode -ne 0) {
			Write-Host ("FALHOU   {0,-24} saiu com {1}" -f $nome, $processo.ExitCode)
			foreach ($f in $falhas) { Write-Host ("         " + $f.Trim()) }
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
			$resumo = ($linhas | Where-Object { $_ -cmatch "_OK:" } | Select-Object -Last 1)
			if (-not $resumo) {
				$resumo = ($linhas |
					Where-Object { $_.Trim() -ne "" -and $_ -notmatch '^(ERROR|WARNING|\s+at:|\s+\[)' } |
					Select-Object -Last 1)
			}
			if (-not $resumo) { $resumo = "" }
			Write-Host ("ok       {0,-24} {1}" -f $nome, $resumo.Trim())
		}
	}
} finally {
	Remove-Item $saida -Recurse -Force
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
