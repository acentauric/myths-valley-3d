# Mapa geográfico do 3D

## Direção

O desenho feito no Google Earth pelo autor é a referência geográfica da primeira
região explorável do 3D. Os dados continuam **em metros reais**; o catálogo
define quantos metros cabem em uma unidade do Godot (`scale_m_per_unit`). Para a
demo, Bom Jesus dos Pobres usa **1 unidade = 4 m** (escala 1/4): a geografia
relativa do KML é preservada, mas o vale fica caminhável — Fazenda e Praça a
~220 m em vez de ~890 m. Larguras de ruas, rios e orla e os afastamentos da
mata têm mínimos em unidades para continuarem jogáveis em qualquer fator.
Ruas, rios e áreas desenhadas no KML orientam o terreno e o mapa visto de cima;
construções, vegetação e encontros podem receber tratamento artístico sem
deslocar os pontos de referência por conveniência da antiga maquete.

A intenção de longo prazo é mapear o Brasil por regiões e pontos de interesse.
Isso não significa criar uma única cena ou carregar todo o país de uma vez.
O protótipo carrega **uma região inteira por execução**; carregamento por
proximidade, transições contínuas e níveis de detalhe ainda são etapas futuras.
O primeiro trecho fornece o formato de dados e a referência de escala.

Esta orientação substitui, **para o mapa geográfico do 3D**, a escolha de uma
região compacta para a demonstração registrada em
[DECISOES_PROTOTIPO_3D.md](../projeto/DECISOES_PROTOTIPO_3D.md). A documentação e o mapa
do jogo 2D continuam com sua escala e implementação próprias.

O KML não é a fonte permanente da composição visual. Depois de importada a base,
casas, árvores, postes e demais elementos autorais devem poder ser ajustados e
salvos visualmente no Godot sem voltar para o KML. A separação entre a camada
geográfica regenerável e a composição autoral, inclusive a regra de reimportação
sem perda, está em [COMPOSICAO_AUTORAL_3D.md](COMPOSICAO_AUTORAL_3D.md).

## Fonte preservada e camadas derivadas

| Camada | Arquivo | Papel |
|---|---|---|
| Desenho original | [`data/mapas/bom_jesus_dos_pobres_fonte.kml`](../../data/mapas/bom_jesus_dos_pobres_fonte.kml) | Exportação do Google Earth fornecida pelo autor; preservar como fonte editável e auditável. |
| Geometria normalizada | [`data/mapas/bom_jesus_dos_pobres.json`](../../data/mapas/bom_jesus_dos_pobres.json) | Resultado determinístico de [`importar_kml.py`](../../tools/mapas/importar_kml.py); coordenadas locais, classes de feição e metadados para o jogo. Não editar à mão. |
| Cenário interpretado | [`data/mapas/bom_jesus_dos_pobres_cenario.json`](../../data/mapas/bom_jesus_dos_pobres_cenario.json) | Costa, faixa urbana e mata ampla inferidas das capturas e convertidas dos traçados do HTML por [`importar_mascaras_html.py`](../../tools/mapas/importar_mascaras_html.py). Revisável sem alterar o KML. |
| Catálogo | [`data/mapas/regioes.json`](../../data/mapas/regioes.json) | Identifica as regiões, aponta para seus arquivos e escolhe `active_region` para a execução atual. |
| Prévia de planejamento | [`MAPA_PONTOS_INTERESSE.html`](../../tools/mapas/MAPA_PONTOS_INTERESSE.html) | Visão 2D para discutir os pontos antes da composição final no 3D. |

O KML veio do projeto **Myths' Valley**; a revisão atual foi recebida em
26/09/2026.
A cópia do repositório preserva os mesmos bytes do arquivo recebido, com SHA-256
`c6f1ef3e93b1b4c269f2ce3e4f4f254856b7e6fa410bda0e958dfc3245decf30`.
Ele contém **26 feições**: 12 pontos, 8 ruas, 2 linhas de rio, 3 polígonos de
área (Fazenda, Praça e Mata) e o polígono Mapa, usado para enquadrar a câmera.
Os nomes e traçados representam as
anotações do autor; não equivalem, por si só, a cadastro oficial de vias,
hidrografia, uso do solo ou edificações. Nenhuma imagem de satélite faz parte
desse KML ou precisa ser embutida no jogo.

