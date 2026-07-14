# Zodiakos: streaming em grid 3 × 3 de viewports

**Data:** 2026-07-14

## Objetivo

Manter carregada uma região retangular equivalente a um grid de nove telas:
uma tela visível no centro e oito telas de preload ao redor.

```text
[ preload ][ preload ][ preload ]
[ preload ][  tela   ][ preload ]
[ preload ][ preload ][ preload ]
```

A cobertura acompanhará diretamente o zoom e a proporção da janela. Ela não
crescerá mais de `1×` até `10×` conforme o zoom.

## Regra geométrica

Para uma área visível de largura `W` e altura `H`, a cobertura carregada terá:

- largura total `3W`;
- altura total `3H`;
- área geométrica total `9WH`.

O viewport do jogador permanece centralizado nessa cobertura. Assim, existe uma
margem de uma tela completa em cada direção: esquerda, direita, acima e abaixo.

A conversão do retângulo contínuo para setores usa arredondamento para cima.
Por isso, a quantidade discreta de setores pode ficar ligeiramente acima ou
abaixo da proporção exata de nove, especialmente em zooms próximos onde um único
setor ocupa grande parte da tela.

## Configuração central

O campo de escala adaptativa será substituído por:

```gdscript
@export var stream_viewport_grid_size: int
```

Valor de produção:

```text
camera_max_zoom = 100.0
stream_viewport_grid_size = 3
```

O valor representa a quantidade de viewports por eixo. Ele deve ser positivo e
ímpar para manter a tela atual em uma célula central exata. Valores possíveis:

- `1`: somente a tela visível;
- `3`: tela visível mais oito vizinhas;
- `5`: tela visível mais 24 vizinhas.

`stream_render_scale` será removido. Não haverá compatibilidade com o significado
antigo, conforme a decisão do projeto de não preservar retrocompatibilidade
nesta fase.

## Proporção real da janela

`VisibleSectorProjection` usará a proporção real da viewport para calcular a
largura visível. O limite seguro continuará configurável:

```text
stream_min_aspect_ratio = 0.25
stream_max_aspect_ratio = 4.0
```

Isso cobre telas de retrato estreitas e formatos ultrawide de até `4:1`, sem
permitir que uma dimensão degenerada produza uma cobertura ilimitada.

## Projeção

`visible_radii(orthographic_size, aspect_ratio)` continuará calculando a tela
central com escala linear `1.0`.

`load_radii(orthographic_size, aspect_ratio)` usará a mesma função geométrica,
mas com escala linear igual a `stream_viewport_grid_size`. Não haverá
interpolação baseada no progresso do zoom.

Os raios ampliados continuarão sendo, componente a componente, no mínimo iguais
aos raios visíveis.

## Ordem de carregamento

O `PrioritizedSectorIterator` existente continuará válido:

1. carrega todos os setores da tela central;
2. carrega os setores das oito áreas externas;
3. ignora coordenadas repetidas entre as fases;
4. mantém enumeração lazy e determinística.

O limite `stream_max_pending_sectors = 256` e o orçamento atual de processamento
permanecem inalterados nesta mudança. O objetivo desta fase é corrigir a área
final solicitada; otimizações adicionais de vazão poderão ser medidas depois
sobre a cobertura correta.

## Exemplo no zoom máximo de produção

Com viewport `1920 × 1080`, zoom `100`, setor de tamanho `40` e margem zero:

- proporção: `16:9`;
- raios visíveis: `(3, 2)`;
- setores da tela central: `7 × 5 = 35`;
- raios carregados: `(7, 4)`;
- cobertura carregada: `15 × 9 = 135` setores.

O modelo anterior chegava a solicitar `63.001` setores no antigo zoom `1000`
porque aplicava escala linear `10` sobre uma área limitada artificialmente a
uma proporção quadrada. A nova configuração de produção limita o zoom a `100`
e representa corretamente o grid de telas.

## Componentes afetados

### `GameSettings`

- remove `stream_render_scale`;
- adiciona `stream_viewport_grid_size`;
- valida valor positivo e ímpar;
- usa proporção máxima `4.0` na configuração de produção.

### `VisibleSectorProjection`

- remove `_effective_render_scale`;
- calcula cobertura visível com escala `1`;
- calcula cobertura carregada com o tamanho fixo do grid;
- reutiliza `_coverage_radii` para os dois cálculos.

### Streaming e demo

O controller, o iterador priorizado e a demo não ganham uma nova
responsabilidade. Eles recebem os novos raios da projeção através das interfaces
existentes.

## Casos limites

- Viewport com largura ou altura não positiva continua ignorado pelo controller.
- Aspect ratio abaixo de `0.25` ou acima de `4.0` é limitado antes do cálculo.
- Grid par, zero ou negativo torna `GameSettings` inválido.
- Grid `1` produz cobertura carregada igual à visível e nenhuma fase externa.
- O arredondamento nunca pode deixar a cobertura carregada menor que a visível.

## Testes

### Configuração

- valor de produção é `3`;
- valores `0`, negativos e pares são rejeitados;
- valores ímpares positivos são aceitos;
- o campo antigo deixa de fazer parte do recurso.

### Projeção

- zoom `100` e aspecto `16:9` produzem raios visíveis `(3, 2)`;
- o mesmo cenário produz raios carregados `(7, 4)`;
- zooms diferentes preservam a relação de três viewports por eixo antes do
  arredondamento;
- grid `1` iguala os dois raios;
- portrait e ultrawide usam a proporção real dentro dos limites;
- proporções extremas permanecem limitadas.

### Integração

- tela central continua sendo materializada antes das áreas externas;
- cobertura final contém exatamente as coordenadas do retângulo projetado;
- fila pendente permanece limitada;
- mudança de zoom substitui a agenda antiga;
- seed e assinatura dos sistemas permanecem inalterados.

## Critérios de aceitação

- A cobertura representa uma tela central e oito telas vizinhas.
- Largura e altura carregadas equivalem a três viewports antes do arredondamento
  para setores.
- Zoom máximo `100` em `1920 × 1080` solicita `135` setores.
- A área visível é carregada antes do preload.
- Configuração, projeção, streaming, suíte completa, catálogo e smoke headless
  passam sem erros.
