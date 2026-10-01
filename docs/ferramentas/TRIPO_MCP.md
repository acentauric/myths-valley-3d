# Tripo no Codex e no VS Code

Configure o servidor MCP local `tripo mcp` na sua instalação do Codex. A configuração da máquina não é versionada neste projeto. O servidor permite gerar modelos a partir de texto ou imagem, consultar tarefas e saldo e executar cadeias de processamento.

As credenciais ficam no perfil local `%USERPROFILE%\.tripo`. Nenhuma chave deve ser colocada no Git ou no `.env`.

## Preparar uma máquina

Requisitos: Node.js 20 ou superior, uma conta do Tripo e créditos para as operações de geração.

No PowerShell:

```powershell
npm install -g tripo-cli
tripo login --region ov
tripo doctor
codex mcp list
```

Abra a pasta `myths-valley-3D` como projeto confiável no Codex/VS Code. Depois da primeira instalação ou de uma alteração na configuração MCP, feche e abra uma nova sessão do Codex. A lista de ferramentas deverá incluir `tripo`.

Cada integrante instala o CLI, configura seu servidor MCP e faz seu próprio login; a configuração e a credencial não são compartilhadas pelo repositório.

## Fluxo recomendado

1. Coloque imagens de referência temporárias em `.assets-raw/tripo/referencias/`.
2. Peça ao Codex para usar o MCP `tripo`, indicando o caminho absoluto da imagem e o destino em `.assets-raw/tripo/gerados/`.
3. Para objetos, use o cenário `game-pc` ou `game-mobile`, conforme o orçamento de geometria.
4. Para personagens, use o cenário `anim`. Ele faz geração, verificação de rig, rig automático e retargeting dos presets `idle` e `walk`.
5. Examine o GLB/FBX no Godot. Só depois copie o resultado escolhido para `assets/` e registre origem, hash e licença.

Exemplo de pedido usando uma imagem:

```text
Use o Tripo MCP para criar um modelo 3D a partir de
C:\caminho\referencia.png. Use o cenário game-pc e grave os arquivos em
.assets-raw\tripo\gerados\casa-medieval. Mostre o saldo antes de gerar.
```

Exemplo de personagem animado:

```text
Use o Tripo MCP com esta imagem de personagem e o cenário anim. Grave o
resultado em .assets-raw\tripo\gerados\personagem. Depois confira se o arquivo
tem esqueleto e os clipes idle e walk antes de sugerir a importação no Godot.
```

## Capacidades disponíveis pelo MCP

| Ferramenta | Uso |
| --- | --- |
| `tripo_make` | Gera de texto, caminho de imagem, URL ou tarefa anterior; também executa uma cadeia como textura, rig e conversão. |
| `tripo_task_get` | Consulta uma tarefa pelo ID. |
| `tripo_task_wait` | Aguarda a tarefa e baixa os artefatos. |
| `tripo_balance` | Consulta créditos disponíveis. |
| `tripo_history` | Lista as tarefas recentes criadas pelo CLI. |

O cenário `anim` inclui dois presets. Para escolher outras animações com precisão, use o CLI após o rig:

```powershell
tripo anim retarget '@last' --animation preset:idle preset:walk preset:run
```

O Tripo aceita até cinco animações por tarefa de retargeting e cobra cada animação. Os nomes disponíveis dependem dos presets expostos pela versão atual do serviço.

## Diagnóstico

```powershell
tripo --version
tripo whoami
tripo doctor --json --no-open
codex mcp get tripo
```

Se o MCP estiver configurado mas não aparecer nesta conversa, abra uma nova sessão do Codex. A lista de ferramentas é definida quando a sessão começa; editar a configuração não injeta ferramentas em uma conversa já aberta.

Documentação oficial: [Tripo no Codex](https://developers.tripo3d.ai/pt/docs/codex-plugin), [Tripo CLI](https://developers.tripo3d.ai/en/docs/cli) e [configuração MCP do Codex](https://developers.openai.com/learn/docs-mcp).
