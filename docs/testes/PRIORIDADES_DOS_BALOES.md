# Prioridades dos balões

Revisão de 07/10/2026, issues #121, #124, #127 e #132.

| Elemento | Prioridade | Regra |
| --- | ---: | --- |
| HUD essencial | 100 | Missão, estado e controles delimitam espaço disponível. |
| Interação E | 90 | Identifica o alvo sem repetir seu nome em outra placa. |
| Fala | 80 | Uma fala ativa impede oferecer nova conversa com seu dono. |
| Aviso contextual | 60 | Cede somente quando sobrepõe fala ou interação; expira pelo prazo próprio. |
| Nome | 20 | Cede a elementos concorrentes e depende de visibilidade física. |

O E de avançar a caixa Dialogo permanece independente do E de iniciar conversa.
Uma interação com árvore é identificada por metadado do alvo, sem procurar o
nome no texto traduzido. Só nomes que competem com a região da dica se recolhem:
há margem de entrada/retorno para evitar alternância na borda. Um nome de outra
pessoa fora dessa região continua disponível se distância e visibilidade permitirem.

A oclusão consulta a câmera ativa em perspectiva ou ortogonal. Cabeça e dois
pontos do torso são amostrados contra as camadas do cenário/câmera; basta uma
amostra livre para preservar uma pessoa parcialmente visível. Corpos de pessoas,
áreas de interação e folhagem explicitamente marcada não contam como paredes.
O cache por pessoa espaça consultas e exige estabilidade antes da mudança.

Os valores exatos de margens e tempos estão em `placas_nomes.gd`; o teste
`matriz_dos_baloes` cobre troca de alvo, retorno dos nomes, parede, visibilidade
parcial, árvore concorrente e mudança de câmera. `prioridade_dos_avisos` protege
a precedência e a expiração dos avisos. Os testes integrados `foco_do_e`,
`placas_e_baloes` e `popups_na_tela` verificam seleção, tamanho e sobreposição
no vale real. A fixture antiga que exigia nome duplicado sob o E foi atualizada
para o comportamento pedido pelo autor; pessoas usadas na medição são colocadas
em profundidades fisicamente visíveis, preservando a mesma projeção na tela.
