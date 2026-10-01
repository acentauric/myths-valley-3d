# Obras no vale

As famílias e os planos estão em `data/construcoes/obras.json`. O autoload
[Obras](../../scripts/compartilhado/obras.gd) mantém planos conhecidos,
materiais e ganhos. As bancadas e construções do mundo são ligadas pelo
painel e pelas âncoras de `world_builder.gd`.

Perto de uma construção atendida, a aba Obras do painel permite executar
o plano conhecido quando os materiais estão disponíveis. Os ganhos de
corpo e descanso já são aplicados; trocar modelos e abrir cômodos segue
os critérios das issues ainda abertas.
