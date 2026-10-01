# Credenciais locais

O jogo e os testes não precisam de chaves. Ferramentas de produção de áudio
podem usar ELEVENLABS_API_KEY por variável de ambiente ou `.env` local na raiz.
`tools/comum/chaves.ps1` lê a variável de ambiente antes do arquivo local.
O `.env` nunca é versionado, lido pelo agente ou copiado para scripts.

O Tripo CLI mantém suas credenciais no perfil local `%USERPROFILE%\.tripo`.
Nunca inclua credenciais ou tokens de extensões em configurações versionadas.
Geração paga só ocorre quando solicitada explicitamente.
