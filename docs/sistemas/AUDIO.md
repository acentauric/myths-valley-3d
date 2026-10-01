# Áudio do vale

O autoload Audio e `ambiente_vale.gd` combinam música por período, ambiente,
passos e falas dos moradores. Os arquivos de jogo ficam em `assets/audio/`;
nomes, texto e voz dos moradores estão em `data/npcs_3d.json`.

As ferramentas em `tools/elevenlabs/` mantêm o registro de produção e leem
credenciais locais por `tools/comum/chaves.ps1`. Gerar fala, música ou efeitos
consome crédito e exige pedido explícito. Não é necessário gerar áudio para
clonar, importar, executar ou testar o jogo.

Origem e créditos estão em `assets/CREDITOS.md` e nos registros ORIGEM.
