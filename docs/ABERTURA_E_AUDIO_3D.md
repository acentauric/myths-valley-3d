# Abertura e áudio compartilhados

## Testar

Execute `JOGAR_3D.cmd`. A abertura mostra o cenário 3D real, sem sprites de fundo. **Jogar** apresenta as nove falas de `data/dialogos/pedro.json` (a mesma travessia do 2D), em três momentos de câmera: partida, travessia e chegada. São enquadramentos evocativos do vale, não uma reconstrução do porto de Salvador. Enter/E/Espaço avançam e Esc pula. **Explorar diretamente** entra sem narrativa.

Opções de áudio: ativar/desativar som, volumes de música/efeitos/ambiente, quatro trilhas de menu, duas famílias de sons de interface e mar/aves. As preferências são salvas automaticamente. Durante o passeio, WASD anda, Shift corre, Esc solta o mouse e **M volta à abertura**. Voltar reinicia o passeio; ainda não há save/continuar 3D. Os passos usam terra, grama ou areia por região aproximada; corrida usa o efeito compartilhado de corrida.

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
