# Zodiakos: painel de debug para streaming ao vivo

**Data:** 2026-07-14

## Objetivo

Permitir que o desenvolvedor ajuste o preload do mapa durante a execução e veja
o efeito imediatamente, sem editar arquivos, reiniciar o jogo ou persistir os
valores depois que a demo for fechada.

O zoom visual da câmera e o zoom usado para calcular o preload serão conceitos
independentes. Assim, a câmera poderá estar em zoom baixo enquanto o streaming
prepara a cobertura equivalente, por exemplo, ao zoom `1000`.

## Escopo

Esta fase adiciona:

- um modo opcional de zoom mínimo fixo para o preload;
- configurações temporárias em uma cópia de `GameSettings`;
- um painel de desenvolvimento aberto por `F3`;
- atualização do streaming durante a execução;
- métricas que mostram o efeito real dos valores escolhidos;
- restauração dos valores que existiam no início da sessão.

Não fazem parte desta fase:

- menu oficial de configurações do jogador;
- persistência em `user://`, banco ou arquivo do projeto;
- alteração automática de `game_settings.tres`;
- geração do universo em GPU;
- cache permanente ou pré-geração de setores sem materialização visual.

## Configuração central

`GameSettings` continuará sendo o único local que declara configurações do
jogo. Serão adicionados os campos:

```gdscript
@export var stream_use_fixed_preload_zoom: bool
@export var stream_fixed_preload_zoom: float
```

Valores padrão:

```text
stream_use_fixed_preload_zoom = false
stream_fixed_preload_zoom = 1000.0
```

O modo desligado preserva o comportamento atual. O valor `1000` estará pronto
para uso, mas só produzirá efeito quando o modo fixo for habilitado durante a
sessão.

`stream_fixed_preload_zoom` deverá ser finito e não negativo. O valor zero é
válido, mas não amplia a cobertura além do zoom visual.

## Regra de projeção

O cálculo da tela central continuará usando sempre o zoom visual atual:

```text
visible_zoom = camera_zoom
```

O zoom efetivo do preload será:

```text
fixed desligado: preload_zoom = camera_zoom
fixed ligado:    preload_zoom = max(camera_zoom, stream_fixed_preload_zoom)
```

Usar o maior valor garante que o preload nunca seja menor que a tela visível,
inclusive se no futuro a câmera puder ultrapassar o valor fixo.

`stream_viewport_grid_size` continuará ampliando a largura e a altura calculadas
a partir do zoom efetivo. Portanto, o zoom de preload e o tamanho do grid são
configurações complementares, não alternativas.

### Exemplo

Com viewport `1920 × 1080`, setor de tamanho `40`, margem zero, grid `3`, câmera
em zoom `30` e preload fixo em `1000`:

- raios visíveis: `(1, 1)`;
- zoom efetivo do preload: `1000`;
- raios carregados: `(67, 38)`;
- alvo total: `135 × 77 = 10.395` setores.

O limite da fila não muda o alvo final. Com `stream_max_pending_sectors = 256`,
somente 256 coordenadas ficam agendadas de cada vez. Com dois setores por frame,
materializar 10.395 setores exige no mínimo 5.198 frames, cerca de 87 segundos a
60 FPS, sem contar o custo de geração e renderização.

## Configuração temporária

Ao criar a demo, `game_settings.tres` será duplicado em memória com
`duplicate(true)`. A câmera, a view, o controller de streaming e o gerador do
universo receberão a mesma cópia temporária por injeção.

O painel alterará somente essa cópia. Nenhuma chamada a `ResourceSaver`,
`ConfigFile` ou escrita no sistema de arquivos será permitida nesse fluxo.

Uma segunda cópia imutável dos valores iniciais da sessão será mantida para o
botão `Restaurar padrões`. Nesse contexto, “padrões” significa o conteúdo
carregado no início daquela execução, não valores codificados no painel.

## Painel de desenvolvimento

O painel será um componente `Control` reutilizável, separado da demo e da lógica
de streaming. Ele será aberto e fechado por `F3` e ficará no canto superior
direito sobre o mapa.

Controles:

- `Preload fixo`: `CheckBox`;
- `Zoom de preload`: `SpinBox` finito e não negativo;
- `Grid de viewports`: `SpinBox` com mínimo 1, passo 2 e valores ímpares;
- `Setores por frame`: `SpinBox` inteiro positivo;
- `Máximo na fila`: `SpinBox` inteiro positivo;
- `Restaurar padrões`: botão.

O painel usará `mouse_filter = STOP` e consumirá os eventos usados por seus
controles, impedindo que a interação simultaneamente mova ou aplique zoom no
mapa.

