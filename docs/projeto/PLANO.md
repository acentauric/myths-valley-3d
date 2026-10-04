# Plano do Myths' Valley 3D

O jogo 3D é mantido em `acentauric/myths-valley-3d`, com seu projeto Godot na
raiz. O jogo 2D segue sua própria linha em `acentauric/myths-valley`.

## O que já roda

Exploração do vale, moradores (que andam pela malha de navegação), missões em
âncoras com recompensa (#48) e diário de missões acompanhadas, calendário (com
o registro das mudanças no relógio), energia, vida, inventário, equipamento,
talentos, cartas, coleção, obras, pesca, cozinha, oficina, os cordéis (pendurados no barbante, o folheto em
alta com a capa de cada um), a lavoura da casa
(#8: arar, plantar, regar, crescer por dia regado e colher, com a regra do
roçado do 2D), o cemitério do Damião (o mato, o conserto das lajes e o cercado,
que é obra), o corte das árvores (toda árvore do vale, que volta adulta em um
ano do calendário, com a madeira de lei e a pedra dura presas ao talento e à
ferramenta de aço), o saveiro do mestre Quirino (o comprador que encosta no
píer no dia 14 de cada estação, com a cadeia do Seu Benedito, a encomenda de
piaçava e a piaçava tirada no facão), a fé (#52: os seis marcos, o rito, a troca, a
teia da fé no K, as missões da Dona Zefa e de cada fé e a festa de cada uma,
com os moradores no marco à tarde, e a capelinha do cemitério de costas para o
mar), os cômodos por dentro das próprias
construções (#26: a igreja do Bom Jesus e a casa herdada, com a cama que vira o
dia, o baú e o desmaio das duas da #50; e a casa do Pedro e a da Dona Zefa,
cada uma com o interior de quem mora) e três vagas de salvamento. A
existência de um sistema não significa que todos os seus gatilhos ou telas
estejam concluídos.

## Próxima tarefa

O board é a fonte dos critérios de aceite:
[issues do projeto](https://github.com/acentauric/myths-valley-3d/issues).
Enquanto houver tarefa aberta no marco Jam 04/10, ela tem prioridade;
Pós-jam segue as dependências descritas em cada issue.

Antes de implementar, confira o código e o teste atuais: as issues mais
antigas podem descrever como ausente algo que já foi incorporado.

## Cada fatia

Leia a issue e o portão do assunto, implemente a mudança, acrescente ou
ajuste a verificação de comportamento e mostre que ela detecta o defeito.
Rode a bateria com perfil isolado; erro de compilação e travamento reprovam.
Registre a mudança no CHANGELOG_3D e cite a issue no corpo do commit.

Os sistemas deste repositório evoluem aqui. Não há sincronizador de regras,
dados ou áudio com outro projeto. Geração de arte e áudio precisa de pedido
explícito, e cada asset mantém origem e créditos.

## Registros

- [Histórico de mudanças](CHANGELOG_3D.md).
- [Etapas e decisões anteriores](HISTORICO_DESENVOLVIMENTO_3D.md).
- [Arquitetura](ARQUITETURA.md).
- [Validação](VALIDACAO.md).

## Separação concluída em 01/10/2026

O projeto abre na raiz, com sistemas locais, sem sincronização ou testes
dependentes de outro checkout (#44 e #61). Modelos e WAVs, inclusive suas
versões históricas, usam Git LFS (#60). Abertura e controles contam falhas e
foram falsificados para conferir a reprovação por código de saída (#69).
