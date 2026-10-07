# Galeria e custo da vegetação — 07/10/2026

## Galeria de moradores e peças (#78)

O MODELOS já oferece cartões paginados, filtro por nome e ficha individual
com o modelo real do catálogo. As setas percorrem os registros; arrasto,
roda e duplo clique manipulam a prévia, sem alterar o vale. EDITAR muda
altura, postos e falas do morador ou medida e colisão da peça selecionada.
Os ajustes persistem no perfil; GRAVAR transfere a camada para o projeto
quando ele roda no editor. RESTAURAR recupera o padrão.

`painel_personagens` passa com navegação, edição, prévia isolada,
paginação, reprodução/pausa da voz mesmo com o som geral desligado e
confirmação de pendências. `-- --sem-previa` retira o modelo apresentado
e reprova a exigência de prévia 3D. Não se alteram os JSON do autor para
fazer a verificação: o gate restaura os ajustes temporários do perfil.

Inspeção gráfica: `scratch/galeria78/ficha-{cartoes,morador,assets,registro,
editor,confirmacao}.png`. A ficha de Pedro, a grade de assets e o editor
da mangueira estão dentro da moldura; a prévia mostra o GLB real. Log
`tools/temp/galeria78.log`: `PAINEL_PERSONAGENS_OK`, sem erro de script.
Os avisos de RID/RenderingServer ao encerrar a janela continuam conhecidos.

## Vegetação (#34)

`tools/prototipo_3d/medir_lod.gd -- --capturar` mede A/B/B/A na mesma
carga, câmera e resolução, sem VSync; espera 40 quadros e mede 120 em
cada passagem. O parâmetro novo salva a imagem depois da medição e
imprime a resolução efetiva, que pode ser redefinida pelo jogo após
iniciar. As seis capturas deste lote têm **1920×1080**, não 1024×576.
GPU: GTX 1660 Ti Max-Q, Vulkan Forward+, Godot 4.7.2.

| Câmera | Triângulos sem/com | FPS sem/com | Draw calls sem/com |
|---|---:|---:|---:|
| Perto | 3.468.905 / 1.231.320 | 108,18 / 179,05 | 655 / 423 |
| Acima | 2.715.558 / 1.193.063 | 112,94 / 162,67 | 550 / 374 |
| Longe | 7.366.811 / 1.106.212 | 66,28 / 152,24 | 1.455 / 825 |

A queda de triângulos é de 64,5%, 56,1% e 85,0%. Uma rodada anterior
produziu a mesma contagem aproximada e melhoria nas três câmeras, com
FPS diferentes: são medições da cena de benchmark, não garantia de
FPS mínimo da exportação (#43). Os logs são `tools/temp/lod34-atual.log`
e `tools/temp/lod34-capturas.log`.

As imagens `scratch/lod34/{perto,acima,longe}-{com,sem}.png` foram
inspecionadas. Perto e acima mantêm os modelos Tripo próximos; longe,
as copas simplificadas substituem o preenchimento distante. Na câmera
livre do benchmark, um tronco em primeiro plano cruza a câmera nas duas
variantes: não é evidência de correção de #156. As árvores de referência
permanecem individuais, e o relevo/composição não são alterados.

`lod_vegetacao` passa passeio, mapa, retorno, reconstrução e copas
distantes; `-- --sem-corte` desliga o fim de visibilidade e reprova.
`lod_das_pecas` e `pier_legivel` também passam. A regressão de calendário
detectada em `saveiro` foi corrigida separadamente; a bateria completa do
vale ainda será conferida antes de encerrar #34.
