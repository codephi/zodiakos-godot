# Design: zoom do mapa ancorado no cursor

**Data:** 2026-07-13
**Status:** aprovado

## Objetivo

Fazer o zoom do mapa estelar aproximar e afastar na direção indicada pelo mouse. A estrela ou região sob o cursor permanece no mesmo ponto da tela durante cada passo da roda.

## Comportamento

- Cada evento de scroll usa a posição atual do cursor como foco.
- Se o cursor mudar de posição entre eventos de scroll, o próximo passo acompanha imediatamente o novo foco.
- Mover somente o mouse não altera o zoom nem a posição da câmera.
- O comportamento vale tanto ao aproximar quanto ao afastar.
- Quando o zoom já estiver no limite mínimo ou máximo, novos eventos nessa direção não deslocam a câmera.
- O arraste do mapa e os limites de zoom existentes permanecem inalterados.

Esta regra substitui a decisão inicial de centralizar o zoom na câmera registrada na spec do mapa procedural.

## Arquitetura

O `MapCameraController` continuará sendo o único responsável pela entrada e pela posição lógica da câmera. Ao receber um evento de roda, ele calculará o deslocamento do cursor em relação ao centro da viewport no plano estelar. Depois de aplicar o novo `Camera3D.size`, converterá a variação de escala em um deslocamento lógico e sincronizará a posição visual.

A operação usará apenas dados explícitos — passos do zoom, posição do cursor e tamanho da viewport — para que o cálculo seja testável sem depender da árvore de cenas. O controlador emitirá `logical_position_changed` somente quando o zoom realmente deslocar a câmera e continuará emitindo `zoom_changed` para uma mudança efetiva de tamanho.

## Fluxo

1. O jogador gira a roda do mouse.
2. O controlador lê a posição atual do cursor e o tamanho da viewport.
3. Calcula o tamanho de câmera limitado e encerra sem movimento se ele não mudar.
4. Calcula quanto o ponto sob o cursor mudaria na projeção ortográfica.
5. Move a posição lógica pela diferença, preservando o ponto sob o cursor.
6. Sincroniza a câmera visual e emite os sinais de posição e zoom.
7. O streaming atual reage aos sinais e atualiza os setores visíveis.

## Casos de teste

- Cursor no centro: o zoom muda sem deslocar a posição lógica.
- Cursor fora do centro: aproximar desloca a câmera na direção do cursor.
- Aproximar e afastar com o mesmo cursor preserva o ponto lógico sob ele.
- Mudar o cursor entre passos muda a direção do deslocamento seguinte.
- Tentar ultrapassar os limites não desloca a câmera nem emite uma falsa mudança.
- Viewport com dimensão inválida ignora a compensação com segurança.

## Fora de escopo

- Zoom contínuo sem eventos de scroll.
- Movimento da câmera causado apenas pelo movimento do mouse.
- Suavização, inércia ou animação do zoom.
- Mudanças no fator ou nos limites atuais do zoom.
