# OS TESTES DA ANÁLISE DO testar.ps1 (sem Godot, em segundos).
#
#   .\tools\prototipo_3d\testar_analise_teste.ps1
#
# A impressão semântica só pode esquecer o que não muda o jogo. Cada caso aqui
# é um par de textos e o que se espera: IGUAIS (a mudança não pode rodar portão)
# ou DIFERENTES (tem de rodar). O segundo grupo é o que importa: é o que impede
# a normalização de engolir mudança de verdade.

$ErrorActionPreference = "Stop"
$fonte = Join-Path $PSScriptRoot "testar_analise.cs"
$dll = Join-Path ([IO.Path]::GetTempPath()) ("testar-analise-teste-" + $PID + ".dll")
Add-Type -Path $fonte -OutputAssembly $dll -OutputType Library
Add-Type -Path $dll

$falhas = 0
$casos = 0
function Conferir([string]$tipo, [string]$a, [string]$b, [bool]$iguais, [string]$nome) {
	$script:casos++
	if ($tipo -eq "gd") { $na = [Testar3D.Texto]::NormalizarGd($a); $nb = [Testar3D.Texto]::NormalizarGd($b) }
	else { $na = [Testar3D.Texto]::NormalizarJson($a); $nb = [Testar3D.Texto]::NormalizarJson($b) }
	if (($na -ceq $nb) -ne $iguais) {
		$script:falhas++
		$esperado = "IGUAIS"
		if (-not $iguais) { $esperado = "DIFERENTES" }
		Write-Host ("FALHA: " + $nome + " (esperava " + $esperado + ")")
		Write-Host ("       a: " + ($na -replace "`n", "\n"))
		Write-Host ("       b: " + ($nb -replace "`n", "\n"))
	}
}

$T = "`t"
$N = "`n"
$Q = '"'

# --- GDScript: o que NAO pode rodar portao ---
Conferir gd ("func f():" + $N + $T + "return 1") ("# novo comentario" + $N + "func f():" + $N + $T + "return 1 # e outro") $true "comentario novo"
Conferir gd ("func f():" + $N + $T + "return 1") ("func f():" + $N + $N + $T + "  " + $N + $T + "return 1   ") $true "linha em branco e espaco no fim"
Conferir gd ("func f():" + $N + $T + "return 1") ("func f():`r`n" + $T + "return 1`r`n") $true "CRLF"
Conferir gd ("## doc" + $N + "var x := 1") ("## outra doc" + $N + "var x := 1") $true "comentario de documentacao"
Conferir gd ("var s := " + $Q + "a" + $Q + " # x") ("var s := " + $Q + "a" + $Q) $true "comentario depois de string"
Conferir gd ("var s := 'it''s'") ("var s := 'it''s' # fim") $true "string de aspas simples"