O KML **não desenha a linha completa da costa**, nem delimita toda a mata ao
norte. A faixa de areia, a água da baía, a mancha urbana, a vegetação extensa e
as transições entre elas foram inferidas visualmente das capturas fornecidas.
Essas formas pertencem à camada de cenário e devem continuar identificáveis
como aproximações. O polígono Mata do KML é uma área localizada e não define,
sozinho, toda a cobertura vegetal do mapa.

## O que o jogo desenha agora

[`geo_region_renderer.gd`](../../scripts/prototipo_3d/geo_region_renderer.gd)
consome o JSON geográfico e o JSON de cenário da região ativa. Ele constrói
superfícies vetoriais para terra, mar, mata, vila e polígonos do KML; faixas para
costa, rios e ruas; e posições para os 12 POIs. A terra tem colisão. A vegetação
é distribuída com semente fixa nas zonas de mata por duas instâncias `MultiMesh`
 (troncos e copas), mantendo afastamento de vias, rios, praia, áreas abertas e
 marcadores. Um grupo pequeno de colisores acompanha o jogador nos troncos
 próximos; a água não tem colisão. [`world_builder.gd`](../../scripts/prototipo_3d/world_builder.gd)
acrescenta edifícios e detalhes locais perto dos POIs da primeira região.

O botão **MAPA** da abertura usa o mesmo mundo 3D com câmera ortográfica superior.
Abre no recorte 16:9 do polígono Mapa; a roda aproxima e não afasta além desse
quadro, o botão direito arrasta a vista e
os marcadores clicáveis centralizam os pontos. **VOLTAR** retorna ao menu.
As pontas norte e sul ficam fora do recorte inicial e podem ser vistas com o arrasto.
O terreno usa a altitude dos 12 pontos do KML. A malha de terra e sua colisão,
as vias, a vegetação, as construções e os destinos de navegação acompanham o
relevo interpolado. Bom Jesus dos Pobres mantém a escala horizontal em 1:4 e usa
`vertical_exaggeration = 2.0`: 4 m reais de altitude correspondem a 2 unidades do
Godot. Rios e mar são representações de superfície, não simulação hídrica.
Esta cena ainda não tem todas as construções, ruas urbanas ou biomas do país.

## Escala e coordenadas

O KML guarda longitude e latitude em graus no sistema WGS84, na ordem
`longitude,latitude,altitude`. A extensão das feições recebidas é aproximadamente
**2,84 km de oeste a leste por 2,03 km de sul a norte**. Isso mede o envelope
dos desenhos, não a superfície exata de terra jogável. A referência local da
primeira região é o ponto Praça:

| Campo | Valor |
|---|---:|
| Longitude da origem | `-38.77964955032106` |
| Latitude da origem | `-12.81231369544162` |
| X no Godot | aumenta para leste |
| Z no Godot | aumenta para sul |
| Escala horizontal | `1 unidade = 4 metros` (demo; `scale_m_per_unit` em `regioes.json`) |
| Escala vertical | exageração `2.0×` (`1 unidade = 2 metros` de altitude) |

Para esta região pequena, o importador usa uma projeção local: calcula os metros
por grau de longitude e latitude na origem e aplica esses fatores a cada ponto.
Os valores atuais, registrados no JSON derivado, são aproximadamente
`108565,6654 m/grau` a leste e `110628,8951 m/grau` ao norte:

```text
x = metros_por_grau_longitude × (longitude − longitude_origem)
z = metros_por_grau_latitude × (latitude_origem − latitude)
```

