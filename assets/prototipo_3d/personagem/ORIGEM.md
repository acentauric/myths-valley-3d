# Personagem de teste

## Arquivo animado em uso

Arquivo fornecido pelo usuário em 23/09/2026:

`C:\Users\ramor\Downloads\JOGO\medieval+character+3d+model.glb`

O repositório preserva uma cópia com nome estável: `medieval_character_animated.glb`.

- Tamanho: 11.601.748 bytes.
- SHA-256: `781F5BBD208E9E7C43E2CF030F2A365A3FA69B18EB221F153E428F279B16BC50`.
- Conteúdo verificado: uma malha texturizada, um `Skeleton3D` com 65 ossos e um `AnimationPlayer` com 11 clipes.
- Clipes: `afraid`, `agree`, `chop`, `fold_arms`, `greet_01`, `idle`, `look_around`, `run`, `swim`, `walk` e `wave_goodbye_02`.
- Altura original aproximada: 0,979 unidade; o controlador normaliza para 1,78 m.

Na tela de exportação compartilhada pelo usuário, o formato era GLB, **Exportar Esqueleto** estava ativado, as 11 animações estavam selecionadas e **Animação no Lugar** estava ativada. Essa configuração é adequada ao controle de deslocamento pelo Godot.

O Godot extrai três imagens incorporadas ao lado do GLB durante a importação. Elas são artefatos reproduzíveis e estão ignoradas; a reprodução limpa parte apenas do GLB versionado.

## Base anterior

O ZIP original continua preservado fora do repositório em `C:\Users\ramor\Downloads\JOGO\medieval+character+3d+model.zip`. Dele veio o FBX `tripo_convert_033097b1-adc1-4d96-a77c-9a57917b5d03.fbx`, também mantido no histórico desta branch. O FBX tem o mesmo rig e texturas, mas não possui clipes. `provisional_animator.gd` permanece somente como fallback para modelos sem animação.

## Uso e licença

Uso local e integração ao protótipo foram solicitados pelo usuário. Nenhum dos arquivos recebidos veio acompanhado de licença. Confirmar no Tripo as condições de redistribuição antes de tornar públicos os fontes, binários ou assets do personagem. Os originais na pasta Downloads não foram modificados.

Correção de apresentação: o material da instância é renderizado dos dois lados. Um comparativo mostrou que partes do torso desapareciam com descarte de faces traseiras. O GLB original permanece intacto.
