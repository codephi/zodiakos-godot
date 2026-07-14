# Zodiakos: minimapa estelar procedural interativo

**Data:** 2026-07-14

## Objetivo

Adicionar um minimapa 2D interativo capaz de observar sistemas estelares dentro
e fora da região carregada pelo mapa 3D. O minimapa deverá navegar pelo universo
procedural determinístico, representar a área visível e o preload atual, e
permitir que um clique duplo mova a câmera principal para uma região distante.

O minimapa não criará meshes, nós 3D ou uma segunda câmera de renderização. Ele
consultará dados do universo e desenhará uma representação 2D com nível de
detalhe adaptativo.

## Decisões aprovadas

- O minimapa pode consultar áreas além do preload do mapa principal.
- Zoom, arrasto e navegação para a câmera principal são interativos.
- Sistemas individuais dão lugar a agrupamentos e densidade em zoom distante.
- A versão compacta permanece no canto inferior direito.
- `M` alterna entre o modo compacto e o expandido.
- O minimapa não compartilha a fila de materialização do streaming 3D.
- Não haverá fog of war nesta fase.

## Fora do escopo

- persistência da posição ou do zoom do minimapa;
- territórios, alianças, fronteiras ou rotas no minimapa;
- seleção e painel de detalhes de um SS pelo minimapa;
- ordens de nave, colonização ou combate pelo minimapa;
- segunda viewport 3D;
- geração procedural em GPU;
- sincronização multiplayer do estado visual do minimapa.

## Arquitetura

### `StellarMinimap`

Componente `Control` responsável por:

- desenhar sistemas, agrupamentos, densidade e sobreposições;
- transformar posições globais do universo em pixels e fazer a transformação
  inversa;
- receber roda, arrasto, clique duplo, botão de centralização e tecla `M`;
- emitir solicitações de bounds e navegação sem conhecer o gerador procedural.

### `MinimapController`

Orquestrador de aplicação responsável por:

- manter centro, altura visível, aspecto e modo de acompanhamento;
- escolher o LOD conforme a quantidade de setores nos bounds;
- iniciar, cancelar e substituir consultas;
- processar orçamento incremental por frame;
- alimentar o componente visual com snapshots imutáveis;
- administrar o cache LRU de setores exatos.

### `MinimapQueryService`

Serviço de dados responsável por:

- consultar sistemas exatos através de `LoadGalaxySector`;
- consultar sistemas científicos em bounds através do repositório SQLite;
- amostrar `GalacticDensityModel` para agrupamentos e heatmap;
- nunca materializar `Node3D`, mesh ou material;
- produzir resultados determinísticos para os mesmos bounds, seed e versão.

### `InfiniteStarMapDemo`

Continua como composition root:

- fornece o mesmo repositório científico aberto;
- cria o gerador e o `LoadGalaxySector` usados pelas consultas exatas;
- conecta a posição da câmera e os raios do stream ao minimapa;
- converte uma navegação solicitada em `UniversePosition`;
- move a câmera principal através de `set_logical_position`.

## Modelo de coordenadas

A posição global 2D de um SS será:

```text
global = Vector2(sector.x, sector.y) × universe_sector_size + local_position
```

O minimapa mantém:

- `center_global`: centro em coordenadas do universo;
- `view_height`: altura global representada;
- `aspect_ratio`: largura do painel dividida pela altura;
- `view_width = view_height × aspect_ratio`.

Para um retângulo interno de desenho `R`, a transformação global para pixel é:

```text
normalized = (global - bounds.position) / bounds.size
pixel = R.position + normalized × R.size
```

A transformação inversa usa a mesma normalização. As duas operações deverão ser
testadas como inversas dentro de tolerância de ponto flutuante.

Uma posição global escolhida no minimapa será convertida para o mapa principal
com:

```gdscript
UniversePosition.new(
    SectorCoordinate.new(),
    target_global,
    universe_sector_size
)
```

O próprio `UniversePosition` normaliza setor e posição local, inclusive para
coordenadas negativas.

## Estado de acompanhamento

O minimapa inicia seguindo a câmera principal:

```text
follow_main_camera = true
```

- Mover a câmera principal atualiza `center_global` enquanto follow estiver
  ativo.
- Arrastar o minimapa define `follow_main_camera = false`.
- Usar o botão de centralização restaura o centro da câmera e reativa follow.
- Clicar duas vezes move a câmera principal para o alvo e reativa follow.
- Expandir ou recolher não altera o centro, zoom ou estado de follow.

## Interface

### Modo compacto

- tamanho: `320 × 220` pixels;
- canto inferior direito;
- sempre visível;
- moldura, título curto, indicador de LOD e estado de carregamento;
- botão para centralizar na câmera principal.

### Modo expandido

- ocupa 70% da largura e 70% da altura da viewport;
- centralizado na tela;
- preserva os mesmos dados, centro e zoom;
- ativado e desativado por `M`.

### Interações