Alterações numéricas serão emitidas após 150 ms sem novas edições. O debounce
evita reconstruir a agenda para cada dígito digitado, mas mantém a sensação de
atualização imediata. Checkbox e botão serão aplicados imediatamente.

## Métricas ao vivo

O painel mostrará:

- zoom visual da câmera;
- zoom efetivo do preload;
- raios visíveis;
- raios carregados;
- total de setores do alvo carregado;
- setores ativos;
- setores pendentes;
- sistemas solares materializados.

O total do alvo será calculado por:

```text
(2 × load_radius_x + 1) × (2 × load_radius_y + 1)
```

As métricas existentes no canto superior esquerdo continuarão disponíveis. O
novo painel complementa o HUD atual e não altera o significado de `Active` ou
`Systems`.

## Componentes e responsabilidades

### `GameSettings`

- declara os dois novos campos;
- valida o zoom fixo;
- permanece como fonte única da configuração inicial.

### `VisibleSectorProjection`

- calcula o zoom efetivo;
- preserva o zoom visual em `visible_radii`;
- usa o zoom efetivo em `load_radii`;
- garante que a cobertura carregada contenha a cobertura visível.

### `StreamingDebugPanel`

- renderiza controles e métricas;
- aplica limites de entrada;
- emite uma proposta de tuning;
- não conhece a projeção, o gerador ou a view;
- não salva dados.

### `InfiniteStarMapDemo`

- atua como composition root;
- cria e injeta as cópias temporárias de configuração;
- valida propostas antes de aplicá-las;
- conecta o painel ao streaming;
- solicita a atualização de cobertura e métricas.

### `SectorStreamController`

- reconcilia a cobertura após mudança geométrica;
- reconstrói a agenda ao reduzir o limite da fila;
- garante imediatamente `pending.size() <= stream_max_pending_sectors`;
- aplica mudanças em `stream_sectors_per_frame` sem reconstruir a cobertura.

## Fluxo de atualização

1. O usuário altera um controle.
2. O painel emite uma proposta após o debounce aplicável.
3. A demo aplica a proposta em uma duplicata da configuração atual.
4. `GameSettings.validation_errors()` valida o candidato.
5. Se válido, a demo copia os campos aprovados para a configuração da sessão.
6. Mudanças geométricas chamam `_refresh_stream_coverage()`.
7. O controller descarta a agenda antiga e prioriza novamente a tela visível.
8. Mudanças de orçamento atualizam fila e processamento conforme necessário.
9. O painel recebe e exibe o novo snapshot de métricas.

## Tratamento de erros

- Valores inválidos não substituem a última configuração válida.
- O painel mostra uma mensagem curta com o erro de validação.
- Valores pares para o grid são impedidos pelo próprio controle.
- Se uma edição produzir valor não finito, o candidato é rejeitado.
- Dimensões inválidas da viewport continuam ignoradas pelo controller.
- Fechar o painel não interrompe nem restaura o streaming.
- Fechar o jogo descarta toda alteração temporária.

## Testes

### Configuração

- os novos valores de produção são `false` e `1000`;
- zoom fixo negativo, `NAN` ou infinito é rejeitado;
- zero e valores positivos são aceitos;
- os campos de apresentação não alteram a identidade procedural do universo.

### Projeção

- modo desligado acompanha o zoom visual;
- câmera em zoom `30` com fixed `1000` usa `1000` somente no preload;
- câmera acima do valor fixo usa o zoom da câmera;
- grid continua multiplicando o zoom efetivo;
- cobertura carregada nunca fica menor que a visível.

### Painel

- `F3` alterna a visibilidade;
- controles emitem valores válidos;
- grid emite apenas valores ímpares;
- botão restaura o snapshot inicial;
- snapshot atualiza todas as métricas;
- o painel não chama APIs de persistência.

### Integração

- a demo injeta uma única cópia temporária nos componentes;
- alteração de geometria reconstrói a agenda;
- redução do limite pendente tem efeito imediato;
- mudança de setores por frame altera o próximo lote;
- área visível continua sendo priorizada;
- fechar e recriar a demo recupera os valores do recurso original;
- arquivo `game_settings.tres` permanece inalterado durante o teste.

## Critérios de aceitação

- `F3` abre e fecha o painel sem interferir na navegação do mapa.
- É possível ativar preload fixo em `1000` com a câmera em qualquer zoom.
- O efeito aparece nas métricas e na agenda sem reiniciar o jogo.
- A cobertura visível continua sendo carregada primeiro.
- Fila e orçamento respondem aos controles durante a execução.
- `Restaurar padrões` recupera os valores do início da sessão.
- Fechar o jogo descarta todas as alterações do painel.
- Nenhum arquivo é salvo pelo painel.
- Testes focados, suíte completa, catálogo e smoke headless passam.
