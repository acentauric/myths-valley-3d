# RODAR OS PORTÕES DO VALE 3D: só os afetados, em paralelo, sem matar o que não é meu.
#
#   .\tools\prototipo_3d\testar.ps1                      # o que a mudança afeta (padrão)
#   .\tools\prototipo_3d\testar.ps1 -Explicar            # só diz o que rodaria e por quê
#   .\tools\prototipo_3d\testar.ps1 -Explicar -Detalhar -Teste casa   # de que a casa depende
#   .\tools\prototipo_3d\testar.ps1 -Explicar -Teste casa -Por scripts/prototipo_3d/world_builder.gd
#   .\tools\prototipo_3d\testar.ps1 -Teste composicao_vale,casa
#   .\tools\prototipo_3d\testar.ps1 -Tudo                # bateria inteira (antes de fechar build)
#   .\tools\prototipo_3d\testar.ps1 -Paralelo 4          # força o número de portões simultâneos
#
#
# COMO ELE DECIDE O QUE RODAR
#
# Cada portão (tests/*.gd) depende de um conjunto de arquivos: o próprio teste, o
# project.godot, os autoloads, e tudo o que esses arquivos alcançam por
# `res://...`, `uid://...` e `class_name` — scripts, cenas, dados, assets. O
# runner monta esse FECHO por análise de texto e tira dele uma IMPRESSÃO DIGITAL:
# o hash de conteúdo (blob do git) de cada arquivo do fecho.
#
# Um portão RODA só quando a impressão digital dele é nova, isto é, quando não é
#   (a) igual a uma que já ficou verde nesta máquina (cache em .godot/testar3d), nem
#   (b) igual à de `origin/main` (-Base), que é verde por regra: nada entra na main
#       sem este runner verde. Por indução, o que não mudou desde a main não reprova.
#
# Mexeu numa vírgula de doc: nenhum portão roda. Mexeu num script do vale: rodam os
# portões cujo fecho o contém, e só eles. Mudou o motor (outro executável do
# Godot): o cache local não vale e tudo o que mudou desde a base roda de novo.
#
# Referência montada em tempo de execução ("res://data/%s.json" % nome) entra como
# PREFIXO ("res://data/"): o portão passa a depender da pasta inteira. É
# conservador de propósito; erra rodando a mais, não a menos. O que nenhuma análise
# de texto pega (um caminho inteiro vindo de fora do projeto) é o motivo do -Tudo
# antes de fechar build.
#
# Os .import e .uid ficam fora da impressão digital: o editor os reescreve sozinho
# (detect_3d, reimportação) e cada reescrita faria portões rodarem à toa.
#
#
# O QUE CONTINUA VALENDO DO RUNNER ANTIGO
#
#     NUNCA MATAR PROCESSO DO GODOT POR NOME.
#
# `taskkill /F /IM Godot_v4.7.2-stable_win64.exe` mata por nome de imagem, e esse
# é o binário do EDITOR. Já fechou o editor aberto do outro lado da mesa no meio do
# trabalho, mais de uma vez, levando junto cena não salva. Aqui se mata só por PID,
# e só PID que este script levantou. Teto de tempo em vez de processo pendurado,
# `$processo.Handle` tocado antes de o processo morrer, stdout e stderr em
# arquivos separados, e `-clike` para "FALHA:" não casar com "Falhas: 0".

param(
	[string[]]$Teste = @(),
	[switch]$Tudo,
	[switch]$Explicar,
	# Com -Explicar: lista o fecho de cada portão analisado e todos os arquivos mudados nele.
	[switch]$Detalhar,
	# Com -Explicar: mostra a cadeia de referências que põe este arquivo no fecho.
	[string]$Por = "",
	[string]$Base = "origin/main",
	[int]$Paralelo = 0,
	[string]$Godot = "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe",
	# O vale monta o mundo inteiro antes de qualquer pergunta, e a cadeia das
	# missões ainda joga os nove passos. Quem passar disto está preso.
	[int]$TetoSegundos = 420,
	# Onde o Godot roda os portões. Só muda para testar o próprio runner numa cópia.
	[string]$Projeto = ""
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8
# Caminho com acento enviado ao git pelo pipe: o 5.1 manda ASCII por padrão.
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$ErrorActionPreference = "Stop"
$raiz = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot "..") "..")).Path
if ($Projeto -eq "") { $Projeto = $raiz }
Push-Location $raiz
$noWindows = ($PSVersionTable.PSEdition -eq "Desktop") -or $IsWindows
$semBom = New-Object System.Text.UTF8Encoding($false)
$relogioTotal = [Diagnostics.Stopwatch]::StartNew()

