# Abertura e áudio compartilhados

## Continuidade do Pedro no roteiro 3D (#65)

O desembarque e a primeira corrida antecedem as apresentações: Tonho no píer,
Candinha na praça e Zefa com a chave. Cada encontro espera a conversa; Pedro
conduz o percurso. Depois vêm a entrada da casa, as ferramentas e a caderneta,
que só é cumprida ao abrir o painel de missões. A primeira roça vem em seguida.
A cabra pertence à frente da lombada, depois da chegada e da lenha da ponte:
quebrar a lapa abre a passagem, aproximar-se da cabra dispara a descida e voltar
ao Pedro fecha a história com a explicação da Santa Casa. São escolhas do 3D;
`dialogos/pedro.json` não precisa reproduzir o roteiro do outro jogo.

`continuidade_pedro` verifica ordem, interlocutores e o sinal da abertura real
do painel. `lombada` joga os oito golpes, a passagem, a descida animada, a
conversa final e a retomada do save. Remover a meta da caderneta reprova.

## Testar

Execute `JOGAR_3D.cmd`. A abertura usa o vídeo do sobrevoo e só monta o
cenário quando uma tela precisa dele. **JOGAR** escolhe uma das três vagas:
nova partida pede nome e começa pela travessia; vaga ocupada retoma o save.
**EXPLORAR** passeia sem salvar. **TESTAR** inicia o testador local
determinístico, com perfil separado e relatório; veja
[AUTOPLAYER.md](../testes/AUTOPLAYER.md). **MODELOS** abre a galeria,
**SOBRE** mostra créditos, **SAIR** pede confirmação. Os ícones laterais
incluem HOME, ajustes, som, relógio, mapa e tela cheia. MAPA abre a região;
Esc retorna. Enter/E/Espaço avançam a travessia e Esc pula.

A versão clicável no rodapé vem de `data/historico_3d.json`: atualmente
`v0.1.0-dev · Build #9`. A numeração só muda ao fechar um build. O registro
completo fica em [CHANGELOG_3D.md](../projeto/CHANGELOG_3D.md).

**Contexto histórico:** a história se passa no Recôncavo Baiano, em 1887, conforme [AMBIENTACAO.md](../mundo/AMBIENTACAO.md). Essa informação orienta a ambientação e fica na documentação; não apresentar o rótulo “RECÔNCAVO BAIANO · 1887” na abertura nem em outra tela da interface.

A tela **CONHECER** apresenta créditos e o mundo ao jogador em linguagem pública. Caminhos de arquivos, ferramentas usadas na produção, comparações entre versões e notas de implementação ficam nesta documentação, fora da interface.

O alto-falante liga/desliga o som. AJUSTAR reúne volumes, trilhas,
sons dos botões e ambiente; preferências são persistidas. WASD anda e
Shift alterna corrida. HOME retorna ao menu, salvando a vaga ativa;
M abre o mapa. As três vagas e seus pontos de restauração pertencem ao
3D, em `MythsValleyPrototype3D`, separados de saves do 2D.

## Áudio e independência

O catálogo inicial reutilizou arquivos do 2D com origem e licença
preservadas. O 3D evolui independentemente: não há sincronização automática
nem requisito de outro checkout. O gerenciador `scripts/autoload/audio.gd`
e os sons de ferramentas, plantio e portas já são usados pelo gameplay.
Novas gerações precisam de autorização do lote e registro de créditos.

Base inicial: branch 2D `849b776`; cenário 3D preservado de `ac3b431`. As fontes existentes em `assets/audio/fontes` acompanham os sons; reutilização técnica não altera as licenças originais. A narração de boas-vindas é a gravação existente, não uma nova dublagem sincronizada frase a frase com a travessia.

## Teste de regressão

`Godot --headless --path . --script res://tests/smoke_opening.gd` verifica carregamento dos 31 áudios de runtime (há mais seis MP3 de origem arquivados), construção dos menus, nove falas, entrada no jogo, jogador no chão, retorno e pulo da abertura. Com renderização gráfica, acrescente `-- --capture` para capturas em `user://teste_abertura.png` e `user://teste_opcoes.png`. Isso não substitui ouvir e avaliar a mixagem no computador de destino. O backend dummy/headless pode emitir aviso de material dos modelos 3D durante descarregamento.

O menu tem **Idioma** (AJUSTAR → Geral): português, inglês ou espanhol, salvo em `user://preferencias_visuais.cfg`. A tradução usa o `TranslationServer` do Godot com as frases em português como chave (`scripts/prototipo_3d/idioma_menu.gd`); textos de dados usam campos `*_en` e `*_es` nos próprios JSON (`travessia_en`/`travessia_es` em `pedro.json`; `estado_*`, `titulo_*` e `mudancas_*` em `historico_3d.json`). Cada campo de AJUSTAR tem um botão "?" com a explicação completa nos três idiomas (`ajuda_menu.gd`). O locale escolhido permanece no vale. A cobertura dos dados é cobrada por `tests/idiomas.gd`; lacunas declaradas continuam na #6. A narração falada da travessia continua em português.
