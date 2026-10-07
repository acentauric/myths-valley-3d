# Escala individual das interfaces — #140

Em AJUSTAR → Cenário → Interface, cada componente oferece 65%, 80%, 100%,
115%, 130% e 150%. A alteração vale imediatamente e persiste no perfil;
a seta de restauração devolve só aquele componente a 100%. O botão ao fim
da lista restaura todos os componentes. Texto global e botões do canto
mantêm seus controles existentes.

Há escolhas separadas para missão, relógio, vida, fôlego, vigor, minimapa,
barra de mão, fala, nomes, E de interação, avisos, mochila/baú, caderneta,
almanaque, talentos, laços do povoado, pausa e conversa/tutorial.
Texto, imagens e área clicável são transformados juntos. Painéis grandes
limitam a ampliação à janela; os cantos e centros de ancoragem permanecem.

O HUD calcula o espaço usando a escala de cada medidor. Caso falte largura,
o relógio e os medidores passam para baixo da missão. A matriz dos balões
recebe os retângulos reais da missão, minimapa e barra. Avisos de espera
procuram espaço abaixo do HUD ampliado e cedem diante da fala; o rodapé
acompanha a altura da barra de mão.

## Evidência

- `interface_individual`: independência, persistência, reset individual/todos,
  ancoragem inferior, área clicável, matriz e avisos; três resoluções
  (1280×720, 1440×900, 1920×1080), nos três idiomas. Verde em 4–5 s.
- `--sem-escala` tira a transformação em memória: uma falha, sem erro de script.
- `idiomas`: 764 campos em 44 arquivos; as pendências existentes seguem declaradas.
- `prioridade_dos_avisos` e `tarefa_no_hud`: verdes após a mudança.
- `composicao_do_hud`: verde com a cena real; com `--componentes` usa 150%
  e relógio a 65%. Capturas PT/EN/ES conferidas em
  `scratch/componentes-interface/idioma-0.png` a `idioma-2.png`.

Ainda falta a revisão de todas as telas secundárias e combinações com tamanho
global de texto ampliado para encerrar a #140. A interface do testador não é
incluída nessas preferências. A execução gráfica mantém os avisos já conhecidos
de liberação de texturas ao encerrar, sem erro de script durante o teste.