# `ordem_da_visita` é uma RÉGUA: mede quanto o jogador anda na ordem de hoje e
# imprime o número. Não há resposta certa. Portão que não pode reprovar não é
# portão, e deixá-lo na bateria ensina a ignorar a bateria.
$REGUAS = @("ordem_da_visita")

# O `agua_rasa` atravessa o bracinho de mar a pé, com 14000 + 16000 quadros de
# física: perto de 500 s de relógio. Cortar o teto faz o portão TRAVAR sem medir.
$TETO_DO_PORTAO = @{ "agua_rasa" = 700 }

function Ler-Log([string]$arquivo) {
	if (-not (Test-Path -LiteralPath $arquivo)) { return "" }
	$fluxo = [IO.File]::Open($arquivo, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
	$leitor = New-Object IO.StreamReader($fluxo, $semBom)
	try { return $leitor.ReadToEnd() } finally { $leitor.Dispose() }
}

function Hash-Texto([string]$texto) {
	$sha = [Security.Cryptography.SHA1]::Create()
	try {
		return ([BitConverter]::ToString($sha.ComputeHash($semBom.GetBytes($texto)))).Replace("-", "").ToLower()
	} finally { $sha.Dispose() }
}

function Git-Linhas([string[]]$argumentos) {
	# No 5.1, stderr de .exe vira ErrorRecord e, com Stop, derruba o script (a
	# armadilha do runner do 2D). Aqui o erro do git é resposta, não exceção.
	$antes = $ErrorActionPreference
	$ErrorActionPreference = "Continue"
	try { $saida = & git -c core.quotepath=false @argumentos 2>$null } finally { $ErrorActionPreference = $antes }
	if ($LASTEXITCODE -ne 0) { return $null }
	return @($saida)
}


# ---------------------------------------------------------------------------
# PRÉ-VOO: TODO AUTOLOAD REGISTRADO TEM DE ESTAR VERSIONADO.
#
# O `project.godot` já registrou `Mochila="*res://scripts/ui/mochila.gd"` com o
# arquivo só na máquina de quem rodou o sincronizador. Aqui tudo passava; quem
# clonasse pegava um autoload apontando para o nada, e o projeto INTEIRO não subia.
# Nenhum portão dentro do Godot pega isso: quem responde é o git, não o motor.
$projetoGodot = Join-Path $raiz "project.godot"
$linhasProjeto = [IO.File]::ReadAllLines($projetoGodot, $semBom)
$autoloads = @()
$secao = ""
$faltando = @()
foreach ($linha in $linhasProjeto) {
	if ($linha -match '^\s*\[(.+)\]\s*$') { $secao = $Matches[1]; continue }
	if ($secao -ne "autoload") { continue }
	if ($linha -notmatch '^\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*"\*?((res|uid)://[^"]+)"\s*$') { continue }
	$autoloads += $Matches[1]
	if ($Matches[2] -ne "res") { continue }
	$relativo = $Matches[1].Substring(6)
	if ($relativo -notmatch '\.(gd|tscn)$') { continue }
	if (-not (Test-Path (Join-Path $raiz $relativo))) { $faltando += "$relativo (nao existe no disco)"; continue }
	$conhecido = & git -C $raiz ls-files -- $relativo
	if ([string]::IsNullOrWhiteSpace(($conhecido -join ""))) { $faltando += "$relativo (existe aqui, mas nao esta versionado)" }
}
if ($faltando.Count -gt 0) {
	Write-Host "PRE-VOO REPROVADO: autoload registrado sem arquivo versionado"
	foreach ($f in $faltando) { Write-Host ("         " + $f) }
	Write-Host "quem clonar esta branch pega um projeto que nao abre."
	Pop-Location; exit 1
}

# O Godot pode terminar com 0 mesmo recebendo ponteiros LFS. Confira os binários
# antes de abrir a engine: clone sem assets reprova com instrução útil.
$ponteiros = @()
foreach ($arquivo in @(git ls-files -- assets | Where-Object { $_ -match '\.(glb|fbx|wav)$' })) {
	$caminho = Join-Path $raiz $arquivo
	if (-not (Test-Path -LiteralPath $caminho)) { continue }
	$fluxo = [IO.File]::OpenRead($caminho)
	try {
		$cabeca = New-Object byte[] 7
		$lidos = $fluxo.Read($cabeca, 0, $cabeca.Length)
		if ($lidos -eq 7 -and [Text.Encoding]::ASCII.GetString($cabeca) -eq 'version') { $ponteiros += $arquivo }
	} finally { $fluxo.Dispose() }
}
if ($ponteiros.Count -gt 0) {
	Write-Host "LFS PENDENTE: execute git lfs pull antes da bateria."
	foreach ($arquivo in $ponteiros) { Write-Host ("         " + $arquivo) }
	Pop-Location; exit 1
}
if (-not (Test-Path -LiteralPath $Godot)) {
	Write-Host "GODOT NAO ENCONTRADO: $Godot"
	Write-Host "         passe o executavel console com -Godot <caminho>"
	Pop-Location; exit 1
}


# ---------------------------------------------------------------------------
# O ESTADO DOS ARQUIVOS: hash de conteúdo de cada um, agora e na base.
#
# Arquivo limpo usa o blob do índice do git (custo zero); arquivo sujo ou novo é
# hasheado com `git hash-object`, o mesmo hash, então "voltei como estava" casa
# com o verde antigo. O project.godot entra sem as seções que só o editor lê.

$ignorarNaImpressao = '\.(import|uid)$'
function Hash-Projeto([string[]]$linhas) {
	$filtradas = New-Object Collections.Generic.List[string]
	$s = ""
	foreach ($l in $linhas) {
		if ($l -match '^\s*\[(.+)\]\s*$') { $s = $Matches[1] }
		if ($s -eq "editor_plugins" -or $s -eq "editor") { continue }
		$filtradas.Add($l.TrimEnd())
	}
	return Hash-Texto ($filtradas -join "`n")
}

$atual = @{}
foreach ($l in (Git-Linhas @("ls-files", "-s"))) {
	if ($l -match '^\d+ ([0-9a-f]+) \d\t(.+)$') { $atual[$Matches[2]] = $Matches[1] }
}
$sujos = New-Object Collections.Generic.List[string]
foreach ($l in (Git-Linhas @("status", "--porcelain=v1", "-uall", "--no-renames"))) {
	if ($l.Length -lt 4) { continue }
	$caminho = $l.Substring(3).Trim('"')
	if (Test-Path -LiteralPath (Join-Path $raiz $caminho) -PathType Leaf) { $sujos.Add($caminho) } else { $atual.Remove($caminho) }
}
if ($sujos.Count -gt 0) {
	$hashes = @($sujos | & git -c core.quotepath=false hash-object --stdin-paths)
	for ($i = 0; $i -lt $sujos.Count; $i++) { $atual[$sujos[$i]] = $hashes[$i] }
}
$atual["project.godot"] = Hash-Projeto $linhasProjeto

$naBase = $null
$baseDescrita = "sem base"
if ($Base -ne "" -and -not $Tudo) {
	$linhasBase = Git-Linhas @("ls-tree", "-r", "--full-tree", $Base)
	if ($null -ne $linhasBase) {
		$naBase = @{}
		foreach ($l in $linhasBase) {
			if ($l -match '^\d+ blob ([0-9a-f]+)\t(.+)$') { $naBase[$Matches[2]] = $Matches[1] }
		}
		$projetoBase = Git-Linhas @("show", "${Base}:project.godot")
		if ($null -ne $projetoBase) { $naBase["project.godot"] = Hash-Projeto $projetoBase }
		$baseDescrita = $Base + " (" + ((Git-Linhas @("rev-parse", "--short", $Base)) -join "") + ")"
	} else {
		Write-Host "aviso: base '$Base' nao existe; sem base, so o cache local evita reteste"
	}
}


# ---------------------------------------------------------------------------
# O GRAFO: quem cada arquivo alcança.

$textuais = '\.(gd|tscn|tres|json|gdshader|godot|cfg)$'
$porUid = @{}
$porClasse = @{}
foreach ($caminho in @($atual.Keys)) {
	if ($caminho -match '\.uid$') {
		$conteudo = (Ler-Log (Join-Path $raiz $caminho)).Trim()
		if ($conteudo -match '^uid://[a-z0-9]+$') { $porUid[$conteudo] = $caminho.Substring(0, $caminho.Length - 4) }
	} elseif ($caminho -match '\.import$') {
		if ((Ler-Log (Join-Path $raiz $caminho)) -match 'uid="(uid://[a-z0-9]+)"') { $porUid[$Matches[1]] = $caminho.Substring(0, $caminho.Length - 7) }
	}
}
$conteudos = @{}
foreach ($caminho in @($atual.Keys)) {
	if ($caminho -notmatch $textuais) { continue }
	if ($caminho -match '^(addons/godot_mcp/cache/|build/|\.assets-raw/)') { continue }
	# O project.godot é FOLHA: o hash dele conta, mas o que ele cita não. A cena
	# principal e os plugins do editor não sobem num `--script`; os autoloads sim, e
	# esses já entram como raiz de todo portão.
	if ($caminho -eq "project.godot") { continue }
	$texto = Ler-Log (Join-Path $raiz $caminho)
	$conteudos[$caminho] = $texto
	if ($caminho -match '\.(tscn|tres)$' -and $texto -match '^\[gd_\w+[^\]]*uid="(uid://[a-z0-9]+)"') { $porUid[$Matches[1]] = $caminho }
	if ($caminho -match '\.gd$' -and $texto -match '(?m)^class_name\s+([A-Za-z_]\w*)') { $porClasse[$Matches[1]] = $caminho }
}
$todos = @($atual.Keys | Sort-Object)
$regexClasses = $null
if ($porClasse.Count -gt 0) { $regexClasses = New-Object Text.RegularExpressions.Regex ('\b(' + (($porClasse.Keys | ForEach-Object { [Regex]::Escape($_) }) -join '|') + ')\b') }

$cachePrefixo = @{}
function Por-Prefixo([string]$prefixo) {
	if ($cachePrefixo.ContainsKey($prefixo)) { return $cachePrefixo[$prefixo] }
	$achados = @($todos | Where-Object { $_.StartsWith($prefixo) })
	$cachePrefixo[$prefixo] = $achados
	return $achados
}

$arestas = @{}
function Vizinhos([string]$caminho) {
	if ($arestas.ContainsKey($caminho)) { return $arestas[$caminho] }
	$saida = New-Object Collections.Generic.HashSet[string]
	if ($conteudos.ContainsKey($caminho)) {
		$texto = $conteudos[$caminho]
		foreach ($m in [Regex]::Matches($texto, 'res://[^"''\r\n\)\]\}<>|*?]*')) {
			$ref = $m.Value.Substring(6)
			$corte = $ref.IndexOfAny([char[]]@('%', '{', ' ', '+'))
			if ($corte -ge 0) { $ref = $ref.Substring(0, $corte) }
			$ultimo = $ref.Substring($ref.LastIndexOf('/') + 1)
			if ($ultimo.Contains('.') -and $corte -lt 0) {
				if ($atual.ContainsKey($ref)) { [void]$saida.Add($ref) }
			} elseif ($ref.Length -ge 4) {
				# Caminho montado em tempo de execução: vale a pasta (ou o prefixo) inteira.
				foreach ($p in (Por-Prefixo $ref)) { [void]$saida.Add($p) }
			}
		}
		foreach ($m in [Regex]::Matches($texto, 'uid://[a-z0-9]+')) {
			if ($porUid.ContainsKey($m.Value)) { [void]$saida.Add($porUid[$m.Value]) }
		}
		if ($caminho -match '\.gd$' -and $null -ne $regexClasses) {
			foreach ($m in $regexClasses.Matches($texto)) { [void]$saida.Add($porClasse[$m.Value]) }
		}
	}
	$arestas[$caminho] = $saida
	return $saida
}

function Fecho([string[]]$raizes) {
	$visto = New-Object Collections.Generic.HashSet[string]
	$fila = New-Object Collections.Generic.Queue[string]
	foreach ($r in $raizes) { if ($visto.Add($r)) { $fila.Enqueue($r) } }
	while ($fila.Count -gt 0) {
		foreach ($v in (Vizinhos $fila.Dequeue())) { if ($visto.Add($v)) { $fila.Enqueue($v) } }
	}
	return $visto
}

function Cadeia([string[]]$raizes, [string]$alvo) {
	$pai = @{}
	$fila = New-Object Collections.Generic.Queue[string]
	foreach ($r in $raizes) { if (-not $pai.ContainsKey($r)) { $pai[$r] = ""; $fila.Enqueue($r) } }
	while ($fila.Count -gt 0) {
		$c = $fila.Dequeue()
		if ($c -eq $alvo) { break }
		foreach ($v in (Vizinhos $c)) { if (-not $pai.ContainsKey($v)) { $pai[$v] = $c; $fila.Enqueue($v) } }
	}
	if (-not $pai.ContainsKey($alvo)) { return @() }
	$passos = @()
	$c = $alvo
	while ($c -ne "") { $passos = @($c) + $passos; $c = $pai[$c] }
	return $passos
}

$raizesComuns = @("project.godot")
foreach ($a in $autoloads) {
	if ($a.StartsWith("res://")) { $raizesComuns += $a.Substring(6) }
	elseif ($porUid.ContainsKey($a)) { $raizesComuns += $porUid[$a] }
}

$itemGodot = Get-Item -LiteralPath $Godot
$motor = $itemGodot.Name + ":" + $itemGodot.Length

function Impressao($fecho, $estado) {
	$linhas = New-Object Collections.Generic.List[string]
	foreach ($c in $fecho) {
		if ($c -match $ignorarNaImpressao) { continue }
		$h = "ausente"
		if ($estado.ContainsKey($c)) { $h = $estado[$c] }
		$linhas.Add($c + "=" + $h)
	}
	$linhas.Sort([StringComparer]::Ordinal)
	return Hash-Texto ($linhas -join "`n")
}


# ---------------------------------------------------------------------------
# O CACHE: impressões digitais que ficaram verdes nesta máquina, e quanto cada
# portão demora (para começar pelos mais longos).

$pastaCache = Join-Path $raiz ".godot/testar3d"
$arquivoCache = Join-Path $pastaCache "cache.json"
$cache = @{}
if (Test-Path -LiteralPath $arquivoCache) {
	try {
		$lido = (Ler-Log $arquivoCache) | ConvertFrom-Json
		if ($lido.motor -eq $motor) {
			foreach ($p in $lido.portoes.PSObject.Properties) {
				$cache[$p.Name] = @{ verdes = @($p.Value.verdes); duracao = [double]$p.Value.duracao }
			}
		} else {
			# Motor novo: os verdes não valem, mas as durações ainda servem de ordem.
			foreach ($p in $lido.portoes.PSObject.Properties) { $cache[$p.Name] = @{ verdes = @(); duracao = [double]$p.Value.duracao } }
		}
	} catch { $cache = @{} }
}


# ---------------------------------------------------------------------------
# A ESCOLHA.

$todosPortoes = @(Get-ChildItem (Join-Path $raiz "tests") -Filter "*.gd" | Sort-Object Name | ForEach-Object { $_.BaseName } | Where-Object { $REGUAS -notcontains $_ })
$pedidos = @()
foreach ($t in $Teste) { foreach ($parte in ($t -split ',')) { if ($parte.Trim() -ne "") { $pedidos += ($parte.Trim() -replace '\.gd$', '') } } }
foreach ($p in $pedidos) {
	if (-not (Test-Path (Join-Path $raiz "tests/$p.gd"))) { Write-Host "portao inexistente: $p"; Pop-Location; exit 1 }
}

$fila = @()
$reaproveitados = 0
$porBase = 0
$porCache = 0
$motivos = @{}
$impressoes = @{}
$analisados = $todosPortoes
if ($pedidos.Count -gt 0) { $analisados = $pedidos }
foreach ($nome in $analisados) {
	$fecho = Fecho ($raizesComuns + @("tests/$nome.gd"))
	$impressao = Impressao $fecho $atual
	$impressoes[$nome] = $impressao
	if ($Detalhar) {
		$pastas = @{}
		foreach ($c in $fecho) { $d = ($c -split '/')[0..([Math]::Min(2, ($c -split '/').Count - 2))] -join '/'; if (-not $pastas.ContainsKey($d)) { $pastas[$d] = 0 }; $pastas[$d]++ }
		Write-Host ("fecho de " + $nome + ": " + $fecho.Count + " arquivos")
		foreach ($d in ($pastas.Keys | Sort-Object { -$pastas[$_] } | Select-Object -First 12)) { Write-Host ("    {0,5}  {1}" -f $pastas[$d], $d) }
	}
	if ($Por -ne "") {
		$passos = Cadeia ($raizesComuns + @("tests/$nome.gd")) $Por
		if ($passos.Count -eq 0) { Write-Host ($nome + ": " + $Por + " nao esta no fecho") }
		else { Write-Host ($nome + ": " + ($passos -join "`n    -> ")) }
	}
	if ($Tudo -or ($pedidos.Count -gt 0 -and -not $Explicar)) { $fila += $nome; $motivos[$nome] = "pedido"; continue }
	if ($cache.ContainsKey($nome) -and ($cache[$nome].verdes -contains $impressao)) { $reaproveitados++; $porCache++; continue }
	if ($null -ne $naBase -and (Impressao $fecho $naBase) -eq $impressao) { $reaproveitados++; $porBase++; continue }
	$fila += $nome
	$mudados = @()
	foreach ($c in $fecho) {
		if ($c -match $ignorarNaImpressao) { continue }
		$antes = $null
		if ($null -ne $naBase -and $naBase.ContainsKey($c)) { $antes = $naBase[$c] }
		$agora = $null
		if ($atual.ContainsKey($c)) { $agora = $atual[$c] }
		if ($null -ne $naBase -and $antes -ne $agora) { $mudados += $c }
	}
	if ($mudados.Count -gt 0) {
		$texto = ($mudados | Select-Object -First 2) -join ", "
		if ($Detalhar) { $texto = $mudados -join ", " }
		elseif ($mudados.Count -gt 2) { $texto += " (+" + ($mudados.Count - 2) + ")" }
		$motivos[$nome] = "mudou: " + $texto
	} elseif ($null -eq $naBase) { $motivos[$nome] = "sem verde registrado" }
	else { $motivos[$nome] = "sem verde com este motor" }
}

# Os mais longos primeiro: o paralelo termina junto em vez de esperar um retardatário.
$fila = @($fila | Sort-Object @{ Expression = { if ($cache.ContainsKey($_)) { $cache[$_].duracao } else { 90 } }; Descending = $true }, @{ Expression = { $_ } })

if ($Paralelo -le 0) {
	$nucleos = [Environment]::ProcessorCount
	$livreGB = 4.0
	try {
		if ($noWindows) { $livreGB = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB }
		elseif (Test-Path /proc/meminfo) { $livreGB = [double](((Get-Content /proc/meminfo | Where-Object { $_ -match '^MemAvailable' }) -split '\s+')[1]) / 1MB }
	} catch { }
	# Um portão que monta o vale chega a ~0,5 GB; 0,8 GB de folga por portão, e
	# 1,5 GB reservados para o editor e o resto da máquina.
	$porMemoria = [Math]::Floor(($livreGB - 1.5) / 0.8)
	$Paralelo = [Math]::Max(1, [Math]::Min([Math]::Min($nucleos - 1, $porMemoria), 12))
	$explicacaoParalelo = "$Paralelo em paralelo ($nucleos nucleos, " + [Math]::Round($livreGB, 1) + " GB livres)"
} else { $explicacaoParalelo = "$Paralelo em paralelo (pedido)" }

Write-Host ("portoes: " + $analisados.Count + " analisados, " + $fila.Count + " a rodar, " + $reaproveitados + " reaproveitados (" + $porCache + " verdes no cache, " + $porBase + " iguais a " + $baseDescrita + ")")
# Agrupado por motivo: 60 portões pela mesma mudança são uma linha, não 60.
$grupos = [ordered]@{}
foreach ($nome in ($fila | Sort-Object)) {
	$m = $motivos[$nome]
	if (-not $grupos.Contains($m)) { $grupos[$m] = New-Object Collections.Generic.List[string] }
	$grupos[$m].Add($nome)
}
foreach ($m in $grupos.Keys) {
	Write-Host ("  " + $grupos[$m].Count + " por " + $m + ":")
	Write-Host ("      " + ($grupos[$m] -join ", "))
}
if ($Explicar) { Pop-Location; exit 0 }
if ($fila.Count -eq 0) {
	Write-Host ""
	Write-Host "nada a testar: a mudanca nao alcanca nenhum portao"
	Pop-Location; exit 0
}
Write-Host ("rodando " + $explicacaoParalelo)
Write-Host ""


# ---------------------------------------------------------------------------
# A EXECUÇÃO.

$saida = Join-Path ([IO.Path]::GetTempPath()) ("testar3d-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $saida | Out-Null
$errosFatais = "Parse Error|Compile Error|SCRIPT ERROR|Failed loading resource"

function Encerrar-Teste($processo) {
	if ($processo.HasExited) { return }
	try {
		if ($noWindows) { & taskkill /F /T /PID $processo.Id 2>&1 | Out-Null } else { Stop-Process -Id $processo.Id -Force }
	} catch {
		# quit(1) pode encerrar entre a leitura do erro e o taskkill.
		if (-not $processo.HasExited) { throw }
	}
	$processo.WaitForExit(5000) | Out-Null
}

function Iniciar-Portao([string]$nome) {
	$perfil = Join-Path $saida ("perfil-" + $nome)
	[IO.Directory]::CreateDirectory($perfil) | Out-Null
	$log = Join-Path $saida "$nome.txt"
	# Cada portão recebe saves e preferências descartáveis (o filho herda o
	# ambiente no momento em que nasce, então trocar aqui não vaza para os outros).
	$anterior = @($env:APPDATA, $env:XDG_DATA_HOME, $env:XDG_CONFIG_HOME)
	$env:APPDATA = $perfil; $env:XDG_DATA_HOME = $perfil; $env:XDG_CONFIG_HOME = $perfil
	try {
		$argumentos = @{
			FilePath = $Godot; PassThru = $true; WorkingDirectory = $Projeto
			ArgumentList = @("--headless", "--path", $Projeto, "--script", "res://tests/$nome.gd")
			RedirectStandardOutput = $log; RedirectStandardError = "$log.err"
		}
		if ($noWindows) { $argumentos["WindowStyle"] = "Hidden" }
		$processo = Start-Process @argumentos
	} finally { $env:APPDATA = $anterior[0]; $env:XDG_DATA_HOME = $anterior[1]; $env:XDG_CONFIG_HOME = $anterior[2] }
	$null = $processo.Handle
	$teto = $TetoSegundos
	if ($TETO_DO_PORTAO.ContainsKey($nome)) { $teto = $TETO_DO_PORTAO[$nome] }
	return @{ nome = $nome; processo = $processo; log = $log; relogio = [Diagnostics.Stopwatch]::StartNew(); teto = $teto }
}

function Julgar($r) {
	$segundos = [Math]::Round($r.relogio.Elapsed.TotalSeconds)
	if ($r.travou) { return @{ ok = $false; linha = ("TRAVOU   {0,-26} {1,4}s  passou do teto de {2}s" -f $r.nome, $segundos, $r.teto) } }
	$dito = Ler-Log $r.log
	$reclamado = Ler-Log ($r.log + ".err")
	$texto = $dito + $reclamado
	$linhas = $dito -split "`n"
	$falhas = @($linhas | Where-Object { $_ -clike "FALHA:*" })
	if ($texto -match $errosFatais) {
		$motivo = (($texto -split "`n") | Where-Object { $_ -match $errosFatais } | Select-Object -First 2) -join "`n         "
		return @{ ok = $false; linha = ("NAO ABRE {0,-26} {1,4}s  o script nao compilou`n         {2}" -f $r.nome, $segundos, $motivo) }
	}
	if ($r.processo.ExitCode -ne 0 -or $falhas.Count -gt 0) {
		$extra = ""
		foreach ($f in $falhas) { $extra += "`n         " + $f.Trim() }
		return @{ ok = $false; linha = ("FALHOU   {0,-26} {1,4}s  saiu com {2}{3}" -f $r.nome, $segundos, $r.processo.ExitCode, $extra) }
	}
	# O RESUMO É A LINHA "<NOME>_OK:" DO TESTE, não a última do processo (o Godot
	# despeja vazamento de RID no desligamento, que não é defeito de ninguém).
	$resumo = ($linhas | Where-Object { $_ -cmatch "_OK:" } | Select-Object -Last 1)
	if (-not $resumo) { $resumo = ($linhas | Where-Object { $_.Trim() -ne "" -and $_ -notmatch '^(ERROR|WARNING|\s+at:|\s+\[)' } | Select-Object -Last 1) }
	if (-not $resumo) { $resumo = "" }
	$resumo = $resumo.Trim()
	if ($resumo.Length -gt 110) { $resumo = $resumo.Substring(0, 107) + "..." }
	return @{ ok = $true; linha = ("ok       {0,-26} {1,4}s  {2}" -f $r.nome, $segundos, $resumo) }
}

$pendentes = New-Object Collections.Generic.Queue[string]
foreach ($n in $fila) { $pendentes.Enqueue($n) }
$rodando = New-Object Collections.Generic.List[object]
$feitos = 0
$reprovados = New-Object Collections.Generic.List[string]
$ultimoSinal = [Diagnostics.Stopwatch]::StartNew()
try {
	while ($pendentes.Count -gt 0 -or $rodando.Count -gt 0) {
		while ($rodando.Count -lt $Paralelo -and $pendentes.Count -gt 0) { $rodando.Add((Iniciar-Portao $pendentes.Dequeue())) }
		Start-Sleep -Milliseconds 400
		foreach ($r in $rodando.ToArray()) {
			$acabou = $r.processo.HasExited
			if (-not $acabou -and (Ler-Log ($r.log + ".err")) -match $errosFatais) { Encerrar-Teste $r.processo; $acabou = $true }
			if (-not $acabou -and $r.relogio.Elapsed.TotalSeconds -ge $r.teto) { Encerrar-Teste $r.processo; $r.travou = $true; $acabou = $true }
			if (-not $acabou) { continue }
			$r.relogio.Stop()
			$r.processo.WaitForExit()
			[void]$rodando.Remove($r)
			$feitos++
			$veredito = Julgar $r
			Write-Host ("[{0,3}/{1}] {2}" -f $feitos, $fila.Count, $veredito.linha)
			$ultimoSinal.Restart()
			$entrada = @{ verdes = @(); duracao = $r.relogio.Elapsed.TotalSeconds }
			if ($cache.ContainsKey($r.nome)) { $entrada.verdes = @($cache[$r.nome].verdes) }
			if ($veredito.ok) {
				$entrada.verdes = @(@($impressoes[$r.nome]) + @($entrada.verdes | Where-Object { $_ -ne $impressoes[$r.nome] }) | Select-Object -First 8)
			} else { $reprovados.Add($r.nome) }
			$cache[$r.nome] = $entrada
		}
		if ($rodando.Count -gt 0 -and $ultimoSinal.Elapsed.TotalSeconds -ge 15) {
			$lista = ($rodando | ForEach-Object { $_.nome + " " + [Math]::Round($_.relogio.Elapsed.TotalSeconds) + "s" }) -join ", "
			Write-Host ("          ... rodando: " + $lista + "  (faltam " + $pendentes.Count + " na fila)")
			$ultimoSinal.Restart()
		}
	}
} finally {
	foreach ($r in $rodando.ToArray()) { Encerrar-Teste $r.processo }
	# O cache é gravado mesmo se a bateria for interrompida: o que ficou verde, ficou.
	[IO.Directory]::CreateDirectory($pastaCache) | Out-Null
	$gravar = @{ versao = 1; motor = $motor; portoes = @{} }
	foreach ($k in $cache.Keys) { $gravar.portoes[$k] = @{ verdes = @($cache[$k].verdes); duracao = [Math]::Round($cache[$k].duracao, 1) } }
	[IO.File]::WriteAllText($arquivoCache, ($gravar | ConvertTo-Json -Depth 5), $semBom)
	$temporarios = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
	$alvo = [IO.Path]::GetFullPath($saida)
	if ($alvo.StartsWith($temporarios, [StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $alvo -Recurse -Force -ErrorAction SilentlyContinue }
	Pop-Location
}

# SEM ACENTO NAS LINHAS DE RESUMO, de propósito: o PowerShell 5.1 lê .ps1 sem BOM
# na página de código da máquina, e acento sai embaralhado no console.
Write-Host ""
$minutos = [Math]::Round($relogioTotal.Elapsed.TotalMinutes, 1)
if ($reprovados.Count -gt 0) {
	Write-Host ("" + $reprovados.Count + " portao(oes) reprovado(s) de " + $fila.Count + " rodados em " + $minutos + " min: " + ($reprovados -join ", "))
	exit 1
}
Write-Host ("os " + $fila.Count + " portoes rodados passaram em " + $minutos + " min (" + $reaproveitados + " reaproveitados)")
Write-Host ("reguas fora da bateria (rode a mao): " + ($REGUAS -join ", "))
