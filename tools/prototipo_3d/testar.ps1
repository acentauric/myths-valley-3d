# RODAR OS PORTÕES DO VALE 3D: só os afetados, uma vez por lote, em paralelo, sem matar o que não é meu.
#
#   .\tools\prototipo_3d\testar.ps1                      # o que mudou desde o último verde (padrão)
#   .\tools\prototipo_3d\testar.ps1 -Push                # antes do git push: tudo o que a branch afeta
#   .\tools\prototipo_3d\testar.ps1 -Explicar            # só diz o que rodaria e por quê
#   .\tools\prototipo_3d\testar.ps1 -Explicar -Detalhar -Teste casa   # de que a casa depende
#   .\tools\prototipo_3d\testar.ps1 -Explicar -Teste casa -Por scripts/prototipo_3d/world_builder.gd
#   .\tools\prototipo_3d\testar.ps1 -Teste composicao_vale,casa
#   .\tools\prototipo_3d\testar.ps1 -Tudo                # bateria inteira (antes de fechar build)
#   .\tools\prototipo_3d\testar.ps1 -Paralelo 4          # força o número de portões simultâneos
#   .\tools\prototipo_3d\testar.ps1 -Base HEAD~5         # compara só com este commit
#   .\tools\prototipo_3d\testar_analise_teste.ps1        # os testes do próprio runner (sem Godot)
#
#
# O FLUXO: COMMITE À VONTADE, TESTE POR LOTE, E O LOTE INTEIRO ANTES DO PUSH
#
# Não se roda isto a cada commit. Faça os commits do lote (uma issue, uma tarde)
# e rode o runner uma vez no fim: a base padrão é o ÚLTIMO VERDE DESTA MÁQUINA,
# então uma rodada cobre todos os commits desde ele. Antes de `git push`, rode
# com -Push: a base passa a ser só a saída da origin/main, a árvore tem de estar
# limpa, e o que a branch inteira afeta tem de estar verde (rodado agora ou já
# verde no cache com o mesmo conteúdo).
#
#
# COMO ELE DECIDE O QUE RODAR
#
# Cada portão (tests/*.gd) depende de um conjunto de arquivos: o próprio teste, o
# project.godot, os autoloads, e tudo o que esses arquivos alcançam por
# `res://...`, `uid://...` e `class_name` — scripts, cenas, dados, assets. O
# runner monta esse FECHO por análise de texto e tira dele uma IMPRESSÃO DIGITAL:
# o hash do conteúdo de cada arquivo do fecho. A análise mora em
# testar_analise.cs (o PowerShell levava um minuto só para montar os fechos).
#
# A impressão é SEMÂNTICA: o .gd entra sem comentário, sem linha em branco e sem
# espaço no fim (o '#' dentro de string fica; o recuo fica, é sintaxe), o .json
# sem espaço fora das strings (a ordem das chaves fica: o Dictionary do Godot
# itera nela), e .md e docs/ não entram. Comentário e formatação não rodam
# portão nenhum. O portão que lê código como texto (FileAccess num .gd, ou
# `source_code`, nas falsificações) é TEXTUAL: para ele vale o conteúdo cru.
#
# Um portão RODA só quando a impressão digital dele é nova, isto é, quando não é
#   (a) igual a uma que já ficou verde nesta máquina (cache em .godot/testar3d), nem
#   (b) igual à de uma BASE verde. Sem -Base, as bases são duas:
#       - o último commit em que esta máquina viu o conjunto analisado inteiro
#         verde (.godot/testar3d/verde.json, gravado por uma rodada verde com a
#         árvore limpa e o mesmo executável do Godot);
#       - o merge-base com a origin/main, verde por regra: nada entra na main sem
#         este runner verde. Por indução, o que não mudou desde ela não reprova.
#       Com a origin/main à frente da branch, compará-la direto contaria como
#       "mudança minha" tudo o que a equipe enviou; o merge-base não conta.
#
# Mexeu numa vírgula de doc ou num comentário: nenhum portão roda. Mexeu num
# script do vale: rodam os portões cujo fecho o contém, e só eles. Mudou o motor
# (outro executável do Godot): o cache local e o último verde não valem, e tudo o
# que mudou desde a origin/main roda de novo.
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
# POR QUE MUDAR UMA FUNÇÃO DE AUTOLOAD AINDA RODA QUASE TUDO
#
# Os 40 autoloads são raiz de todo portão, e a unidade da impressão é o arquivo.
# Recortar por função (rodar só os portões cujo fecho cita a função mudada, ou
# quem a chama) foi medido em 08/10/2026 e recusado:
#   - o ganho é pequeno: das 27 funções do tela.gd, 17 são citadas em 169 a 216
#     dos 216 fechos, e as outras são chamadas de dentro delas (do _ready, do
#     _aplicar, de sinais); no missoes.gd a mediana é 216. O recorte pouparia no
#     máximo um quinto dos portões de uma mudança no tela.gd;
#   - erro de compilação em qualquer função derruba o autoload e, com ele, todo
#     portão: o recorte deixaria esse erro passar quando nenhum portão cita a
#     função, e a origin/main herdaria um verde falso;
#   - o GDScript chama por nome montado em tempo de execução (call, Callable,
#     sinais ligados em .tscn, dados que nomeiam ações), e citação por texto não
#     prova quem executa o quê.
# O que resolve o custo é o lote: dez commits no tela.gd custam uma rodada.
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
	# Sem -Base: o último verde desta máquina e o merge-base com a origin/main.
	# Com -Base <commit>: só ele (vazio: nenhuma base, só o cache).
	[string]$Base = "",
	# Antes do git push: só a origin/main como base, árvore limpa, verde gravado.
	[switch]$Push,
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
$baseExplicita = $PSBoundParameters.ContainsKey("Base")

