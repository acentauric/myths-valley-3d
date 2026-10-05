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

Configure o servidor MCP `playwright` na sua instalação do Codex e reinicie a
sessão para carregá-lo. Configuração e tokens ficam locais, fora do Git.

## Fluxo de trabalho recomendado

1. O integrante fornece a imagem e descreve o modelo ou a animação desejada.
2. O Codex abre o Studio e prepara os campos e arquivos.
3. A interface informa a modalidade e o custo da operação.
4. O integrante confirma a geração que consumirá créditos.
5. O Codex acompanha o processamento e baixa o resultado.
6. O resultado escolhido vai para `.assets-raw/tripo/` para inspeção.
7. Somente arquivos aprovados são promovidos para `assets/`.

Pagamentos, CAPTCHA, verificação por e-mail e autenticação de dois fatores são
sempre manuais. O saldo do Studio não deve ser confundido com o saldo da API
consultado pelo Tripo CLI/MCP.

Mais detalhes operacionais estão em
[`tools/tripo-studio/README.md`](../../tools/tripo-studio/README.md).

## Produção em lote, do prompt ao GLB (05/10/2026)

`tools/tripo/lote_producao.js`, injetado depois de `lote_studio.js` na aba logada
(pela ponte do Playwright MCP, com `browser_run_code_unsafe` e o código num
arquivo dentro de `.playwright-mcp/`), leva cada item `{key, prompt, faces, tex,
tpose, rig}` por geração (55 créditos), retopologia Malha Smart (40), rig (20,
quando pedido) com as animações prontas uma de cada vez (grátis) e exportação
(grátis). O estado fica no localStorage (`mv-producao`): rodar de novo continua
de onde parou, e uma recarga da página só pede reinjetar. O que se aprendeu na
noite de 05/10, com 157 peças:

- **O saldo de verdade** está em `wm-billing/wallet` (`__mv.saldo()`) e o extrato
  em `wm-billing/records?limit=100&offset=N`. O cabeçalho do Studio só se atualiza
  ao recarregar a página; a carteira mostra também créditos que vencem antes do
  plano (em 05/10: 24.640, dos quais 24.620 vencem em 07/10). `produzir` não
  começa uma geração sem saldo para a retopologia.
- **O download pelo clique falha** quando o Chrome deixa o arquivo "Não
  confirmado". `__mv.links()` devolve as URLs assinadas: salve-as com o `filename`
  do `browser_evaluate` e baixe com `tools/tripo/baixar_links.py`; depois
  `sincronizar_downloads.py` (com `--chaves` ou `--exceto`; ele não troca mais um
  GLB do projeto por um download mais velho) e `registrar_lote.py` para o
  `ORIGEM.md` de cada pasta.
- **O `pre_rig_check` é só conselho**: a beata de saia longa veio "não rigável"
  e o rig Mixamo forçado saiu bom. Com o tipo dito no item (`biped`,
  `quadruped`), rigamos assim mesmo; com `auto`, o Studio escolhe o tipo
  (quadrúpede, ave, aquático, serpente). O quadrúpede só tem o `walk`, e em
  alguns modelos ele sai torto: o jogo anda com as pernas do código
  (`animador_bicho.gd`).
- **Versões leves e de longe** de uma árvore pronta saem por retopologia sobre o
  projeto original (`__mv.reaproveitar`, 40 créditos), com a mesma forma e
  textura; dois itens do mesmo projeto nunca no mesmo lote.
- **Clipes a mais** num personagem já rigado custam zero: `reanimar` com o
  preset e uma exportação nova.
