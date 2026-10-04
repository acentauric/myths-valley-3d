# O COFRE: toda arte que custou crédito fica guardada, sempre, sem exceção.
#
#     . "$PSScriptRoot\cofre.ps1"
#     Guardar-NoCofre $destino $descricao $semente
#
# REGRA: geração que custou crédito é guardada AUTOMATICAMENTE, no momento em
# que os bytes chegam da API, antes de qualquer decisão sobre ela.
#
# Por que isto existe, e por que não bastava o arquivo.ps1
# --------------------------------------------------------
#
# O `arquivo.ps1` guarda o desenho ANTERIOR antes de alguém passar por cima
# dele. Isso protege o que já estava no jogo, e protegeu: foi dali que saíram
# os três mirantes velhos quando foi preciso voltar atrás.
#
# Mas ele tem um buraco, e o buraco custa crédito: ele não guarda a geração que
# NÃO FOI ESCOLHIDA. Quando se geram quatro variantes da mesma peça para
# escolher a melhor, três não têm destino no jogo. Elas foram pagas, saíram da
# API, e desapareciam — no melhor caso numa pasta temporária que some com a
# sessão.
#
# E são justamente essas que mais custam para refazer: a mesma semente com o
# mesmo texto NÃO devolve o mesmo desenho. Variante descartada é uma tentativa
# que não volta.
#
# Por que mora na camada da API
# ------------------------------
#
# Porque assim nenhum script chamador pode errar. Há mais de vinte
# `gerar-*.ps1` no projeto e vai haver mais; pedir que cada um lembre de
# guardar é pedir que alguém esqueça. Aqui há SEIS pontos em que bytes gerados
# tocam o disco (pixellab.ps1 e geracao.ps1), e os seis chamam isto. Quem
# escrever o vigésimo primeiro script de geração ganha a regra de graça e sem
# saber que ela existe.
#
# O que fica guardado
# --------------------
#
#   assets/sprites/cofre/<nome>__<semente>__<carimbo>.png
#   assets/sprites/cofre/REGISTRO.tsv
#
# O carimbo no nome garante que duas gerações da mesma peça nunca se cubram —
# é o que faltava para as variantes.
#
# O REGISTRO guarda o que a imagem não guarda: a DESCRIÇÃO. O texto é a parte
# mais cara de perder, porque é ele que se ajusta de tentativa em tentativa até
# a peça sair boa, e uma pasta de PNGs não diz o que foi pedido a cada um.
#
# NADA É APAGADO DAQUI. Nunca. Nem peça feia, nem tentativa que deu errado, nem
# variante recusada. Arte gerada é dinheiro gasto e é sorte gasta; espaço em
# disco é barato e é o único dos três que se repõe.

$COFRE = "assets\sprites\cofre"
$REGISTRO_DO_COFRE = "assets\sprites\cofre\REGISTRO.tsv"

## O que está sendo gerado AGORA: descrição e semente do pedido em curso.
##
## Existe porque quem escreve os bytes no disco (`_SalvarBase64`, `_Baixar`)
## não sabe o que pediu — ele recebe uma URL ou um base64 e um destino. Quem
## sabe é a função de geração, que fica duas camadas acima.
##
## Podia ser mais um argumento em cada função interna. Seria pior: bastaria uma
## chamada nova esquecer de repassar e a peça entraria no cofre sem o texto que
## a gerou, que é a parte cara. Marcada aqui, a descrição chega sozinha.
$script:GeracaoEmCurso = @{ descricao = ""; semente = 0 }


## Diz o que está sendo pedido. Toda função `New-PixelLab*` chama isto logo na
## entrada, antes de falar com a API.
function Marcar-Geracao {
    param([string] $Descricao = "", [int] $Semente = 0)
    $script:GeracaoEmCurso = @{ descricao = $Descricao; semente = $Semente }
}


## Guarda uma cópia permanente do que acabou de sair da API.
##
## Chamada logo depois de os bytes tocarem o disco, e de propósito: entre a
## resposta chegar e o script decidir o que fazer com ela não pode haver
## caminho nenhum que perca o arquivo.
##
## Nunca derruba a geração. Se guardar falhar — disco cheio, permissão, o que
## for —, avisa e deixa seguir: perder o aviso é ruim, perder a peça que já foi
## paga e já está no destino seria pior.
function Guardar-NoCofre {
    param(
        [Parameter(Mandatory)][string] $Destino,
        [string] $Descricao = "",
        [int] $Semente = 0
    )
    try {
        if ($Descricao -eq "") { $Descricao = [string]$script:GeracaoEmCurso.descricao }
        if ($Semente -eq 0) { $Semente = [int]$script:GeracaoEmCurso.semente }
        if (-not (Test-Path $Destino)) { return }

        # O cofre é relativo à RAIZ do projeto, e não ao diretório de trabalho
        # de quem chamou: script que roda com Set-Location noutro canto não
        # pode espalhar cofres pelo disco.
        $raiz = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $pasta = Join-Path $raiz $COFRE
        if (-not (Test-Path $pasta)) { New-Item -ItemType Directory -Force $pasta | Out-Null }

        $nome = [System.IO.Path]::GetFileNameWithoutExtension($Destino)
        $carimbo = (Get-Date).ToString("yyyyMMdd-HHmmss")
        $guardado = Join-Path $pasta "${nome}__${Semente}__${carimbo}.png"
        # Dois pedidos no mesmo segundo: desempata pelo milissegundo em vez de
        # cobrir o primeiro.
        if (Test-Path $guardado) {
            $guardado = Join-Path $pasta "${nome}__${Semente}__${carimbo}-$((Get-Date).Millisecond).png"
        }
        Copy-Item $Destino $guardado -Force

        $linha = "{0}`t{1}`t{2}`t{3}`t{4}" -f (Get-Date).ToString("s"),
            (Split-Path $guardado -Leaf),
            ($Destino -replace '^.*[\\/]assets[\\/]', 'assets/'),
            $Semente,
            ($Descricao -replace "`t", " " -replace "`r?`n", " ")
        $arquivo = Join-Path $raiz $REGISTRO_DO_COFRE
        if (-not (Test-Path $arquivo)) {
            [System.IO.File]::WriteAllText($arquivo,
                "quando`tguardado`tdestino`tsemente`tdescricao`r`n",
                (New-Object System.Text.UTF8Encoding $false))
        }
        [System.IO.File]::AppendAllText($arquivo, "$linha`r`n",
            (New-Object System.Text.UTF8Encoding $false))
    } catch {
        Write-Host "  AVISO: nao consegui guardar no cofre: $($_.Exception.Message)"
    }
}
