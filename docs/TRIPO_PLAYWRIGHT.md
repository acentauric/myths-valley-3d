# Tripo Studio com Playwright

## Decisão

O projeto adota uma automação assistida do Tripo Studio para aproveitar o saldo e o
plano da interface web, que são separados da cobrança da API. O Playwright conecta-se
ao Chrome normal pela extensão oficial e usa somente a aba escolhida pelo integrante.

Essa integração não é uma API oficial do Studio: ela depende da interface visual e
pode precisar de manutenção quando a página mudar. Por isso, operações de custo e
etapas de segurança continuam com confirmação humana.

## Instalação

```powershell
cd tools/tripo-studio
npm install
npm run open
```

Antes de conectar o MCP, instale a extensão oficial
[Playwright MCP Bridge](https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm)
e faça login no Tripo Studio normalmente. A extensão solicita aprovação e permite
escolher qual aba será compartilhada com o Codex.

Depois da instalação, reinicie o VS Code/Codex para carregar o servidor `playwright`
de `.codex/config.toml`.

## Fluxo de trabalho recomendado

1. O integrante fornece a imagem e descreve o modelo ou a animação desejada.
2. O Codex abre o Studio e prepara os campos e arquivos.
3. A interface informa a modalidade e o custo da operação.
4. O integrante confirma a geração que consumirá créditos.
5. O Codex acompanha o processamento e baixa o resultado.
6. O resultado escolhido vai para `.assets-raw/tripo/` para inspeção.
7. Somente arquivos aprovados são promovidos para `prototipo_3d/assets/`.

Pagamentos, CAPTCHA, verificação por e-mail e autenticação de dois fatores são
sempre manuais. O saldo do Studio não deve ser confundido com o saldo da API
consultado pelo Tripo CLI/MCP.

Mais detalhes operacionais estão em
[`tools/tripo-studio/README.md`](../tools/tripo-studio/README.md).