# --- GDScript: o que TEM de rodar portao ---
Conferir gd ("var c := " + $Q + "#fff" + $Q) ("var c := " + $Q + "#000" + $Q) $false "cerquilha dentro de string"
Conferir gd ("var c := " + $Q + "a # b" + $Q) ("var c := " + $Q + "a # c" + $Q) $false "cerquilha no meio da string"
Conferir gd ("var c := " + $Q + "a\" + $Q + " # b" + $Q) ("var c := " + $Q + "a\" + $Q + " # c" + $Q) $false "aspas escapadas antes da cerquilha"
Conferir gd ("var s := r" + $Q + "\" + $Q + "#a" + $Q) ("var s := r" + $Q + "\" + $Q + "#b" + $Q) $false "string crua com aspas escapadas"
Conferir gd ("var t := " + $Q + $Q + $Q + "a" + $N + "# nao e comentario" + $N + $Q + $Q + $Q) ("var t := " + $Q + $Q + $Q + "a" + $N + "# outra coisa" + $N + $Q + $Q + $Q) $false "cerquilha em string de tres aspas"
Conferir gd ("var t := " + $Q + $Q + $Q + "a" + $N + $N + "b" + $Q + $Q + $Q) ("var t := " + $Q + $Q + $Q + "a" + $N + "b" + $Q + $Q + $Q) $false "linha em branco dentro de string de tres aspas"
Conferir gd ("var t := " + $Q + $Q + $Q + "a   " + $N + "b" + $Q + $Q + $Q) ("var t := " + $Q + $Q + $Q + "a" + $N + "b" + $Q + $Q + $Q) $false "espaco no fim dentro de string de tres aspas"
Conferir gd ("func f():" + $N + $T + "if a:" + $N + $T + $T + "b()" + $N + $T + "c()") ("func f():" + $N + $T + "if a:" + $N + $T + $T + "b()" + $N + $T + $T + "c()") $false "recuo (e sintaxe)"
Conferir gd ("func f():" + $N + $T + "return 1") ("func f():" + $N + $T + "return 2") $false "logica"
Conferir gd ("var s := &" + $Q + "a#" + $Q) ("var s := &" + $Q + "a#b" + $Q) $false "StringName com cerquilha"
Conferir gd ("var s := 'a#'") ("var s := 'a#b'") $false "aspas simples com cerquilha"
Conferir gd ("var a := 1 + \" + $N + $T + "2") ("var a := 1 + \" + $N + $T + "3") $false "continuacao de linha"

# --- JSON ---
Conferir json ('{"a": 1, "b": [1, 2]}') ("{`n  " + '"a":1,' + "`r`n  " + '"b": [ 1,2 ]' + "`n}") $true "formatacao do JSON"
Conferir json ('{"a": "x y"}') ('{"a": "x  y"}') $false "espaco dentro de string do JSON"
Conferir json ('{"a": 1, "b": 2}') ('{"b": 2, "a": 1}') $false "ordem das chaves (o Dictionary do Godot itera nela)"
Conferir json ('{"a": "\"}"}') ('{"a": "\"} "}') $false "aspas escapadas no JSON"
Conferir json ('{"a": 1}') ('{"a": 1.0}') $false "numero reescrito"

# --- O fecho e a impressao de verdade, num projeto de mentira em TEMP ---
# le_texto.gd le scripts/lido.gd como texto e usa scripts/usado.gd pelo
# scripts/meio.gd (o que o teste cita por res:// ele pode estar lendo: conta cru);
# falsifica.gd mexe em source_code. Comentario no usado nao pode mudar a
# impressao do le_texto; comentario no lido tem de mudar; no falsifica, tudo conta.
$projeto = Join-Path ([IO.Path]::GetTempPath()) ("testar-analise-projeto-" + $PID)
function Escrever([string]$rel, [string]$texto) {
	$p = Join-Path $projeto $rel
	[IO.Directory]::CreateDirectory((Split-Path $p)) | Out-Null
	[IO.File]::WriteAllText($p, $texto, (New-Object Text.UTF8Encoding($false)))
}
function Estado {
	$e = New-Object 'Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
	foreach ($rel in @("scripts/usado.gd", "scripts/meio.gd", "scripts/lido.gd", "tests/le_texto.gd", "tests/falsifica.gd", "docs/nota.md")) {
		$e[$rel] = [Testar3D.Texto]::Hash([IO.File]::ReadAllText((Join-Path $projeto $rel)))
	}
	return , $e
}
function Impressoes {
	$e = Estado
	$g = [Testar3D.Grafo]::new($projeto, $e)
	$n = [Testar3D.Normas]::new((Join-Path $projeto "normas.txt"), $projeto, $g)
	$n.PrepararEstado($e)
	$r = @{}
	foreach ($t in @("le_texto", "falsifica")) {
		$f = $g.Fecho([string[]]@("tests/$t.gd"))
		$r[$t] = $n.Impressao($f, $e, $g.EscopoTextual($f))
		$r[$t + "_fecho"] = $f.Count
	}
	return $r
}
function Conferir-Projeto([bool]$ok, [string]$nome) {
	$script:casos++
	if (-not $ok) { $script:falhas++; Write-Host ("FALHA: " + $nome) }
}
try {
	Escrever "scripts/usado.gd" ("extends Node" + $N + "func f():" + $N + $T + "return 1")
	Escrever "scripts/lido.gd" ("extends Node" + $N + "func g():" + $N + $T + "return 2")
	Escrever "scripts/meio.gd" ("extends Node" + $N + "const U = preload(" + $Q + "res://scripts/usado.gd" + $Q + ")")
	Escrever "docs/nota.md" "nada"
	Escrever "tests/le_texto.gd" ("extends SceneTree" + $N + "const M = preload(" + $Q + "res://scripts/meio.gd" + $Q + ")" + $N + "func _init():" + $N + $T + "var t := FileAccess.get_file_as_string(" + $Q + "res://scripts/lido.gd" + $Q + ")")
	Escrever "tests/falsifica.gd" ("extends SceneTree" + $N + "func _init():" + $N + $T + "var s = load(" + $Q + "res://scripts/usado.gd" + $Q + ")" + $N + $T + "s.source_code = s.source_code.replace(" + $Q + "1" + $Q + ", " + $Q + "2" + $Q + ")")
	$antes = Impressoes
	Conferir-Projeto ($antes["le_texto_fecho"] -eq 4) "o fecho do le_texto tem o teste, o meio, o usado e o lido"
	Escrever "docs/nota.md" "outra coisa"
	$doc = Impressoes
	Conferir-Projeto ($doc["le_texto"] -eq $antes["le_texto"] -and $doc["falsifica"] -eq $antes["falsifica"]) "doc nao muda impressao nenhuma"
	Escrever "scripts/usado.gd" ("extends Node" + $N + "# comentario novo" + $N + "func f():" + $N + $N + $T + "return 1 # e outro")
	$comentario = Impressoes
	Conferir-Projeto ($comentario["le_texto"] -eq $antes["le_texto"]) "comentario no script usado nao muda o portao que nao o le como texto"
	Conferir-Projeto ($comentario["falsifica"] -ne $antes["falsifica"]) "comentario muda o portao que mexe em source_code"
	Escrever "scripts/lido.gd" ("extends Node" + $N + "# lido como texto" + $N + "func g():" + $N + $T + "return 2")
	$lido = Impressoes
	Conferir-Projeto ($lido["le_texto"] -ne $comentario["le_texto"]) "comentario no script lido como texto muda o portao que o le"
	Escrever "scripts/usado.gd" ("extends Node" + $N + "func f():" + $N + $T + "return 3")
	$logica = Impressoes
	Conferir-Projeto ($logica["le_texto"] -ne $lido["le_texto"]) "logica no script usado muda o portao"
} finally {
	Remove-Item -LiteralPath $projeto -Recurse -Force -ErrorAction SilentlyContinue
}

Remove-Item -LiteralPath $dll -Force -ErrorAction SilentlyContinue
if ($falhas -gt 0) { Write-Host ("" + $falhas + " de " + $casos + " casos reprovaram"); exit 1 }
Write-Host ("ANALISE_OK: " + $casos + " casos")
