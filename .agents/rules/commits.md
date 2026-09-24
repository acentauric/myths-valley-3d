# Regras de Commits Semânticos

Todos os commits no repositório devem seguir a convenção de **Commits Semânticos Estruturados** (Conventional Commits em português).

## Formato

```
<tipo>(<escopo>): <descrição clara e objetiva>
```

## Tipos Permitidos

- `feat`: nova funcionalidade no jogo, sistemas, UI ou dados
- `fix`: correção de bug, erro em GDScript ou incoerência nos JSONs de dados/diálogos
- `docs`: alterações exclusivas na documentação em `docs/`, `README.md` ou comentários de cabeçalho
- `refactor`: reestruturação de código/arquitetura sem alterar comportamento final
- `style`: formatação, convenções de escrita, organização de imports ou lint
- `chore`: manutenção de ferramentas (`tools/`), configurações da IDE (`.vscode/`), git ou tarefas rotineiras
- `perf`: melhoria de desempenho, otimização de renderização ou alocação de memória

## Exemplos

- `feat(mundo): adiciona leiras de mandioca na roca`
- `docs(readme): adiciona guia de commits semanticos`
- `fix(dialogo): corrige data historica de 1880 para 1887 em pedro.json`
- `chore(pixellab): atualiza prompts nos scripts de geracao`
