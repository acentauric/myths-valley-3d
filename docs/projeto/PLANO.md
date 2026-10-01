# Plano do Myths' Valley 3D

O jogo 3D é mantido em `acentauric/myths-valley-3d`, com seu projeto Godot na
raiz. O jogo 2D segue sua própria linha em `acentauric/myths-valley`.

## O que já roda

Exploração do vale, moradores, missões em âncoras, calendário, energia, vida,
inventário, equipamento, talentos, fé, cartas, coleção, obras, pesca,
cozinha, oficina e três vagas de salvamento. A existência de um sistema não
significa que todos os seus gatilhos ou telas estejam concluídos.

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
