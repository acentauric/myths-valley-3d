# O MCP do Godot

Dois servidores MCP deixam o agente (Claude Code, Cursor, Cline) trabalhar no
Godot do projeto. Eles se completam:

| Servidor | Precisa do editor aberto? | Para quê |
| --- | --- | --- |
| `godot-editor` — [tomyud1/godot-mcp](https://github.com/tomyud1/godot-mcp) 0.6.0 | **sim**: fala com o addon `addons/godot_mcp/` do editor | ler e editar cenas, nós, scripts, recursos e configurações com o projeto aberto, rodar a cena, ler o console e os erros, desfazer o que fez (77 ferramentas) |
| `godot` — [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) 0.1.1 | não: chama o executável pela linha de comando | abrir o editor, rodar o jogo, ler a saída de depuração, criar cena pela linha de comando, cuidar dos UIDs |

O addon do primeiro veio no commit 00264f0 (Ramon), auditado: MIT, só fala com
`127.0.0.1` (WebSocket 6505, ponte HTTP 6506, visualizador 6510). O runtime
dele (`MCPRuntime`) só atende no jogo rodado pelo editor: no jogo exportado e
nos portões headless ele fica mudo (dbff29a — reaplicar o patch ao atualizar o
addon).

## Como instalar

Os servidores rodam pelo `npx` (Node.js 18 ou mais novo) e ficam **fora do
repositório**: cada um registra no seu Claude Code. O comando muda com o
sistema — no Windows nativo o `npx` vai dentro de `cmd /c` —, e por isso não há
`.mcp.json` versionado: um arquivo com `cmd` quebraria as sessões em Linux.

Windows:

```
claude mcp add godot-editor -- cmd /c npx -y godot-mcp-server@0.6.0
claude mcp add godot -e GODOT_PATH=C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe -- cmd /c npx -y @coding-solo/godot-mcp@0.1.1
```

Linux e macOS:

```
claude mcp add godot-editor -- npx -y godot-mcp-server@0.6.0
claude mcp add godot -e GODOT_PATH=/caminho/do/godot -- npx -y @coding-solo/godot-mcp@0.1.1
```

As versões ficam presas — a do `godot-editor` é a do addon do projeto —, para
ninguém receber outra no meio do trabalho. Depois de registrar, `/mcp` mostra
os dois. O `godot-editor` só responde com o editor aberto e o plugin "Godot
MCP" ligado (Projeto → Configurações do Projeto → Plugins); quem tinha o editor
aberto antes do 00264f0 precisa reabri-lo.

Na máquina do Matheus (05/10/2026), os dois estão em
`C:\Virtualenvs\Mitys Valley\.mcp.json`, a pasta em que o Claude Code abre, e
ligados no `.claude\settings.local.json` dela. Testado: o `godot` lê a versão
(4.7.2) e o projeto (7 cenas, 282 scripts); o `godot-editor` sobe na 6505 e
lista as 77 ferramentas.

## Cuidados

- **Não rode o jogo pelo MCP durante a bateria** (`tools/prototipo_3d/testar.ps1`):
  vários portões medem tempo e física, e outro Godot ocupando a máquina os faz
  reprovar à toa.
- **O `stop_project` e o `stop_scene` param só o que o MCP abriu.** A regra do
  projeto continua: nunca matar processo do Godot por nome (ver o AGENTS.md),
  porque isso fecha o editor aberto de quem está trabalhando.
- O que um e outro gravam (`create_scene`, `add_node`, `save_scene`,
  `write_file`...) cai no projeto como qualquer edição: cena nova segue as
  regras do catálogo e dos dois estilos, e passa pelos portões.
- O cache de desfazer do `godot-editor` (`addons/godot_mcp/cache/`) fica fora do
  Git e do scan do editor (`.gdignore`): guarda cópias de cenas com UIDs
  repetidos.
