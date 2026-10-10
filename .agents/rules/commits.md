# Regras de commit

O assunto do commit é **uma frase em prosa, no presente, dizendo o que mudou no
jogo** — não um rótulo de categoria.

```
A cabra do Seu Benedito dá motivo à pedra, e o Pedro explica de quem é o morro
```

## Por que não `tipo(escopo):`

O repositório carregou a convenção de Commits Semânticos por 59 commits e a
abandonou na prática: nenhum dos quarenta últimos a seguia, e ninguém sentiu
falta. A razão é o que este projeto é. Uma fatia daqui quase nunca cabe num
tipo só — a da cabra mexeu em geração de mundo, em diálogo, em missão e no
portão que a segura. `feat(mundo):` teria escondido três quartos disso, e o
escopo entre parênteses, que era a parte informativa, ficou vazio em quase
todos os commits em que foi usado.

A prosa também é a voz do resto da documentação. `git log --oneline` deste
projeto se lê como a lista do que o jogo passou a fazer, que é exatamente o
que se quer procurar nele meses depois.

## Como escrever o assunto

- **O que mudou para quem joga**, e não que arquivo foi tocado. "A lapa passa a
  trancar a rampa de verdade" diz mais que "corrige colisão da lapa".
- **Presente do indicativo.** O commit descreve o jogo depois dele.
- **Uma linha**, sem ponto final. Duas orações ligadas por vírgula ou por dois
  pontos quando a mudança tem duas metades que se seguram: *"O quintal ganha
  porteira nos fundos: a saída por cima, para a ladeira e a lapa"*.
- **Documentação sozinha** abre com `Docs:` — é o único prefixo que sobrou, e
  existe porque commit que não muda o jogo precisa se anunciar como tal.

## O corpo

Opcional, e vale a pena quando a mudança tem uma razão que o assunto não cabe:
o defeito que ela conserta, a decisão que foi tomada e a alternativa recusada,
ou a armadilha que o próximo vai pisar. O corpo é para o porquê; o diff já
conta o quê.

## O que vale sempre

- **O trabalho entra na `develop`; a `main` sempre abre e roda.** A `develop` é
  fluida: o autor testa o jogo nela, e teste automático só roda quando ele pedir.
  A `main` só recebe a `develop` quando o autor decidir, com a bateria completa
  verde (`testar.ps1 -Push`).
- **Cada fatia é um commit, com teste e falsificação** (regra 4 do
  [PLANO.md](../../docs/projeto/PLANO.md)): um `test_` de unidade ou uma
  conferência num caso da suíte do vale. Commit que muda comportamento sem
  mexer em teste nenhum é commit que ninguém vai conseguir defender depois.
- Commite à vontade na `develop`. Teste quando o autor pedir:
  `.\tools\prototipo_3d\testar.ps1` (os testes de unidade, em segundos). A
  bateria completa, `testar.ps1 -Push`, é obrigatória só para ir à `main` (#242).
