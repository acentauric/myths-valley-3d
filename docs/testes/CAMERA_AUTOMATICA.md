# Câmera automática — 07/10/2026

Refs #126, #99 e #150. C remapeável percorre Livre, Arrastar e Automática.
A preferência e os rótulos são preservados em PT/EN/ES. Movimento por teclas
mantém o rumo inicial enquanto a câmera acompanha; clique continua usando
a navegação física do jogador. Mouse ainda permite orientar e aproximar.

O acompanhamento limita o giro a 1,2 rad/s. Sondas laterais têm intervalo de
0,3 s e retenção de 1,5 s. A geometria de até oito árvores/barcos próximos
é reutilizada para detectar galhos, raízes e velas que o cilindro do tronco
ou o casco não descrevem. Se não há ângulo livre, apenas o modelo que encobre
o corpo desvanece temporariamente, voltando ao sair ou trocar de modo.
As árvores da mata continuam usando o conjunto de colisões de troncos.

`camera_automatica` passa em 51 s: três modos persistidos, giro sem saltos,
paredes nas camadas CAMERA/MUNDO, desvio e retorno, raízes da gameleira,
folga em casa/píer/guia, caminhada real na lavoura e restauração das malhas.
`--sem-desvio` reprova duas perguntas; `--sem-visibilidade` reprova a raiz
obstruindo o corpo, sem falhas de compilação. `camera_volta` (59 s),
`click_controls` (58 s) e `idiomas` (2 s, 744 campos) também passaram.

Capturas locais em `scratch/camera-automatica/`: vegetação com raízes
desvanecidas, casa, píer e proximidade do guia. A vela que preenchia a tela
foi detectada na conferência visual e incluída nos obstáculos. Os NPCs
interpenetrando no píer pertencem à revisão de colisões #36; esta correção
não muda sua física. Saída gráfica ainda apresenta warnings de recursos
no encerramento; os resultados acima não significam encerramento gráfico
sem warnings.

A navegação usava o raio nominal dos coqueiros, enquanto o corpo físico
incluía sua base mais larga. `raio_fisico_do_tronco` agora é a medida comum.
O gate anterior acusou passagem por `Colisão de tronco 04`; depois da
correção, `navegacao` passou em 63 s. A fixture da Filó libera a população
para isolar a pergunta de locomoção. A #99 permanece aberta até a bateria
final completa; a #150 ainda exige revisão das demais espécies.
