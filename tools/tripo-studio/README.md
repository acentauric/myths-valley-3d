# Automação assistida do Tripo Studio

Esta ferramenta conecta o Codex ao seu Chrome normal pela extensão oficial do
Playwright MCP. Assim, o Tripo Studio usa a sessão que você já autenticou manualmente,
sem depender dos créditos separados da API do Tripo.

## Primeira execução

1. Instale a extensão oficial
   [Playwright MCP Bridge](https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm)
   no Chrome.
2. Faça login no Tripo Studio normalmente, sem abrir um navegador automatizado.
3. No PowerShell, a partir da raiz do projeto, instale as dependências:

```powershell
cd tools/tripo-studio
npm install
npm run open
```

`npm run open` apenas abre o endereço no navegador padrão. O MCP não inicia outro
Chrome nem copia seus cookies. Na primeira operação, a extensão pedirá que você
aprove a conexão e escolha a aba que poderá ser controlada.

## Uso pelo Codex

Configure o servidor MCP `playwright` localmente e reinicie o Codex ou
o VS Code para carregá-lo. Configuração e tokens não são versionados. Então peça,
por exemplo:

> Abra o Tripo Studio, use a imagem X como referência e prepare a geração. Antes de
> consumir créditos, mostre o custo e aguarde minha confirmação.

Esse é um fluxo semiautomático: o Codex pode navegar, preencher campos, carregar
imagens, acompanhar tarefas e baixar resultados. A confirmação humana fica no ponto
que efetivamente consome créditos ou publica um resultado.

Para iniciar o servidor manualmente:

```powershell
npm run mcp
```

Para abrir o Tripo Studio no navegador padrão:

```powershell
npm run open
```

## Limites práticos

- Mudanças na interface do Tripo podem exigir ajustes na automação.
- CAPTCHA, verificação por e-mail e autenticação de dois fatores continuam manuais.
- Compartilhe somente a aba necessária quando a extensão solicitar acesso.
- Antes de colocar um arquivo no jogo, confira aparência, licença, escala, rig,
  materiais e nomes das animações.