- roda do mouse: zoom ancorado na posição atual do cursor;
- botão esquerdo arrastado: move o centro do minimapa;
- clique duplo com botão esquerdo: solicita navegação da câmera principal;
- botão de centralização: retorna à câmera principal;
- `M`: alterna compacto/expandido;
- todos os eventos do painel são consumidos para não mover ou aplicar zoom no
  mapa 3D simultaneamente.

## Representação visual

- SS exato procedural: círculo preenchido com a cor de `visual_type`.
- SS científico: círculo com contorno branco e preenchimento do tipo visual
  padrão enquanto não houver estilo científico específico.
- Agrupamento intermediário: círculo cujo raio e intensidade representam a
  contagem estimada.
- Densidade distante: células retangulares com intensidade baseada em
  `GalacticDensityModel.density_at`.
- Área visível da câmera principal: retângulo azul.
- Área de setores carregados pelo streaming 3D: retângulo laranja.
- Centro independente do minimapa: cruz discreta.

Pontos e células fora do retângulo interno de desenho serão recortados pelo
`Control`. O minimapa usará `_draw`, `draw_circle`, `draw_rect` e linhas 2D; não
usará `SubViewport`.

## Níveis de detalhe

O LOD será escolhido pelo número de setores que intersectam os bounds atuais.
O cálculo usa `floor` no início, `ceil` no fim e inclui setores que tocam a área
visível.

### LOD exato

Condição:

```text
sector_count <= minimap_exact_sector_limit
```

Valor inicial do limite: `256`.

- enumera setores de forma lazy, priorizando o centro;
- obtém `UniverseSector` através de `LoadGalaxySector`;
- desenha todos os sistemas resolvidos, científicos e procedurais;
- usa até `minimap_query_sectors_per_frame` consultas por frame;
- reutiliza setores armazenados no cache.

### LOD de agrupamentos

Condição:

```text
256 < sector_count <= minimap_cluster_sector_limit
```

Valor inicial do limite: `4096`.

- não enumera os sistemas de todos os setores;
- divide os bounds em uma grade de células;
- usa `minimap_cluster_grid_resolution` células por eixo;
- estima a contagem usando densidade, área em setores e
  `galaxy_max_candidate_systems_per_sector`;
- desenha um círculo por célula não vazia;
- sobrepõe sistemas científicos retornados por uma consulta única dos bounds.

Contagens de agrupamentos são explicitamente estimativas visuais e não alteram
estado de jogo.

### LOD de densidade

Condição:

```text
sector_count > minimap_cluster_sector_limit
```

- usa uma grade de resolução fixa;
- amostra o modelo de densidade no centro de cada célula;
- desenha heatmap sem enumerar setores ou SS procedurais;
- sobrepõe sistemas científicos catalogados dentro dos bounds;
- limita o trabalho por frame através de orçamento de células.

## Sistemas científicos

Nos LODs de agrupamento e densidade, o repositório será consultado uma única vez
por geração de bounds através de `systems_in_bounds(bounds)`. Sistemas
catalogados ficam visíveis como pontos individuais mesmo quando os procedurais
estão agregados.

No LOD exato, os sistemas científicos já vêm resolvidos em cada
`UniverseSector` e não serão desenhados novamente pela sobreposição.

## Consultas incrementais e cancelamento

Cada consulta recebe um `generation_id` monotônico.

1. Mudança relevante de bounds ou LOD incrementa o id.
2. Trabalho pendente mantém o id com o qual foi criado.
3. Resultados cujo id não corresponde ao atual são descartados.
4. A fila anterior é liberada sem alterar a fila do `SectorStreamController`.
5. O snapshot visual permanece válido até o primeiro resultado da nova geração,
   evitando piscar uma tela vazia durante movimentos pequenos.

Arrasto contínuo e zoom usam debounce de 100 ms antes de iniciar uma nova
consulta pesada. A moldura da câmera e a transformação do painel respondem
imediatamente; somente os dados são substituídos após o debounce.

## Cache exato

O cache LRU será indexado por:

```text
universe_identity + generator_version + sector_coordinate
```

Valor inicial:

```text
minimap_cache_sector_limit = 512
```

- hit retorna o `UniverseSector` sem nova consulta SQLite/procedural;
- acesso atualiza a recência;
- ao ultrapassar o limite, remove primeiro o setor menos recente;
- cache zero será inválido;
- mudar identidade ou versão cria chaves diferentes;
- o cache existe apenas durante a sessão.

## Configuração central

Todos os campos serão declarados em `GameSettings` sob a categoria `Minimap`:

```gdscript
@export var minimap_compact_size: Vector2
@export var minimap_expanded_screen_ratio: float
@export var minimap_initial_view_scale: float
@export var minimap_zoom_factor: float
@export var minimap_min_view_height: float
@export var minimap_max_view_height: float
@export var minimap_exact_sector_limit: int
@export var minimap_cluster_sector_limit: int
@export var minimap_query_sectors_per_frame: int
@export var minimap_cluster_grid_resolution: int
@export var minimap_density_grid_resolution: int
@export var minimap_density_cells_per_frame: int
@export var minimap_cache_sector_limit: int
@export var minimap_query_debounce_seconds: float
```

Valores iniciais:

