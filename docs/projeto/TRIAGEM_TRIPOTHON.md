# Triagem do Tripothon S1: #40 e #62

Levantamento de 09/10/2026 a partir das issues (e dos comentários de 08/10), de
`docs/arte/ASSETS_TRIPO.md` e de `docs/projeto/DECISOES_PROTOTIPO_3D.md`. Fatos
dos comentários: a submissão foi feita em **05/10/2026**, o Demo Day de São Paulo
é em **11/10/2026** (os textos antigos dizem 17/10, o que está errado), e as
Builds 9, 9B e 10 já são públicas. Este documento não confirma nada que as
issues não registrem: o link da submissão e as respostas do regulamento não
estão no repositório.

## #40: pacote de submissão e regulamento

| Item | Estado |
|---|---|
| Submissão feita | **Feita** em 05/10 (comentário de 08/10). Link não registrado na issue |
| Build jogável Windows | **Feito**; superado: já existem as Builds 9, 9B e 10 |
| Gravação do percurso (roteiro na #41) | Não verificável aqui; confirmar o que foi enviado e a #41 |
| Prancha de assets | Idem |
| Registro do pipeline Tripo → Godot | Documentação existe (`ASSETS_TRIPO.md`, `docs/ferramentas/TRIPO_MCP.md`, `TRIPO_PLAYWRIGHT.md`, `ORIGEM.md` por pasta); falta confirmar o que foi anexado |
| LEIA-ME curto (teclas, requisitos #43, créditos #42) | Créditos: texto pronto em `assets/ATRIBUICOES.md`; falta confirmar o LEIA-ME enviado |
| Regulamento conferido, respostas anotadas | **Falta**: nada na issue. `DECISOES` mantém prazo, fuso, formato, vídeo, ferramentas e código anterior como "itens de conferência" |
| Declaração do que é anterior ao evento (base 2D) | **Falta**: `DECISOES` manda não afirmar elegibilidade sem verificar |
| Link da submissão na issue | **Falta** |

**Obsoleto:** o prazo "05/10 (AoE)" como pendência (passou, e a entrega foi feita);
"Depende de #38, #39, #41 e #42" como bloqueio da submissão (o envio ocorreu sem
a #42 fechada); o pacote como algo a montar, no que já foi enviado.

**Ainda falta, na prática:** a pessoa responsável anota na #40 o link da submissão,
as respostas do regulamento (prazo e fuso, formato, vídeo, ferramentas, regra de
código anterior, trilhas Game e ferramenta Tripo) e a declaração do que veio da
base 2D; depois fecha. A conferência de licenças (#42) segue aberta e vira risco
do que foi submetido: ver `LICENCAS.md`.

## #62: Demo Day em São Paulo

| Item | Estado |
|---|---|
| Título "(17/10)" | **Errado**: o evento é em 11/10/2026; renomear a issue (o comentário de 08/10 já pede) |
| Decidir se a equipe vai | **Falta** registrar a decisão |
| Inscrição (separada da jam) | **Falta**; sem registro. Com o evento em 2 dias, é urgente |
| Build para o dia | Pronto no essencial: a Build 10 (`data/historico_3d.json`) é a mais recente fechada; escolher e congelar a que será mostrada |
| Material de apresentação | **Falta**: reaproveitar vídeo e prancha da submissão, se existirem; apresentação ligada ao tema "A Gift for ____" (`DECISOES`) |
| Marco | A issue está em "Pós-jam", mas a data a trouxe para a frente de tudo |

**Obsoleto:** a data 17/10 em `ASSETS_TRIPO.md` (seção "Tripothon S1"),
`BOARD_2026-10-07.md` e `ISSUES_ABERTAS_2026-10-07.md`; a espera pela submissão da
jam (concluída). Esses documentos não foram alterados nesta fatia.

## Próximos passos, em ordem

1. Decidir presença e fazer a inscrição do Demo Day (11/10).
2. Corrigir o título da #62 e a data nos três documentos acima.
3. Anotar na #40 o link e as respostas do regulamento; fechar.
4. Fechar os bloqueios de licença da #42 que afetam a demo pública (personagem
   jogável, Tripo pós-cancelamento, ElevenLabs).
5. Levar às mãos a Build 10 e o material de apresentação para o Demo Day.
