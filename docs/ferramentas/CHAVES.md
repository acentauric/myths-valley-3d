# Credenciais locais

O jogo e os testes não precisam de chaves. Ferramentas de produção de áudio
podem usar ELEVENLABS_API_KEY por variável de ambiente ou `.env` local na raiz;
a das capas dos cordéis (`tools/openai/gerar-capas-cordeis.ps1`) usa
OPENAI_API_KEY do mesmo jeito, e mostra o custo estimado antes (`-Estimar`).
`tools/comum/chaves.ps1` lê a variável de ambiente antes do arquivo local.
O `.env` nunca é versionado, lido pelo agente ou copiado para scripts.

O Tripo CLI mantém suas credenciais no perfil local `%USERPROFILE%\.tripo`.
Nunca inclua credenciais ou tokens de extensões em configurações versionadas.
Geração paga só ocorre quando solicitada explicitamente.

## Jev / TypeSafe: experimento de jogador automático

`JOGAR_JEV.cmd` usa a ponte local `tools/jev/jogar.py`, que lê
`TYPESAFE_API_KEY`, `TYPESAFE_MODEL` e `TYPESAFE_API_URL` do ambiente ou do
`.env` em tempo de execução. A chave nunca é exibida, enviada ao Godot ou
gravada no relatório; só vai no cabeçalho de autenticação do endpoint oficial.
O agente não precisa abrir o `.env` para executar o experimento autorizado.

Cada execução limita o gasto estimado a US$ 0,10 por padrão, com teto
configurável de US$ 0,50 por `--budget`, pela tarifa publicada
configurada na ponte, sem limite padrão de tempo ou chamadas. `--seconds` e
`--calls` acrescentam limites opcionais. `--offline --seconds 15` permite
validar os controles sem usar a API ou crédito.
Operação, limites e relatórios estão em [tools/jev/README.md](../../tools/jev/README.md).