Altura (`Y`) vem do campo `source_altitude_m` dos 12 pontos do KML. As linhas de
rua e rio e os polígonos têm altitude zero sem medição útil; seus zeros não são
amostras do solo. Entre os pontos, o jogo interpola a altitude por média ponderada
pelo inverso do quadrado da distância. Isso cria um relevo aproximado, não uma
medição contínua: o KML não contém dados suficientes para reconstruir encostas,
maré ou profundidade com precisão. Ao atualizar o KML, regenere o JSON derivado
para que as novas altitudes sejam usadas. **Não usar a mesma aproximação ou
uma única origem em ponto flutuante para o Brasil inteiro.** Cada região terá
uma âncora WGS84 própria; conexões entre regiões trabalham com coordenadas
geográficas de precisão adequada, e apenas o trecho carregado vira coordenada
local do Godot.

## Regiões, pontos de interesse e renderização

O catálogo `regioes.json` já permite escolher uma região ativa pelos caminhos
`source_kml`, `geometry` e `scenario`. O renderizador aceita o mesmo esquema de
dados para outra região. O acabamento artesanal em `world_builder.gd`, por sua
vez, ainda é específico de Bom Jesus dos Pobres; selecionar outro ID no catálogo
produz sua base vetorial, desde que os arquivos existam, sem colocar
automaticamente prédios narrativos ou criar uma passagem jogável entre mapas.

Cada região futura deve registrar identificador estável, limites geográficos,
origem local, fonte e revisão dos dados. O importador usa o atributo `id` de
cada `Placemark` do KML como ID da feição e guarda também
`source_placemark_id`. Assim o nome exibido pode mudar sem trocar a chave do
POI. Ao reexportar, confira se o Google Earth conservou esses IDs; se não,
prepare uma migração dos vínculos de missões e salvamentos. Para feições sem
`Placemark id`, o importador cria um ID `provisional_...` baseado em ordem e
nome, que **não deve ser usado como chave permanente**. O campo opcional
`ExtendedData/Data[@name="kind"]` pode declarar `poi`, `road`, `river` ou
`area` conforme a geometria; sem ele, o tipo é inferido, inclusive rios cujo
nome é literalmente `Rio`. Separe ainda a posição anotada, o papel no enredo e
a representação de época: um nome observado hoje não precisa aparecer
literalmente em uma história situada em 1887.

Ruas e rios são percursos; polígonos delimitam zonas; POIs fixam lugares e
eventos. Hoje toda a primeira região, suas superfícies e suas árvores são
construídas na entrada. Para avançar até uma escala nacional, será necessário:

1. Dividir o território em regiões identificadas e conexas, começando pelas
   vizinhas da vila. Registrar POIs e transições entre elas.
2. Preservar cada levantamento original com sua proveniência, normalizar os
   dados para um esquema único e usar IDs próprios, sem depender de nomes de
   ruas para encontrar feições.
3. Carregar e descarregar regiões por proximidade, mantendo estado persistente
   de missões, construções e mudanças do jogador separado do terreno de base.
4. Criar níveis de detalhe para visão aérea e caminhada, além de colisões e
   objetos detalhados apenas perto do jogador. Medir memória, tempo de
   carregamento e precisão antes de ampliar a área contínua.

### Adicionar uma região ao catálogo

1. Dê à região um ID único e estável, por exemplo `br_ba_nome_da_regiao`.
   Guarde o KML original em `data/mapas/` com origem e data.
2. Gere o JSON métrico com `importar_kml.py`, informando `--source`, `--output`,
   `--region-id` e `--origin-name`. A origem precisa ser o nome de um ponto
   presente no KML. O script atual aceita ponto, linha e polígono.
3. Produza um JSON de cenário com o **mesmo `region_id`**, limites métricos,
   polígono de terra, `background_kind` (`sea` na costa ou `land` no interior) e,
   conforme a região, costa, mata, vila e configuração de vegetação. O
   importador `importar_mascaras_html.py` usa caminhos e parâmetros
   específicos da prévia atual; ele não converte automaticamente HTMLs de novas
   regiões. Adapte a ferramenta ou desenhe e registre essas máscaras em uma
   fonte própria da nova região.