# `ordem_da_visita` é uma RÉGUA: mede quanto o jogador anda na ordem de hoje e
# imprime o número. Não há resposta certa. Portão que não pode reprovar não é
# portão, e deixá-lo na bateria ensina a ignorar a bateria.
$REGUAS = @("ordem_da_visita")

# O `agua_rasa` atravessa o bracinho de mar a pé, com 14000 + 16000 quadros de
# física: perto de 500 s de relógio. Cortar o teto faz o portão TRAVAR sem medir.
#
# O `missoes_do_comeco_ao_fim` joga as 22 filas, do desembarque à fazenda, com os controles
# do jogador (andar atrás do Pedro, cortar árvore, E, J, dormir, lutar): o jogo anda perto de
# 1 segundo de jogo por segundo de relógio e a partida inteira passa de uma hora de jogo (de uma
# hora e meia a duas, medido, com a máquina livre) — e a bateria cheia a deixa mais lenta: com o
# quadro em 130 ms o jogo anda a 0,4 do relógio. O teto é de quatro horas: o portão se mata sozinho
# no primeiro passo que não fecha (ver `tests/missoes_do_comeco_ao_fim.gd`), e o teto só pega o
# que trava de verdade.
$TETO_DO_PORTAO = @{ "agua_rasa" = 700; "missoes_do_comeco_ao_fim" = 14400 }

# OS PESADOS SÓ ENTRAM NA BATERIA COMPLETA (-Tudo) ou pedidos pelo nome (-Teste). A impressão digital
# deles abrange o jogo inteiro (`res://data/` por prefixo, todos os scripts do vale): rodariam a cada
# mudança, e meia hora por commit ensina a pular o runner. Antes de fechar build, -Tudo os roda.
$SO_NO_TUDO = @("missoes_do_comeco_ao_fim")

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