```text
minimap_compact_size = Vector2(320, 220)
minimap_expanded_screen_ratio = 0.7
minimap_initial_view_scale = 9.0
minimap_zoom_factor = 0.8
minimap_min_view_height = 40.0
minimap_max_view_height = 120000.0
minimap_exact_sector_limit = 256
minimap_cluster_sector_limit = 4096
minimap_query_sectors_per_frame = 8
minimap_cluster_grid_resolution = 24
minimap_density_grid_resolution = 64
minimap_density_cells_per_frame = 128
minimap_cache_sector_limit = 512
minimap_query_debounce_seconds = 0.1
```

`view_height` inicial será o maior valor entre:

```text
camera_zoom × minimap_initial_view_scale
loaded_sector_height × 1.1
```

`loaded_sector_height` será calculado com os raios atuais do streaming. Assim,
o retângulo laranja de preload começa inteiramente enquadrado mesmo quando o
preload fixo está muito acima do zoom visual. O resultado será limitado ao
intervalo configurado.

Validações:

- tamanhos e alturas devem ser finitos e positivos;
- proporção expandida deve satisfazer `0 < value <= 1`;
- `minimap_zoom_factor` deve satisfazer `0 < value < 1`;
- limite exato deve ser positivo e menor que o limite de agrupamentos;
- orçamentos, resoluções de agrupamento/densidade e cache devem ser positivos;
- debounce deve ser finito e não negativo;
- altura mínima deve ser menor ou igual à máxima.

Esses campos são apenas de apresentação e não participam da identidade ou da
seed do universo.

## Fluxo de dados

1. A demo cria query service, controller e componente visual.
2. O controller recebe o centro da câmera e calcula bounds iniciais.
3. O controller escolhe o LOD e cria uma nova geração de consulta.
4. O serviço processa setores ou células dentro do orçamento do frame.
5. O controller agrega resultados em um snapshot.
6. O minimapa recebe o snapshot, chama `queue_redraw` e desenha.
7. Movimento e zoom atualizam bounds e substituem consultas obsoletas.
8. Clique duplo emite uma posição global.
9. A demo converte a posição e chama `map_camera.set_logical_position`.
10. O streaming 3D reage normalmente à nova posição da câmera.

## Tratamento de erros

- Bounds vazios ou não finitos não iniciam consultas.
- Viewport com dimensão não positiva mantém o último snapshot válido.
- Repositório ou metadata inválidos mostram `MINIMAP_UNAVAILABLE`.
- Consulta científica vazia não impede densidade ou procedurais.
- Resultados obsoletos são descartados sem alterar o snapshot atual.
- Um setor que falha não interrompe os demais; o contador de erros aparece no
  status do minimapa.
- Zoom é sempre limitado às alturas mínima e máxima.
- O controle continua navegável enquanto a nova consulta carrega.

## Testes

### Coordenadas

- global para pixel e pixel para global são operações inversas;
- coordenadas negativas normalizam corretamente;
- zoom ancorado preserva o ponto sob o cursor;
- resize mantém centro e altura.

### LOD

- 256 setores selecionam exato;
- 257 setores selecionam agrupamentos;
- 4096 setores permanecem em agrupamentos;
- 4097 setores selecionam densidade;
- agrupamentos e densidade são determinísticos;
- sistemas científicos aparecem nos três modos sem duplicação.

### Consulta e cache

- limite de oito setores por frame é respeitado;
- limite de 128 células por frame é respeitado;
- geração antiga não publica resultados;
- cache hit evita nova geração de setor;
- LRU remove o item menos recente ao atingir 513 entradas;
- cache nunca altera o stream principal.

### Interface

- inicia compacta em `320 × 220`;
- `M` alterna o modo expandido;
- roda aplica zoom no cursor;
- arrasto desativa follow;
- botão centraliza e reativa follow;
- clique duplo emite a posição global correta;
- eventos consumidos não chegam à câmera principal;
- retângulos visível e de preload usam posições e tamanhos corretos.

### Integração

- demo compõe os três novos componentes;
- câmera movimenta a moldura em follow;
- clique duplo move a câmera e o stream principal;
- minimapa consulta fora dos setores ativos;
- fechar a demo libera consultas e cache;
- seed, identidade e sistemas gerados permanecem inalterados.

## Critérios de aceitação

- O minimapa compacto aparece no canto inferior direito.
- `M` alterna para uma visualização expandida de 70% da tela.
- É possível observar regiões fora do preload sem criar meshes 3D.
- Até 256 setores exibem SS procedurais e científicos exatos.
- Zoom distante usa agrupamentos ou densidade sem enumerar todos os setores.
- Sistemas científicos permanecem identificáveis em todos os LODs.
- Área visível e área de preload do mapa principal são claramente diferentes.
- Arrasto, zoom e clique duplo não interferem acidentalmente no mapa principal.
- Clique duplo recentraliza a câmera principal na região escolhida.
- Consultas são incrementais, canceláveis, determinísticas e limitadas.
- O streaming 3D mantém sua própria fila, orçamento e contadores.
- Nenhuma configuração ou posição do minimapa é persistida.
- Suíte completa, catálogo e smoke headless passam.