4. Adicione a entrada em `regioes.json` com `id`, `title`, `source_kml`,
   `geometry`, `scenario` e `scale_m_per_unit` (4.0 na demo; 1.0 para escala real). Defina `active_region` com
   esse ID para abrir a região no protótipo. A seleção é de desenvolvimento,
   ainda sem viagem contínua entre regiões.
5. Acrescente os detalhes próprios da região separadamente do renderizador
   genérico. Compare distâncias, vias e POIs com a fonte antes de criar a região
   seguinte.

## Como atualizar o desenho

1. Exporte novamente o projeto do Google Earth em KML e guarde a exportação
   original. Confira a região e compare IDs dos `Placemark`, nomes, contagens e
   limites com a versão anterior; mudanças grandes podem indicar seleção errada
   na exportação.
2. Substitua a fonte versionada somente pelo novo desenho escolhido. A revisão
   anterior continuará recuperável no histórico do Git. Registre a origem e a
   data da revisão.
3. Execute `python tools/mapas/importar_kml.py` a partir da raiz do
   repositório para regenerar `bom_jesus_dos_pobres.json`. Não altere o JSON
   derivado manualmente; corrija a fonte ou o importador quando o traçado vier
   errado.
4. Se alterar as máscaras desenhadas no HTML, execute depois
   `python tools/mapas/importar_mascaras_html.py` para regenerar
   `bom_jesus_dos_pobres_cenario.json`. Confira costa, mata e vila no jogo:
   esse script usa a transformação específica da prévia e converte
   **interpretações visuais**, não feições adicionais do KML. Se só o KML mudou,
   revise se as máscaras existentes ainda correspondem ao novo traçado.
5. Compare a visão superior com o desenho, percorra no jogo as ligações entre
   Praça, costa, Ponte e Mirante e registre quais POIs foram aprovados para a
   história antes de ampliar a próxima região.

Essa separação deixa o KML reutilizável, o processamento reproduzível e as
decisões visuais reversíveis à medida que o mapa cresce.

## Caminhos e colisão no protótipo

As oito ruas do KML são faixas vetoriais em metros reais convertidos pela escala:
a Rua Principal tem 11 m, a Rua do mirante 4,2 m e as demais 5 m, com mínimos
jogáveis de 4,6 / 2,6 / 3,2 unidades. As faixas recebem a textura de terra batida
com UV ao longo do percurso; a Praça recebe o chão de terra projetado pelo mundo. Uma borda terrosa
ajuda a distinguir as vias da Praça e da vegetação na vista superior. As faixas
têm colisão própria para que continuem caminháveis mesmo onde cruzam água.

A malha de terra usa colisão nos dois lados. Isso é necessário neste cenário:
sem essa configuração, a malha aparecia no mapa, mas a física não reconhecia o
chão na Praça e o personagem caía e reaparecia continuamente. Os materiais das
superfícies vetoriais também mostram as duas faces; antes, a orientação dos
triângulos ocultava terra, ruas e rios na câmera do jogo.

Dois POIs originais ficam fora do polígono de terra inferido: um Rio e o Pier.
O renderizador cria passarelas estreitas desde a margem até esses pontos, sem
alterar as coordenadas do KML. Elas são uma interpretação jogável do cenário,
não um traçado fornecido pelo Google Earth. O Pier fica no mesmo nível do
percurso para permitir a passagem do personagem. Ao rever a linha de costa ou
o KML, conferir novamente esses acessos.

O teste `tests/mapa_fluxo.gd` percorre HOME, MAPA, AJUSTAR,
CONHECER, histórico, confirmação de SAIR, introdução, jogo e retorno ao HOME.
Ele também verifica caminhada, corrida, deslocamento da Praça até a Rua
Principal, colisão em todos os vértices das oito ruas e exploração dos dois
POIs sobre a água. Execute com Godot em modo gráfico, pois a captura de mouse
necessária ao movimento não funciona em `--headless`:

```text
Godot --path . --script res://tests/mapa_fluxo.gd
```
