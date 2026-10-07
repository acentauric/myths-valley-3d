# Apresentação do povoado — #155

A chegada mantém Pedro, Tonho, Candinha e Zefa disponíveis. Na região do
jogador (65 unidades), entram inicialmente até dois moradores opcionais,
três quadrúpedes e um bando. A cada 45 segundos de jogo ativo, a apresentação
acrescenta dois moradores, dois quadrúpedes e um bando. Ao terminar a entrada
na casa (passo 7 do Pedro), o elenco próximo já pode aparecer inteiro.
O tempo decorrido entra no save.

Uma missão em andamento ou uma fala reserva seu morador, mesmo fora desse
orçamento. Quem já entrou em cena não desaparece perto do jogador: a saída
usa 85 unidades. A entrada visual leva 0,8 segundo; a decisão custa uma
verificação a cada 0,5 segundo. Fora de cena, movimento, rig, animação e
colisão ficam suspensos; as cadeias continuam disponíveis. As rotinas voltam
a consultar o horário ao retornar. Isso concentra a redução no começo da
campanha, sem amputar o elenco ou impedir encontros posteriores.

## Medição em 07/10/2026

Mesmo equipamento, Godot 4.7.2, Tripo, Forward+, viewport 1920×1080,
07:54 fixo, câmera acima de Candinha, perfis novos isolados. Autoplay
e outros portões parados. Cinco segundos de aquecimento e quinze de coleta
por execução. A opção `--sem-orcamento` restaura todos os atores, mantendo
o mesmo código, câmera e cenário. Os tempos são intervalos reais entre
quadros; não constituem uma certificação geral de FPS (#43).

| Medida | Sem apresentação gradual | Com apresentação gradual |
|---|---:|---:|
| Moradores ativos | 23 | 6 |
| Quadrúpedes ativos | 22 | 3 |
| Bandos ativos | 10 | 1 |
| Quadros coletados | 501 | 896 |
| FPS médio | 33,33 | 59,73 |
| Mediana por quadro | 29,33 ms | 13,77 ms |
| Percentil 95 | 52,78 ms | 54,88 ms |

CPU Intel Core i7-9750H, GPU NVIDIA GTX 1660 Ti Max-Q. Os picos continuam:
esta amostra melhora a média, mas não demonstra melhora no percentil 95.
Vistas: `scratch/populacao/antes.png` e `depois.png`; logs locais em
`tools/temp/populacao-{antes,depois}.log`, ignorados pelo Git. O desligamento
das janelas ainda apresenta avisos de textura/RID conhecidos, sem erro de
script durante a coleta; isso permanece pendência própria.

Portão: `testar.ps1 -Teste apresentacao_do_povoado`. Cobra os limites,
os quatro essenciais, rig e colisão suspensos, missões preservadas,
introdução por tempo e progresso, fade terminado e tempo salvo.
Liberar todos os atores reprova as três perguntas de orçamento.
