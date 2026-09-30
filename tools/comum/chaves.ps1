# Leitor das chaves de API.
#
# Ordem: variável de ambiente primeiro, depois o arquivo .env da raiz do projeto
# (que está no .gitignore). A chave nunca é passada por argumento de linha de
# comando nem impressa.
#
# Carregue com:  . .\tools\comum\chaves.ps1

function Get-RaizDoProjeto {
    # tools/comum/ -> tools/ -> raiz
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}


function Get-Chave {
    param([Parameter(Mandatory)][string] $Nome)

    $doAmbiente = [Environment]::GetEnvironmentVariable($Nome)
    if ($doAmbiente) { return $doAmbiente.Trim() }

    $env_file = Join-Path (Get-RaizDoProjeto) ".env"
    if (Test-Path $env_file) {
        foreach ($linha in [System.IO.File]::ReadAllLines($env_file)) {
            $limpa = $linha.Trim()
            if ($limpa -eq "" -or $limpa.StartsWith("#")) { continue }
            $corte = $limpa.IndexOf("=")
            if ($corte -lt 1) { continue }
            if ($limpa.Substring(0, $corte).Trim() -eq $Nome) {
                return $limpa.Substring($corte + 1).Trim().Trim('"').Trim("'")
            }
        }
    }

    throw "Chave '$Nome' não encontrada. Veja docs/ferramentas/CHAVES.md."
}
