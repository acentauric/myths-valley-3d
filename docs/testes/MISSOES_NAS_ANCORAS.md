# Missões nas âncoras do vale — auditoria de 07/10/2026 (#1)

O contexto original de cinco missões numa constante foi superado: a chegada
tem 16 passos em `data/missoes_guia.json`; as demais cadeias também vivem em
dados. O painel J agrupa enredo e dia a dia, mostra objetivo e diário, permite
acompanhar uma missão e mantém a escolha quando outra missão chega.
HUD, bússola e marcador consultam a mesma missão acompanhada.

O checklist do autoload 2D foi substituído por decisão posterior do autor,
registrada em `scripts/autoload/caderno_do_vale.gd`: o 3D deve ter seus próprios
mecanismos, sem depender desse checklist. Não restauramos a implementação
antiga para cumprir literalmente um critério anterior àquela decisão.
O diário e os contadores das metas apresentam o progresso nativo.

Evidências no estado local:

- `cadeia_das_missoes`: verde em 83 s, 16 passos completos pelos gatilhos
  do vale (interação, ferramentas, oficina, mutirão, cozinha e descanso).
  O fixture posiciona o jogador entre passos; não comprova o trajeto inteiro.
- `painel`: verde em 42 s; seleção, diário, acompanhamento e permanência
  do foco, incluindo a mudança correspondente do resumo no HUD.
- `missoes`: verde em 42 s; regressão das regras compartilhadas preservadas.
- `tarefa_no_hud`: verde em 6 s; resumo e progresso da tarefa nativa.
- `idiomas`: verde; textos dos passos têm tradução ou pendência explícita
  no catálogo, conforme o critério original da issue.
- Execução V21 do testador: chegada completa em 483,44 s e 110 ações normais,
  custo zero, sem teleporte. Complementa o fixture da cadeia com navegação real.

Pedro mantém condução, narração, espera por proximidade e aviso de escurecer;
as correções posteriores de prioridade, soleiras, alcance e recursos preservam
esses gatilhos. A conclusão desta issue cobre as missões nas âncoras presentes,
não declara que todo o enredo futuro ou todas as issues do jogo estão prontos.
