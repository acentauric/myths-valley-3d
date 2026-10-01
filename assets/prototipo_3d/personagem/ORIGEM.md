# Personagem de teste

## Arquivo animado em uso

Arquivo fornecido pelo usuário em 23/09/2026:

`C:\Users\ramor\Downloads\JOGO\medieval+character+3d+model.glb`

O repositório preserva uma cópia com nome estável: `medieval_character_animated.glb`.

- Tamanho: 11.682.884 bytes.
- SHA-256: `BE2C56A1BDD1321B717BC02EB433F294AB7EB374DA496A5ED0E83D7FB3C51675`.
- Conteúdo verificado: a malha e as texturas originais, um `Skeleton3D` com 65 ossos e um `AnimationPlayer` com 12 clipes.
- Clipes: `afraid`, `agree`, `chop`, `fold_arms`, `greet_01`, `idle`, `jump_down`, `look_around`, `run`, `swim`, `walk` e `wave_goodbye_02`.
- Altura original aproximada: 0,979 unidade; o controlador normaliza para 1,78 m.

Na tela de exportação compartilhada pelo usuário, o formato era GLB, **Exportar Esqueleto** estava ativado, as 11 animações estavam selecionadas e **Animação no Lugar** estava ativada. Essa configuração é adequada ao controle de deslocamento pelo Godot.

Em 26/09/2026, o usuário solicitou `pular_baixo` diretamente do [projeto original no Tripo Studio](https://studio.tripo3d.ai/pt/workspace/animate/medieval-man-wearing-brown-leather-tunic-with-blue-cape-beige-stockin-d3210044-a230-470f-bd18-fa75fce0497c). A exportação GLB com esqueleto e animação no lugar trouxe 12 clipes; `pular_baixo` veio com o nome `jump_down`. Arquivo baixado: `medieval_character_pular_baixo_export.glb`, SHA-256 `6D81BFD0E41C9C8C928999E829DEFA8581941950C9429FEA8ADF4DFDAD9DDCAA`. Somente os dados de `jump_down` foram incorporados ao GLB anterior, de SHA-256 `781F5BBD208E9E7C43E2CF030F2A365A3FA69B18EB221F153E428F279B16BC50`; malha, materiais, texturas, esqueleto e 11 clipes anteriores permaneceram idênticos.

Para o salto jogável, os 90 quadros da posição vertical do quadril em `jump_down` foram fixados na altura inicial de `idle` (0,527653 unidade). O clipe exportado começava com o quadril em 0,946750 unidade, fazendo o personagem aparecer no ar antes do impulso. As demais trilhas e os outros 11 clipes não foram alterados; o arco vertical agora é calculado pelo `CharacterBody3D`. SHA-256 antes desse ajuste: `04B3C23510B2081581482114419FD0AF53D3D050A31153AA2F348B99A5FF7A95`.

O Godot extrai três imagens incorporadas ao lado do GLB durante a importação. Elas são artefatos reproduzíveis e estão ignoradas; a reprodução limpa parte apenas do GLB versionado.

## Base anterior

O ZIP original continua preservado fora do repositório em `C:\Users\ramor\Downloads\JOGO\medieval+character+3d+model.zip`. Dele veio o FBX `tripo_convert_033097b1-adc1-4d96-a77c-9a57917b5d03.fbx`, preservado apenas nas versões históricas que o usavam. O FBX tem o mesmo rig e texturas, mas não possui clipes. `provisional_animator.gd` permanece somente como fallback para modelos sem animação.

## Uso e licença

Uso local e integração ao protótipo foram solicitados pelo usuário. Nenhum dos arquivos recebidos veio acompanhado de licença. Confirmar no Tripo as condições de redistribuição antes de tornar públicos os fontes, binários ou assets do personagem. Os originais na pasta Downloads não foram modificados.

Correção de apresentação: o material da instância é renderizado dos dois lados. Um comparativo mostrou que partes do torso desapareciam com descarte de faces traseiras. O GLB original permanece intacto.
