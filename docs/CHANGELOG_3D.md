# Histórico de mudanças — Myths' Valley 3D

Este histórico acompanha apenas a experiência executada em `prototipo_3d/` na
branch `prototype/myths-valley-3d`. O projeto 2D foi a base da derivação, mas
suas fases, versões e novidades não são entradas deste registro. Os marcos
abaixo seguem o que mudou no 3D. A identificação atual é **v0.1.0-dev · Build #3**,
exclusiva desta derivação e ainda sem distribuição publicada.

O texto clicável de versão e build no rodapé da abertura mostra resumos destes
marcos. Os textos curtos e a identificação exibidos no jogo ficam em
`prototipo_3d/data/historico_3d.json`; ao registrar um novo marco ou build,
atualize esse arquivo e este documento juntos.

## Em desenvolvimento — 25/09/2026

Estas mudanças estão no trabalho local e ainda não representam uma versão
publicada:

- O KML desenhado pelo autor foi preservado no projeto e passou a orientar
  ruas, rios, áreas e pontos de interesse do 3D em escala horizontal de 1:1.
- O terreno, a costa e a mata agora são construídos de vetores; a vegetação usa
  instâncias leves e colisão de troncos apenas perto do jogador.
- A vista **MAPA** ganhou zoom, deslocamento e marcadores clicáveis. Um catálogo
  de regiões e importadores separam fonte, geometria e escolhas de cenário.
- O menu inicial passou a usar ações curtas; a saída pede confirmação.
- O controle geral de som ficou no canto superior direito, e as opções de áudio
  passaram a nomear os sons dos botões com clareza. A alternância agora usa
  ícones de som ligado e desligado.
- O passeio 3D ganhou um botão **HOME** para retornar ao menu.
- A abertura e os créditos passaram por uma revisão de texto voltada ao jogador,
  sem notas de implementação na interface.
- O 3D ganhou um histórico próprio, acessível pelo texto de versão e build no
  rodapé do painel inicial; o histórico abre no centro da tela.
- O cenário real da abertura ganhou um sobrevoo suave. Em **AJUSTAR**, é possível
  escolher entre **Parado** e **Sobrevoo**; a preferência visual é salva apenas
  no protótipo 3D.
- O menu ganhou **MAPA**, uma visão superior do cenário com acesso para retornar.
- Terra, ruas e rios voltaram a aparecer na câmera do jogo; a colisão da terra
  foi corrigida para impedir a queda e o reaparecimento contínuo do personagem.
- As oito ruas agora têm bordas visíveis e colisão caminhável. Dois pontos sobre
  a água, Rio e Pier, ganharam acessos desde a margem sem mover o KML original.

## 24/09/2026 — Abertura, áudio e cenário

- A travessia ganhou uma abertura sobre o cenário 3D, com narração, música,
  paisagem sonora e preferências de áudio separadas das partidas 2D
  (`0fcecdc`).
- A casa de Carro Quebrado entrou no cenário com escala e colisão ajustadas
  (`be97f26`).
- O pau-brasil e a referência para novos modelos ampliaram a paisagem
  (`6bd07ed`).

## 23/09/2026 — Primeiro passeio jogável

- O projeto 3D independente ganhou vila explorável, personagem, câmera em
  terceira pessoa, colisões e HUD (`243697e`).
- O personagem passou a usar animações de repouso, caminhada, corrida e gestos
  acionáveis no jogo (`1e77309`).
- As primeiras decisões de escopo e a base técnica foram registradas em
  documentos específicos do protótipo (`1b4080a`, `ee20191`).
