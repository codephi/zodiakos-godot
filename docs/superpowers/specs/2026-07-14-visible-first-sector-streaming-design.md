# Zodiakos: streaming de setores com prioridade para a área visível

**Data:** 2026-07-14

## Objetivo

Carregar todos os setores estelares da área visível antes de iniciar o
precarregamento externo definido por `stream_render_scale`.

A alteração modifica somente a ordem de enumeração e materialização. Seed,
conteúdo dos sistemas, cobertura final, limite da fila e orçamento por frame
permanecem iguais.

## Problema atual

`SectorStreamController` usa um único `SectorRingIterator` com os raios finais
ampliados. A enumeração começa no centro, mas os anéis quadrados podem incluir
setores externos enquanto ainda existem setores visíveis aguardando carga,
especialmente em viewports retangulares.

Isso permite gastar o orçamento de geração em conteúdo fora da tela antes de
completar o mapa que o jogador está observando.

## Regra de prioridade

O streaming terá duas fases estritamente ordenadas:

1. **Visível:** enumera do centro para as bordas todos os setores da cobertura
   do viewport sem ampliação.
2. **Externa:** enumera a cobertura ampliada do centro para fora, descartando
   coordenadas que pertencem à cobertura visível.

Nenhuma coordenada externa pode ser adicionada a `pending` enquanto a fase
visível ainda tiver uma coordenada não examinada. Coordenadas já ativas ou já
enfileiradas continuam sendo ignoradas sem quebrar essa regra.

Quando `stream_render_scale` efetivo for `1.0`, a fase externa ficará vazia.

## Projeção da cobertura

`VisibleSectorProjection` passará a produzir dois raios para a mesma câmera e
viewport:

- `visible_radii`: cobertura com escala `1.0`;
- `load_radii`: cobertura com a escala adaptativa já existente.

Os dois cálculos reutilizam o mesmo tamanho de setor, margens e limites seguros
de proporção já configurados. Para garantir que a cobertura final sempre
contenha a prioritária, cada componente de `load_radii` será no mínimo o
componente correspondente de `visible_radii`.

Não será adicionada uma nova configuração ao Inspector. O
`stream_render_scale` continuará controlando apenas quanto conteúdo externo será
precarregado.

## Iteração lazy em duas fases

Será criado um iterador de cobertura priorizada, independente de Godot UI e da
árvore de cenas. Ele compõe dois `SectorRingIterator`:

- o primeiro recebe `visible_radii`;
- o segundo recebe `load_radii` e ignora coordenadas dentro de
  `visible_radii`.

Interface pública:

```gdscript
next_coordinate() # SectorCoordinate ou null quando esgotado
is_exhausted() -> bool
```

O iterador não cria a lista completa, não ordena arrays e mantém somente o
estado escalar dos dois iteradores. A ordem dentro de cada fase continua sendo
determinística: distância de Chebyshev, `y` e depois `x`.

## Integração no controller

`SectorStreamController` armazenará `visible_radii` além de `load_radii` e
`unload_radii`.

Em mudança de centro, zoom ou cobertura:

1. recalcula os raios visíveis e ampliados;
2. limpa a agenda antiga quando qualquer raio efetivo mudar;
3. cria o iterador priorizado com uma cópia do centro;
4. preenche `pending` até `stream_max_pending_sectors`;
5. materializa no máximo `stream_sectors_per_frame`;
6. repõe a fila sem ultrapassar o limite;
7. descarrega setores fora de `unload_radii`.

Uma atualização idêntica de viewport preserva o progresso do iterador e da
fila. Mudança de centro ou de raios substitui coordenadas pendentes antigas.

## Limites e desempenho

- `pending.size()` permanece limitado a 256 na configuração atual.
- Cada preenchimento examina no máximo o limite configurado de candidatos.
- O iterador continua lazy mesmo na cobertura de 63.001 setores do zoom máximo.
- A geração continua síncrona e limitada por frame nesta fase.
- Não haverá alteração em SQLite, geração procedural, LOD, GPU ou threads.

## Tratamento de casos limites

- Centro nulo ou raios negativos continuam inválidos por asserção.
- `visible_radii` será limitado componente a componente por `load_radii`.
- Viewport com dimensão não positiva será ignorado sem reiniciar a agenda.
- Exaustão retorna `null` de forma estável.
- Setores ativos não serão gerados novamente.

## Testes

### Projeção

- calcula cobertura visível sem ampliação;
- cobertura ampliada contém a visível;
- escala efetiva `1.0` produz raios iguais;
- mantém proteção para viewport inválido e proporções extremas.

### Iterador priorizado

- emite toda a área visível antes da primeira coordenada externa;
- preserva ordem centro-primeiro em cada fase;
- não repete coordenadas entre as fases;
- produz exatamente a quantidade da cobertura ampliada;
- funciona com raios retangulares, zero e fases iguais;
- mantém exaustão estável e cópia defensiva do centro.

### Controller

- a fila inicial contém somente setores visíveis quando eles ocupam o limite;
- o primeiro setor externo só é materializado após todos os visíveis;
- limite de pendências e orçamento por frame permanecem válidos;
- mudança de câmera descarta a agenda antiga;
- atualização idêntica preserva o progresso;
- cobertura final e descarregamento permanecem inalterados.

## Critérios de aceitação

- Nenhum setor externo é materializado antes de todos os setores visíveis.
- A enumeração permanece lazy, determinística e limitada em memória.
- `stream_render_scale` continua definindo a cobertura final externa.
- Seed e conteúdo de cada sistema permanecem inalterados.
- Testes focados, suíte completa, validação do catálogo e smoke headless passam.