# A primeira linha da resposta do git, ou $null. (Função devolve array de um item
# como o item: `(Git-Linhas ...)[0]` de um hash só daria o primeiro caractere.)
function Git-Linha([string[]]$argumentos) {
	$linhas = Git-Linhas $argumentos
	if ($null -eq $linhas) { return $null }
	foreach ($l in $linhas) { if ("$l" -ne "") { return [string]$l } }
	return $null
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
$itemGodot = Get-Item -LiteralPath $Godot
$motor = $itemGodot.Name + ":" + $itemGodot.Length


# ---------------------------------------------------------------------------
# A ANÁLISE EM C#: compilada uma vez por versão da fonte, guardada no cache.

$pastaCache = Join-Path $raiz ".godot/testar3d"
[IO.Directory]::CreateDirectory($pastaCache) | Out-Null
$fonteAnalise = Join-Path $PSScriptRoot "testar_analise.cs"
$assinatura = (Hash-Texto ([IO.File]::ReadAllText($fonteAnalise, $semBom) + $PSVersionTable.PSEdition + $PSVersionTable.PSVersion)).Substring(0, 12)
$dllAnalise = Join-Path $pastaCache ("analise-" + $assinatura + ".dll")
if (-not (Test-Path -LiteralPath $dllAnalise)) {
	# Compila num nome só deste processo e renomeia: duas rodadas ao mesmo tempo
	# não leem DLL pela metade.
	$temporaria = Join-Path $pastaCache ("analise-" + $assinatura + "-" + $PID + ".dll")
	Add-Type -Path $fonteAnalise -OutputAssembly $temporaria -OutputType Library
	try { Move-Item -LiteralPath $temporaria -Destination $dllAnalise -ErrorAction Stop } catch { $dllAnalise = $temporaria }
	foreach ($velha in @(Get-ChildItem -LiteralPath $pastaCache -Filter "analise-*.dll")) {
		if ($velha.FullName -ne $dllAnalise) { try { Remove-Item -LiteralPath $velha.FullName -Force -ErrorAction Stop } catch { } }
	}
}
Add-Type -Path $dllAnalise


# ---------------------------------------------------------------------------
# O ESTADO DOS ARQUIVOS: hash de conteúdo de cada um, agora e nas bases.
#
# Arquivo limpo usa o blob do índice do git (custo zero); arquivo sujo ou novo é
# hasheado com `git hash-object`, o mesmo hash, então "voltei como estava" casa
# com o verde antigo. O project.godot entra sem as seções que só o editor lê.

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

function Novo-Estado {
	return , (New-Object 'Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase))
}

$atual = Novo-Estado
foreach ($l in (Git-Linhas @("ls-files", "-s"))) {
	if ($l -match '^\d+ ([0-9a-f]+) \d\t(.+)$') { $atual[$Matches[2]] = $Matches[1] }
}
$sujos = New-Object Collections.Generic.List[string]
# A textura que a importação extrai de um .glb (<modelo>_*.png/.jpg ao lado
# dele, e o .import dela) não é versionada: é saída da importação, como o .import,
# e fica fora do estado. Se contasse, cada importação mudaria o fecho de todo
# portão que cita a pasta dos modelos.
$modelosPorPasta = @{}
foreach ($c in $atual.Keys) {
	if ($c -notmatch '^(.*/)?([^/]+)\.(glb|gltf)$') { continue }
	$pasta = $Matches[1]
	if ($null -eq $pasta) { $pasta = "" }
	if (-not $modelosPorPasta.ContainsKey($pasta)) { $modelosPorPasta[$pasta] = New-Object Collections.Generic.List[string] }
	$modelosPorPasta[$pasta].Add($Matches[2] + "_")
}
function Extraida-Da-Importacao([string]$caminho) {
	if ($caminho -notmatch '^(.*/)?([^/]+)\.(png|jpe?g|webp)(\.import)?$') { return $false }
	$pasta = $Matches[1]
	if ($null -eq $pasta) { $pasta = "" }
	if (-not $modelosPorPasta.ContainsKey($pasta)) { return $false }
	foreach ($prefixo in $modelosPorPasta[$pasta]) { if ($Matches[2].StartsWith($prefixo)) { return $true } }
	return $false
}
foreach ($l in (Git-Linhas @("status", "--porcelain=v1", "-uall", "--no-renames"))) {
	if ($l.Length -lt 4) { continue }
	$caminho = $l.Substring(3).Trim('"')
	if ($l.StartsWith("??") -and (Extraida-Da-Importacao $caminho)) { continue }
	if (Test-Path -LiteralPath (Join-Path $raiz $caminho) -PathType Leaf) { $sujos.Add($caminho) } else { [void]$atual.Remove($caminho) }
}
if ($sujos.Count -gt 0) {
	# Os caminhos vão como ARGUMENTOS, e não pelo pipe para o `--stdin-paths`: no
	# Windows PowerShell 5.1 o pipe para programa nativo põe um BOM na frente do
	# primeiro caminho, e o git procurava "﻿AGENTS.md" e parava o runner com
	# qualquer arquivo modificado. Em lotes, para a linha de comando caber.
	$hashes = New-Object Collections.Generic.List[string]
	for ($i = 0; $i -lt $sujos.Count; $i += 100) {
		$lote = @($sujos.GetRange($i, [Math]::Min(100, $sujos.Count - $i)))
		foreach ($h in @(& git -c core.quotepath=false hash-object -- $lote)) { $hashes.Add([string]$h) }
	}
	for ($i = 0; $i -lt $sujos.Count; $i++) { $atual[$sujos[$i]] = $hashes[$i] }
}
$atual["project.godot"] = Hash-Projeto $linhasProjeto
# Mudança fora de commit que conta para algum portão (doc, .import e .uid não contam).
$sujosQueContam = @($sujos | Where-Object { -not [Testar3D.Grafo]::ForaDaImpressao($_) })

function Estado-Do-Commit([string]$sha) {
	$linhasBase = Git-Linhas @("ls-tree", "-r", "--full-tree", $sha)
	if ($null -eq $linhasBase) { return $null }
	$estado = Novo-Estado
	foreach ($l in $linhasBase) {
		if ($l -match '^\d+ blob ([0-9a-f]+)\t(.+)$') { $estado[$Matches[2]] = $Matches[1] }
	}
	$projetoBase = Git-Linhas @("show", "${sha}:project.godot")
	if ($null -ne $projetoBase) { $estado["project.godot"] = Hash-Projeto $projetoBase }
	return , $estado
}

# AS BASES: commits cujo conteúdo é verde. Cada uma leva a lista dos portões que
# ela prova (o último verde só prova o que foi analisado naquela rodada).
$bases = New-Object Collections.Generic.List[object]
function Juntar-Base([string]$rev, [string]$papel, $portoes) {
	$sha = Git-Linha @("rev-parse", "--verify", "--quiet", ($rev + "^{commit}"))
	if ($null -eq $sha) { Write-Host "aviso: base '$rev' nao existe"; return }
	foreach ($b in $bases) { if ($b.sha -eq $sha) { return } }
	$estado = Estado-Do-Commit $sha
	if ($null -eq $estado) { return }
	$bases.Add(@{ sha = $sha; papel = $papel; estado = $estado; portoes = $portoes })
}

$arquivoVerde = Join-Path $pastaCache "verde.json"
if (-not $Tudo) {
	if ($baseExplicita) {
		if ($Base -ne "") { Juntar-Base $Base "pedida" $null }
	} else {
		$saidaDaMain = Git-Linha @("merge-base", "HEAD", "origin/main")
		$verde = $null
		if (-not $Push -and (Test-Path -LiteralPath $arquivoVerde)) {
			try { $verde = (Ler-Log $arquivoVerde) | ConvertFrom-Json } catch { $verde = $null }
		}
		if ($null -ne $verde -and $verde.motor -eq $motor -and $null -ne (Git-Linhas @("merge-base", "--is-ancestor", [string]$verde.commit, "HEAD"))) {
			# O verde mais velho que a saída da main não acrescenta nada: a main é verde por regra.
			$velho = ($null -ne $saidaDaMain -and [string]$verde.commit -ne $saidaDaMain -and $null -ne (Git-Linhas @("merge-base", "--is-ancestor", [string]$verde.commit, $saidaDaMain)))
			if (-not $velho) { Juntar-Base ([string]$verde.commit) "ultimo verde desta maquina" @($verde.portoes) }
		}
		if ($null -ne $saidaDaMain) { Juntar-Base $saidaDaMain "saida da origin/main" $null }
		else { Write-Host "aviso: sem origin/main; so o cache e o ultimo verde evitam reteste" }
	}
}
$basesDescritas = "sem base"
if ($bases.Count -gt 0) { $basesDescritas = (@($bases | ForEach-Object { $_.papel + " " + $_.sha.Substring(0, 7) }) -join ", ") }

if ($Push -and $sujosQueContam.Count -gt 0) {
	Write-Host ("PUSH: ha " + $sujosQueContam.Count + " arquivo(s) fora de commit (doc, .import e .uid nao contam): " + (($sujosQueContam | Select-Object -First 3) -join ", "))
	Write-Host "         o push envia commits: commite ou guarde (git stash) e rode de novo."
	if (-not $Explicar) { Pop-Location; exit 1 }
}


# ---------------------------------------------------------------------------
# O GRAFO E AS NORMAS: quem cada arquivo alcança, e o hash semântico de cada
# conteúdo (guardado em .godot/testar3d/normas-<versão da análise>.txt; cada
# blob é lido uma vez; mudou a normalização, as normas antigas não valem).

$grafo = [Testar3D.Grafo]::new($raiz, $atual)
$arquivoNormas = Join-Path $pastaCache ("normas-" + $assinatura + ".txt")
foreach ($velha in @(Get-ChildItem -LiteralPath $pastaCache -Filter "normas*.txt")) {
	if ($velha.FullName -ne $arquivoNormas) { try { Remove-Item -LiteralPath $velha.FullName -Force -ErrorAction Stop } catch { } }
}
$normas = [Testar3D.Normas]::new($arquivoNormas, $raiz, $grafo)
$normas.PrepararEstado($atual)
foreach ($b in $bases) { $normas.PrepararEstado($b.estado) }

# AS REFERÊNCIAS: o estado de agora (prova pelo cache antigo), o do HEAD quando há
# mudança fora de commit, e as bases. Uma referência só serve se dá a mesma
# impressão semântica que o estado de agora.
$referencias = New-Object Collections.Generic.List[object]
$referencias.Add(@{ estado = $atual; base = $false; portoes = $null })
if ($sujos.Count -gt 0) {
	$cabecaAgora = Git-Linha @("rev-parse", "--verify", "--quiet", "HEAD")
	if ($null -ne $cabecaAgora) {
		$estadoDoHead = Estado-Do-Commit $cabecaAgora
		if ($null -ne $estadoDoHead) {
			$normas.PrepararEstado($estadoDoHead)
			$referencias.Add(@{ estado = $estadoDoHead; base = $false; portoes = $null })
		}
	}
}
foreach ($b in $bases) { $referencias.Add(@{ estado = $b.estado; base = $true; portoes = $b.portoes }) }

$raizesComuns = @("project.godot")
foreach ($a in $autoloads) {
	if ($a.StartsWith("res://")) { $raizesComuns += $a.Substring(6) }
	elseif ($grafo.PorUid.ContainsKey($a)) { $raizesComuns += $grafo.PorUid[$a] }
}


# ---------------------------------------------------------------------------
# O CACHE: impressões digitais que ficaram verdes nesta máquina, e quanto cada
# portão demora (para começar pelos mais longos). `legado` guarda as impressões
# cruas do runner antigo: conteúdo igual ao cru é igual ao semântico, então um
# verde antigo ainda vale, e vira verde novo na primeira rodada que o encontra.

$arquivoCache = Join-Path $pastaCache "cache.json"
$cache = @{}
if (Test-Path -LiteralPath $arquivoCache) {
	try {
		$lido = (Ler-Log $arquivoCache) | ConvertFrom-Json
		$versaoLida = 1
		if ($null -ne $lido.versao) { $versaoLida = [int]$lido.versao }
		$mesmoMotor = ($lido.motor -eq $motor)
		foreach ($p in $lido.portoes.PSObject.Properties) {
			$entrada = @{ verdes = @(); legado = @(); duracao = [double]$p.Value.duracao }
			# Motor novo: os verdes não valem, mas as durações ainda servem de ordem.
			if ($mesmoMotor) {
				if ($versaoLida -ge 2) {
					$entrada.verdes = @($p.Value.verdes | Where-Object { $_ })
					$entrada.legado = @($p.Value.legado | Where-Object { $_ })
				} else { $entrada.legado = @($p.Value.verdes | Where-Object { $_ }) }
			}
			$cache[$p.Name] = $entrada
		}
	} catch { $cache = @{} }
}

function Gravar-Cache {
	[IO.Directory]::CreateDirectory($pastaCache) | Out-Null
	$gravar = @{ versao = 2; motor = $motor; portoes = @{} }
	foreach ($k in $cache.Keys) {
		$gravar.portoes[$k] = @{ verdes = @($cache[$k].verdes); legado = @($cache[$k].legado); duracao = [Math]::Round($cache[$k].duracao, 1) }
	}
	[IO.File]::WriteAllText($arquivoCache, ($gravar | ConvertTo-Json -Depth 5), $semBom)
	$normas.Gravar()
}

function Marcar-Verde([string]$nome, [string]$impressao) {
	if (-not $cache.ContainsKey($nome)) { $cache[$nome] = @{ verdes = @(); legado = @(); duracao = 90 } }
	$cache[$nome].verdes = @(@($impressao) + @($cache[$nome].verdes | Where-Object { $_ -ne $impressao }) | Select-Object -First 8)
}

# O último verde: só com a rodada inteira (nada pedido pelo nome), verde, e
# nada fora de commit que conte. É o que o próximo lote usa de base.
function Gravar-Verde {
	if ($pedidos.Count -gt 0 -or $sujosQueContam.Count -gt 0) { return }
	$cabeca = Git-Linha @("rev-parse", "HEAD")
	if ($null -eq $cabeca) { return }
	$registro = @{ commit = $cabeca; motor = $motor; portoes = @($analisados); quando = (Get-Date).ToString("s") }
	[IO.File]::WriteAllText($arquivoVerde, ($registro | ConvertTo-Json -Depth 3), $semBom)
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
$textuais = 0
$motivos = @{}
$impressoes = @{}
# Verdes provados sem rodar (base ou impressão antiga): entram no cache na rodada de verdade.
$provados = @{}
$analisados = $todosPortoes
if (-not $Tudo) { $analisados = @($todosPortoes | Where-Object { $SO_NO_TUDO -notcontains $_ }) }
if ($pedidos.Count -gt 0) { $analisados = $pedidos }
foreach ($nome in $analisados) {
	$fecho = $grafo.Fecho([string[]]($raizesComuns + @("tests/$nome.gd")))
	# O que o portão lê como texto (null: nada) vale cru na impressão dele.
	$textual = $grafo.EscopoTextual($fecho)
	if ($null -ne $textual) { $textuais++ }
	$impressao = $normas.Impressao($fecho, $atual, $textual)
	$impressoes[$nome] = $impressao
	if ($Detalhar) {
		$pastas = @{}
		foreach ($c in $fecho) { $d = ($c -split '/')[0..([Math]::Min(2, ($c -split '/').Count - 2))] -join '/'; if (-not $pastas.ContainsKey($d)) { $pastas[$d] = 0 }; $pastas[$d]++ }
		$tipo = ""
		if ($null -ne $textual) { $tipo = " (textual: le " + $textual.Count + " arquivo(s) como texto, e neles comentario conta)" }
		Write-Host ("fecho de " + $nome + ": " + $fecho.Count + " arquivos" + $tipo)
		foreach ($d in ($pastas.Keys | Sort-Object { -$pastas[$_] } | Select-Object -First 12)) { Write-Host ("    {0,5}  {1}" -f $pastas[$d], $d) }
	}
	if ($Por -ne "") {
		$passos = $grafo.Cadeia([string[]]($raizesComuns + @("tests/$nome.gd")), $Por)
		if ($passos.Count -eq 0) { Write-Host ($nome + ": " + $Por + " nao esta no fecho") }
		else { Write-Host ($nome + ": " + ($passos -join "`n    -> ")) }
	}
	if ($Tudo -or ($pedidos.Count -gt 0 -and -not $Explicar)) { $fila += $nome; $motivos[$nome] = "pedido"; continue }
	if ($cache.ContainsKey($nome) -and $cache[$nome].verdes -contains $impressao) { $reaproveitados++; $porCache++; continue }
	# Um estado de referência com a mesma impressão semântica prova o verde se é
	# base deste portão, ou se o cache antigo (cru) o viu verde: é assim que um
	# comentário novo por cima de um verde antigo não roda nada.
	$legado = @()
	if ($cache.ContainsKey($nome)) { $legado = $cache[$nome].legado }
	$prova = ""
	foreach ($r in $referencias) {
		if ($normas.Impressao($fecho, $r.estado, $textual) -ne $impressao) { continue }
		if ($r.base -and ($null -eq $r.portoes -or $r.portoes -contains $nome)) { $prova = "base"; break }
		if ($legado.Count -gt 0 -and $legado -contains [Testar3D.Grafo]::ImpressaoV1($fecho, $r.estado)) { $prova = "cache"; break }
	}
	if ($prova -eq "base") { $reaproveitados++; $porBase++; $provados[$nome] = $impressao; continue }
	if ($prova -eq "cache") { $reaproveitados++; $porCache++; $provados[$nome] = $impressao; continue }
	$fila += $nome
	# O motivo mostrado é a menor diferença para alguma referência: o HEAD, com
	# mudança fora de commit, ou a base mais próxima.
	$mudados = @()
	$comoNoHead = $false
	foreach ($r in $referencias) {
		if ([object]::ReferenceEquals($r.estado, $atual)) { continue }
		$estes = @($normas.Mudados($fecho, $r.estado, $atual, $textual))
		if ($estes.Count -eq 0) { $comoNoHead = $true; continue }
		if ($mudados.Count -eq 0 -or $estes.Count -lt $mudados.Count) { $mudados = $estes }
	}
	if ($mudados.Count -gt 0) {
		$texto = ($mudados | Select-Object -First 2) -join ", "
		if ($Detalhar) { $texto = $mudados -join ", " }
		elseif ($mudados.Count -gt 2) { $texto += " (+" + ($mudados.Count - 2) + ")" }
		$motivos[$nome] = "mudou: " + $texto
		# Igual ao HEAD no que conta, mas o HEAD nunca ficou verde aqui.
		if ($comoNoHead) { $motivos[$nome] = "sem verde do HEAD nesta maquina (desde a base mudou: " + $texto + ")" }
	} elseif ($bases.Count -eq 0) { $motivos[$nome] = "sem verde registrado" }
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
	# Outras baterias na mesma máquina (outros agentes, outras worktrees) disputam
	# os mesmos núcleos: cada portão delas é um `..._console` vivo. Com a máquina
	# cheia, 11 portões a mais faziam o vale montar em câmera lenta e 22 portões
	# TRAVAREM no teto de 420 s (medido em 08/10/2026). Só se conta; não se mexe neles.
	$outros = 0
	try { $outros = @(Get-Process -ErrorAction Stop | Where-Object { $_.ProcessName -like "Godot*console*" }).Count } catch { }
	$Paralelo = [Math]::Max(1, [Math]::Min([Math]::Min($nucleos - 1 - $outros, $porMemoria), 12))
	$explicacaoParalelo = "$Paralelo em paralelo ($nucleos nucleos, $outros portoes de outras baterias, " + [Math]::Round($livreGB, 1) + " GB livres)"
} else { $explicacaoParalelo = "$Paralelo em paralelo (pedido)" }

Write-Host ("bases: " + $basesDescritas)
Write-Host ("portoes: " + $analisados.Count + " analisados, " + $fila.Count + " a rodar, " + $reaproveitados + " reaproveitados (" + $porCache + " verdes no cache, " + $porBase + " iguais a uma base); " + $textuais + " textuais; analise em " + [Math]::Round($relogioTotal.Elapsed.TotalSeconds, 1) + " s")
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
if ($Explicar) { $normas.Gravar(); Pop-Location; exit 0 }
foreach ($nome in $provados.Keys) { Marcar-Verde $nome $provados[$nome] }
if ($fila.Count -eq 0) {
	Gravar-Cache
	Gravar-Verde
	Write-Host ""
	Write-Host "nada a testar: a mudanca nao alcanca nenhum portao"
	if ($Push) { Write-Host "PUSH OK: tudo o que a branch afeta esta verde" }
	Pop-Location; exit 0
}


# ---------------------------------------------------------------------------
# A IMPORTAÇÃO, UMA VEZ: num `--script` o Godot não importa nada, e recurso novo
# sem cache (ou class_name novo fora do cache de classes) reprovaria cada portão
# que o toca como "NAO ABRE". Pendente, importa antes da bateria. O cache que
# existe mas está quebrado (o .scn importado de um .glb cita a textura que a
# importação extraiu e que sumiu do disco; o md5 do .glb bate, e o Godot não o
# refaria) tem o cache apagado antes da importação (ver CachesQuebrados). O
# que ainda escapar aparece no log do portão como "Failed loading resource:
# res://.godot/imported/..." ou "Resource file not found": aí importa uma vez e
# roda de novo só esses portões.

$saida = Join-Path ([IO.Path]::GetTempPath()) ("testar3d-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $saida | Out-Null
# Uma importação depois da bateria, e só uma: o que reprovar de novo reprova.
$retentou = $false
# Recursos cujo cache importado está quebrado (o .scn cita textura extraída que não
# existe): o md5 bate, então o Godot não reimportaria. Apagar o cache deles (só
# dentro de .godot/imported) obriga a importação a refazê-los.
$refazer = New-Object 'Collections.Generic.HashSet[string]'
function Importar-Projeto([string]$motivo) {
	Write-Host ("importando (" + $motivo + ")...")
	$pastaImportados = [IO.Path]::GetFullPath((Join-Path $raiz ".godot/imported"))
	foreach ($origem in $refazer) {
		$descricao = Ler-Log (Join-Path $raiz ($origem + ".import"))
		foreach ($d in [regex]::Matches($descricao, '"res://(\.godot/imported/[^"]+)"')) {
			$destino = [IO.Path]::GetFullPath((Join-Path $raiz $d.Groups[1].Value))
			if (-not $destino.StartsWith($pastaImportados, [StringComparison]::OrdinalIgnoreCase)) { continue }
			Remove-Item -LiteralPath $destino -Force -ErrorAction SilentlyContinue
			Remove-Item -LiteralPath ($destino -replace '(-[0-9a-f]{32})\..*$', '$1.md5') -Force -ErrorAction SilentlyContinue
		}
	}
	if ($refazer.Count -gt 0) { Write-Host ("  refazendo o cache de " + $refazer.Count + " recurso(s), ex.: " + ((@($refazer) | Select-Object -First 3) -join ", ")) }
	$perfilImportacao = Join-Path $saida "perfil-importacao"
	[IO.Directory]::CreateDirectory($perfilImportacao) | Out-Null
	$anterior = @($env:APPDATA, $env:XDG_DATA_HOME, $env:XDG_CONFIG_HOME)
	$env:APPDATA = $perfilImportacao; $env:XDG_DATA_HOME = $perfilImportacao; $env:XDG_CONFIG_HOME = $perfilImportacao
	try {
		$argumentos = @{
			FilePath = $Godot; PassThru = $true; WorkingDirectory = $Projeto
			ArgumentList = @("--headless", "--path", ".", "--editor", "--import")
			RedirectStandardOutput = (Join-Path $saida "importacao.txt"); RedirectStandardError = (Join-Path $saida "importacao.err")
		}
		if ($noWindows) { $argumentos["WindowStyle"] = "Hidden" }
		$importacao = Start-Process @argumentos
	} finally { $env:APPDATA = $anterior[0]; $env:XDG_DATA_HOME = $anterior[1]; $env:XDG_CONFIG_HOME = $anterior[2] }
	$null = $importacao.Handle
	if (-not $importacao.WaitForExit(900000)) {
		# Só o PID que este script levantou, nunca por nome.
		if ($noWindows) { & taskkill /F /T /PID $importacao.Id 2>&1 | Out-Null } else { Stop-Process -Id $importacao.Id -Force }
		Write-Host "aviso: a importacao passou de 15 min e foi encerrada; os portoes rodam assim mesmo"
	}
	[Testar3D.Importacao]::Aceitar($raiz, [string[]]@($refazer))
	$refazer.Clear()
	$restantes = [Testar3D.Importacao]::Pendencias($raiz, $grafo)
	if ($restantes.Count -gt 0) { Write-Host ("aviso: " + $restantes.Count + " pendencia(s) seguem depois da importacao, ex.: " + (($restantes | Select-Object -First 3) -join ", ")) }
}
foreach ($q in [Testar3D.Importacao]::CachesQuebrados($raiz, $grafo)) { [void]$refazer.Add($q) }
$pendentes = [Testar3D.Importacao]::Pendencias($raiz, $grafo)
if ($pendentes.Count -gt 0) {
	Importar-Projeto ("" + $pendentes.Count + " pendencia(s) antes da bateria, ex.: " + (($pendentes | Select-Object -First 3) -join ", "))
}
Write-Host ("rodando " + $explicacaoParalelo)
Write-Host ""


# ---------------------------------------------------------------------------
# A EXECUÇÃO.

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
			# `--path .`, e não o caminho inteiro: o diretório de trabalho já é o
			# projeto, e no Windows PowerShell 5.1 o -ArgumentList não põe aspas em
			# argumento com espaço — "Mitys Valley 3D" chegava partido, e o Godot
			# saía com 1 antes de qualquer portão.
			ArgumentList = @("--headless", "--path", ".", "--script", "res://tests/$nome.gd")
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
		$daImportacao = $texto -match 'Failed loading resource: res://\.godot/imported/|Resource file not found: res://'
		# O recurso de origem que não carregou: o cache dele é refeito na importação.
		foreach ($m in [regex]::Matches($texto, 'Failed loading resource: res://([^\s]+?)\.?(
?
|$)')) {
			$origem = $m.Groups[1].Value
			if (-not $origem.StartsWith(".godot/") -and $atual.ContainsKey($origem + ".import")) { [void]$refazer.Add($origem) }
		}
		return @{ ok = $false; importacao = $daImportacao; linha = ("NAO ABRE {0,-26} {1,4}s  o script nao compilou`n         {2}" -f $r.nome, $segundos, $motivo) }
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

$aguardando = New-Object Collections.Generic.Queue[string]
foreach ($n in $fila) { $aguardando.Enqueue($n) }
$rodando = New-Object Collections.Generic.List[object]
$feitos = 0
$reprovados = New-Object Collections.Generic.List[string]
# Os que reprovaram por cache de importação: rodam de novo depois de uma importação.
$deNovo = New-Object Collections.Generic.List[string]
$ultimoSinal = [Diagnostics.Stopwatch]::StartNew()
try {
	while ($aguardando.Count -gt 0 -or $rodando.Count -gt 0) {
		while ($rodando.Count -lt $Paralelo -and $aguardando.Count -gt 0) { $rodando.Add((Iniciar-Portao $aguardando.Dequeue())) }
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
			if (-not $cache.ContainsKey($r.nome)) { $cache[$r.nome] = @{ verdes = @(); legado = @(); duracao = 90 } }
			$cache[$r.nome].duracao = $r.relogio.Elapsed.TotalSeconds
			if ($veredito.ok) { Marcar-Verde $r.nome $impressoes[$r.nome] }
			elseif ($veredito.importacao -and -not $retentou) { $deNovo.Add($r.nome) }
			else { $reprovados.Add($r.nome) }
		}
		if ($aguardando.Count -eq 0 -and $rodando.Count -eq 0 -and $deNovo.Count -gt 0) {
			$retentou = $true
			Importar-Projeto ("" + $deNovo.Count + " portao(oes) nao acharam recurso importado")
			Write-Host ("rodando de novo: " + ($deNovo -join ", "))
			foreach ($n in $deNovo) { $aguardando.Enqueue($n) }
			$feitos -= $deNovo.Count
			$deNovo.Clear()
		}
		if ($rodando.Count -gt 0 -and $ultimoSinal.Elapsed.TotalSeconds -ge 15) {
			$lista = ($rodando | ForEach-Object { $_.nome + " " + [Math]::Round($_.relogio.Elapsed.TotalSeconds) + "s" }) -join ", "
			Write-Host ("          ... rodando: " + $lista + "  (faltam " + $aguardando.Count + " na fila)")
			$ultimoSinal.Restart()
		}
	}
} finally {
	foreach ($r in $rodando.ToArray()) { Encerrar-Teste $r.processo }
	# O cache é gravado mesmo se a bateria for interrompida: o que ficou verde, ficou.
	Gravar-Cache
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
Push-Location $raiz
Gravar-Verde
Pop-Location
Write-Host ("os " + $fila.Count + " portoes rodados passaram em " + $minutos + " min (" + $reaproveitados + " reaproveitados)")
if ($Push) { Write-Host "PUSH OK: tudo o que a branch afeta esta verde" }
Write-Host ("reguas fora da bateria (rode a mao): " + ($REGUAS -join ", "))
Write-Host ("pesados que so rodam com -Tudo ou pelo nome (-Teste): " + ($SO_NO_TUDO -join ", "))
