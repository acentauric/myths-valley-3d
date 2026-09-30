# Abertura e áudio compartilhados

## Testar

Execute `JOGAR_3D.cmd`. A abertura mostra o cenário 3D real, sem sprites de fundo. Por padrão, a câmera faz um sobrevoo suave pela vila; em **AJUSTAR → Cenário do menu**, é possível escolher **Parado** ou **Sobrevoo**. A escolha é salva em `user://preferencias_visuais.cfg`, separada das preferências de áudio e do projeto 2D. Os botões do menu usam um único verbo em caixa alta: **JOGAR** apresenta as nove falas de `data/dialogos/pedro.json` (a mesma travessia do 2D), em três momentos de câmera; **EXPLORAR** entra diretamente no vale; **MAPA** abre a vista superior da região geográfica em escala horizontal 1:1, com pontos de interesse clicáveis, zoom pela roda e deslocamento pelo botão direito; **AJUSTAR** abre as opções de cenário e áudio; **CONHECER** mostra créditos e bastidores; **SAIR** abre uma confirmação antes de fechar o jogo. No mapa, **VOLTAR** ou Esc retorna ao menu. Na confirmação de saída, **CANCELAR** ou Esc retorna ao menu. As cenas da travessia evocam o vale, sem reconstruir o porto de Salvador. Enter/E/Espaço avançam a narrativa e Esc a pula. A origem e as limitações do mapa estão em [MAPA_GEOGRAFICO_3D.md](../mundo/MAPA_GEOGRAFICO_3D.md).

O texto clicável **v0.1.0-dev · Build #4** fica no rodapé interno do painel do menu e abre os marcos desta derivação em um painel centralizado. A seta direita avança para a próxima página e a esquerda retorna; cada mudança aparece em uma linha. O registro completo está em [CHANGELOG_3D.md](../projeto/CHANGELOG_3D.md); a identificação e as entradas curtas apresentadas no jogo ficam em `prototipo_3d/data/historico_3d.json`.

**Contexto histórico:** a história se passa no Recôncavo Baiano, em 1887, conforme [AMBIENTACAO.md](../mundo/AMBIENTACAO.md). Essa informação orienta a ambientação e fica na documentação; não apresentar o rótulo “RECÔNCAVO BAIANO · 1887” na abertura nem em outra tela da interface.

A tela **CONHECER** apresenta créditos e o mundo ao jogador em linguagem pública. Caminhos de arquivos, ferramentas usadas na produção, comparações entre versões e notas de implementação ficam nesta documentação, fora da interface.

O controle geral de som fica no canto superior direito da abertura: o próprio ícone de alto-falante é o botão que liga ou desliga o áudio, e a dica ao passar o mouse indica a ação. O painel de opções reúne volumes de música/efeitos/ambiente, quatro trilhas de menu, dois conjuntos de sons dos botões (Original e Madeira) e mar/aves. As preferências são salvas automaticamente. Durante o passeio, WASD anda e Shift corre. Esc libera o cursor; o botão **HOME** (ícone de casa na coluna de botões redondos do canto superior direito, abaixo do som e do relógio) retorna ao menu inicial. A tecla M oferece o mesmo atalho. Voltar reinicia o passeio; ainda não há save/continuar 3D. Os passos usam terra, grama ou areia por região aproximada; corrida usa o efeito compartilhado de corrida.

## Contrato de reutilização

- `assets/audio/` na raiz é o catálogo compartilhável com o projeto 2D, incluindo fontes e metadados.
- `scripts/autoload/audio.gd` é o mesmo gerenciador independente de dimensionalidade do 2D, copiado sem adaptar sua API.
- O projeto executável separado `prototipo_3d/` recebe cópias nos **mesmos caminhos relativos**, via script. Não usa links simbólicos, caminhos pessoais ou dependência de outro clone.
- Todos os áudios ficam disponíveis, inclusive ferramentas/plantio/portas ainda não usados pelo gameplay 3D. Chamadas futuras: `Audio.efeito("plantar")`, `Audio.passo("terra")`, `Audio.tocar_musica()`.
- Dados narrativos são reutilizados; cenas e controladores visuais continuam específicos de cada versão. Não importar autoloads 2D dependentes de gameplay só para tocar áudio.
- Preferências têm o mesmo formato, mas o 3D conserva seu diretório `MythsValleyPrototype3D`: não sobrescreve saves ou preferências 2D.

## Sincronizar sem apagar assets exclusivos

Na raiz do repositório 3D:

```powershell
# Atualizar catálogo da branch 3D a partir do worktree 2D (revisar diff depois).
./tools/sync_audio.ps1 -SourceProject ../myths-valley-2D -TargetProject .
# Publicar o catálogo no projeto 3D executável.
./tools/sync_audio.ps1
# Auditoria SHA-256; código de saída 1 se houver divergências.
./tools/sync_audio.ps1 -Check
```

O script copia arquivos novos/modificados, **sobrescrevendo os equivalentes do destino** com a origem escolhida. Faça commit das edições desejadas antes de sincronizar. Não remove arquivos exclusivos. Também copia `.import` para preservar configurações de importação; `.godot` não é copiado. Antes de publicar, confira `git diff` e faça importação/teste no Godot. Para propor melhorias ao áudio comum, mantenha a API compatível e sincronize ou cherry-pick para a outra branch, sem mesclar controladores 2D/3D indiscriminadamente.

Base inicial: branch 2D `849b776`; cenário 3D preservado de `6bd07ed`. As fontes existentes em `assets/audio/fontes` acompanham os sons; reutilização técnica não altera as licenças originais. A narração de boas-vindas é a gravação existente, não uma nova dublagem sincronizada frase a frase com a travessia.

## Teste de regressão

`Godot --headless --path prototipo_3d --script res://tests/smoke_opening.gd` verifica carregamento dos 31 áudios de runtime (há mais seis MP3 de origem arquivados), construção dos menus, nove falas, entrada no jogo, jogador no chão, retorno e pulo da abertura. Com renderização gráfica, acrescente `-- --capture` para capturas em `user://teste_abertura.png` e `user://teste_opcoes.png`. Isso não substitui ouvir e avaliar a mixagem no computador de destino. O backend dummy/headless pode emitir aviso de material dos modelos 3D durante descarregamento.

O menu tem **Idioma** (AJUSTAR → Geral): português, inglês ou espanhol, salvo em `user://preferencias_visuais.cfg`. A tradução usa o `TranslationServer` do Godot com as frases em português como chave (`prototipo_3d/scripts/prototipo_3d/idioma_menu.gd`); textos de dados usam campos `*_en` e `*_es` nos próprios JSON (`travessia_en`/`travessia_es` em `pedro.json`; `estado_*`, `titulo_*` e `mudancas_*` em `historico_3d.json`). Cada campo de AJUSTAR tem um botão "?" com a explicação completa nos três idiomas (`ajuda_menu.gd`). Só o menu muda de idioma: ao entrar no vale, o locale volta ao português. A narração falada da travessia continua em português.
