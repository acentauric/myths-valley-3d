# Enredo

## O que temos

| Arquivo | Conteúdo |
|---------|----------|
| [capitulo-06.md](capitulo-06.md) | Capítulo 6 — Um Convite ao Acaso |
| [capitulo-07.md](capitulo-07.md) | Capítulo 7 — O Revoar das Asas Negras |

Transcritos de `Batalha de Mitos - Cap 06 ao 10.docx`, texto original do universo
de Batalha de Mitos.


## Como o jogo consome

A prosa acima é a **fonte**, para leitura humana. O jogo lê a versão estruturada
em [`data/enredo/enredo.json`](../../data/enredo/enredo.json): capítulos,
momentos, personagens e locais, em campos que o código consegue percorrer.

As falas ficam separadas em [`data/dialogos/`](../../data/dialogos/), um arquivo
por personagem. Isso facilita revisar diálogo sem encostar em código.

Quando o texto da prosa mudar, a versão estruturada precisa ser atualizada junto
— ela não é gerada automaticamente, é uma adaptação.

## Onde o jogador entra

O jogador é um **viajante que atravessou com o manuscrito** e chegou ao vilarejo
do recôncavo baiano, trezentos anos depois do décimo terceiro navio. Pedro
Nolasco da Encarnação, o jovem pescador, é quem o acolhe: cede a terra vizinha,
ensina a viver ali e, quando o convite da fazenda chegar, leva o jogador junto.

Assim o jogador não substitui o protagonista — ele **acompanha** Pedro pelos
acontecimentos dos capítulos 6 e 7, que são a história dele.

O nome do jogador é pedido na abertura e guardado em `Jogo.nome_jogador`. Todas
as falas usam `{jogador}` como marcador, trocado em tempo de execução.

## Adaptação para o jogo (proposta a validar)

| Capítulo | Vira no jogo |
|----------|--------------|
| 6 — Um Convite ao Acaso | Ato 1: chegam os convites ao vilarejo. Viagem pela mata até a fazenda. Recepção, o desafio, as seis salas. |
| 7 — O Revoar das Asas Negras | Ato 2: o quarto da Matinta. A fuga. A noite de perseguição. Buscar escudo e lança nas ruínas do palacete. O embate final com o espírito do senhor da fazenda. |

Pontos que já são mecânica natural do jogo:
- **A jornada pela mata** vira travessia com caminho não definido — combina com
  a geração procedural das regiões.
- **Buscar armas nos destroços** vira coleta e inventário (Fase 2).
- **O escudo e a lança de safira** viram itens com brilho azul — candidatos
  naturais a virarem cartas de invocação.
- **A Matinta que troca energia por objetos** é a origem temática da mecânica de
  escambo e das cartas de ritual.
