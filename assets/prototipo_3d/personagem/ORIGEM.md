# Personagem de teste

Arquivo fornecido pelo usuário: `C:\Users\ramor\Downloads\JOGO\medieval+character+3d+model.zip`.

O ZIP contém um FBX `tripo_convert_033097b1-adc1-4d96-a77c-9a57917b5d03.fbx` e cinco texturas PNG na pasta `.fbm`. O FBX importado pelo Godot tem um Skeleton3D com 65 ossos `mixamorig_*`, uma malha com 23.695 vértices e nenhum clipe de animação. Altura original aproximada: 0,979 unidade; o controlador normaliza para 1,78 m.

Uso: validação local autorizada pelo usuário. O arquivo não veio acompanhado de licença no ZIP; confirmar condições de redistribuição antes de publicar fontes/binários. Os arquivos originais de Downloads permanecem preservados.

O repositório versiona o FBX, que contém as imagens embutidas. Na primeira importação, o Godot recria cinco PNGs ao lado do modelo; esses arquivos e a pasta `.fbm` redundante são ignorados. Uma reprodução limpa confirmou a importação da malha com textura usando somente o FBX.

O movimento provisório é criado por `scripts/prototipo_3d/provisional_animator.gd`; não se trata de clipes do Mixamo. As texturas são do modelo fornecido.

Correção de apresentação: o material da instância é renderizado dos dois lados. Um comparativo mostrou que partes do torso sumiam com descarte de faces traseiras mesmo na pose original. O FBX não foi modificado.
