# Zodiakos: streaming galáctico adaptativo e geração lazy de sistemas estelares

## 1. Objetivo

Esta especificação define como Zodiakos manterá a navegação fluida em toda a
escala da Via Láctea sem gerar, carregar ou renderizar individualmente todos os
sistemas estelares visíveis no zoom distante.

O desenho combina:

- LOD galáctico em três níveis;
- renderização de estrelas com `MultiMesh`;
- fila incremental e limitada de setores;
- geração canônica em workers de CPU;
- cache LRU somente em memória;
- composição completa de sistemas estelares sob demanda;
- perfis Automático, Baixo, Médio, Alto e Ultra;
- configuração central editável pelo Inspector do Godot.

A GPU será usada para desenhar grandes quantidades de pontos e efeitos. Seed,
IDs, posições, nomes, catálogo e composição dos sistemas continuam sendo
determinados no CPU. Compute shaders não fazem parte desta fase.

## 2. Contexto e problema atual

O mapa atual calcula o retângulo completo de setores visíveis, materializa uma
lista com todas as coordenadas, ordena essa lista e processa uma quantidade fixa
por frame. Cada sistema visível também cria uma hierarquia própria de nós e
meshes.

Com os valores atuais:

- zoom ortográfico máximo: `30000`;
- tamanho do setor: `40`;
- aspecto aproximado: `16:9`;
- margem de carga: `1`.

O retângulo calculado pode alcançar aproximadamente `1.006.761` setores. Mesmo
que muitos estejam fora da densidade útil da galáxia, criar e ordenar essa fila
já é um custo inadequado. Gerar dois setores por frame também tornaria impossível
preencher essa visualização em tempo útil.

A composição completa de um sistema procedural possui no máximo três estrelas,
doze planetas, quarenta e oito luas e oito corpos menores. Criar uma composição
isolada é barato. O risco de escala surge quando o jogo tenta criar composições
ou nós visuais para milhares de sistemas que o jogador não consultou.

## 3. Relação com especificações existentes

Esta especificação estende:

- [arquitetura hexagonal orientada a eventos](2026-07-12-event-driven-hexagonal-architecture-design.md);
- [catálogo científico SQLite e galáxia procedural](2026-07-13-scientific-catalog-procedural-galaxy-design.md);
- [zoom estendido](2026-07-13-extended-map-zoom-design.md).

Permanecem válidos:

- uma única Via Láctea finita;
- SQLite como fonte de verdade científica;
- catálogo aberto somente para leitura;
- sistemas procedurais reconstruíveis por identidade do universo;
- mapa jogável no plano `x,y`;
- origem flutuante por setor;
- domínio independente da árvore de cenas;
- ausência de retrocompatibilidade entre versões do gerador nesta fase.

Esta especificação substitui o comportamento de criar e ordenar todo o retângulo
de setores visíveis e a estratégia de um conjunto de nós Godot por estrela.

## 4. Decisões aprovadas

- O pipeline completo será otimizado, incluindo mapa e composição dos sistemas.
- O zoom distante é agregado e não permite selecionar sistemas individuais.
- A composição completa de um sistema só é criada quando uma regra de gameplay
  ou uma interação realmente precisar dela.
- O cache da demo é limitado, LRU, somente em memória e descartado ao fechar.
- O universo canônico não depende do perfil de desempenho.
- A renderização usa GPU por `MultiMesh` e shaders normais.
- A geração canônica usa CPU e `WorkerThreadPool`.
- O renderer continua sendo Compatibility.
- Compute shaders ficam fora desta fase.
- O usuário escolhe Automático, Baixo, Médio, Alto ou Ultra.
- Todos os valores-base dos perfis ficam em `game_settings.tres` e são editáveis
  pelo Inspector.
- A preferência do jogador fica em `user://performance_settings.cfg` e não
  modifica o recurso do projeto.
- O modo Automático começa em Médio e busca 60 FPS por padrão.

## 5. Invariantes canônicos

Os itens abaixo devem ser idênticos em todos os perfis, em qualquer ordem de
requisição e em qualquer quantidade de workers:

- identidade e versão do universo;
- IDs de setores, sistemas e corpos;
- posições dos sistemas;
- designações e nomes procedurais;
- quantidade e tipos de estrelas, planetas, luas e corpos menores;
- relações de parentesco e órbitas;
- precedência de sistemas catalogados;
- conteúdo científico retornado pelo SQLite.

Configurações de apresentação e desempenho nunca entram no cálculo de
`UniverseIdentity`. Alterar um perfil não cria outra galáxia e não invalida
caches por conteúdo; apenas muda o conjunto visível e os limites de memória.

## 6. Arquitetura

```text
Preferência do jogador     game_settings.tres
          |                        |
          +---- PerformanceProfileService
                              |
Câmera ---------------- GalaxyLodPolicy
                              |
                    SectorRequestScheduler
                      |                 |
                  SectorCache      AsyncSectorGenerator
                      |                 |
                      +------ resultados canônicos
                                      |
                +---------------------+--------------------+
                |                                          |
       MultiMeshStarFieldView                    GalaxyOverviewView
                |
       SystemPickingIndex
                |
       LoadSystemComposition
          |              |
CatalogRuntimeSnapshot   ProceduralSystemFactory
          |              |
          +---- SystemCompositionCache
```

### 6.1 `PerformanceProfile`

Recurso tipado e somente de configuração. Define os orçamentos de um nível de
qualidade. Instâncias Baixo, Médio, Alto e Ultra ficam embutidas como subrecursos
do mesmo `game_settings.tres`, preservando um único ponto de edição no Inspector.

Campos mínimos:

- `profile_id`;
- `detail_max_zoom`;
- `cluster_max_zoom`;
- `lod_hysteresis_ratio`;
- `max_detailed_sectors`;
- `max_pending_requests`;
- `max_concurrent_jobs`;
- `main_thread_budget_ms`;
- `sector_cache_capacity`;
- `composition_cache_capacity`;
- `cluster_point_budget`;
- `star_mesh_quality`;
- `effects_enabled`.

### 6.2 `PerformanceProfileService`

Resolve o perfil solicitado pelo usuário e o perfil efetivo. Em modo fixo, os
dois são iguais. Em Automático, o perfil solicitado é `auto` e o perfil efetivo
varia entre Baixo e Ultra.

Responsabilidades:

- carregar a preferência do jogador;
- aplicar fallback seguro para preferência ausente ou inválida;
- publicar alteração do perfil efetivo;
- nunca reescrever `game_settings.tres`;
- nunca alterar configurações canônicas da geração.

### 6.3 `GalaxyLodPolicy`

Função pura que recebe zoom e perfil efetivo e retorna um dos níveis:

- `overview`;
- `cluster`;
- `detail`.

A política usa histerese. A entrada em um nível e a saída dele possuem limites
diferentes, impedindo alternância repetida quando o zoom permanece próximo da
fronteira.

### 6.4 `SectorRequestScheduler`

Mantém uma fila limitada, incremental e priorizada. Não cria o retângulo completo
de coordenadas nem ordena milhões de itens.

Responsabilidades:

- percorrer coordenadas em anéis a partir do centro;
- manter no máximo `max_pending_requests`;
- priorizar menor distância da câmera;
- não duplicar coordenadas ativas, cacheadas, pendentes ou em execução;
- atribuir uma época a cada estado de câmera/LOD;
- cancelar logicamente pedidos que deixaram de ser relevantes;
- descartar resultados de épocas antigas;
- respeitar `max_detailed_sectors` mesmo se a projeção geométrica for maior.

### 6.5 `AsyncSectorGenerator`

Executa trabalhos no `WorkerThreadPool`. Cada trabalho recebe somente snapshots
imutáveis e produz dados de domínio. Workers não adicionam nós, não modificam
`MultiMesh`, não acessam a árvore de cenas e não compartilham uma conexão SQLite.

O resultado é entregue a uma fila de conclusão pertencente à thread principal.
Toda tarefa do `WorkerThreadPool` deve ser aguardada ou finalizada pelo serviço
antes de liberar seus recursos.

### 6.6 `CatalogRuntimeSnapshot`

O SQLite continua sendo a fonte única dos objetos científicos. Durante a tela de
inicialização, o jogo:

1. abre o banco em modo somente leitura;
2. valida esquema, metadados e integridade;
3. carrega anchors e composições catalogadas em um snapshot imutável;
4. constrói um índice espacial de anchors;
5. fecha a conexão depois que o snapshot estiver completo.

Nenhum dado parcial é publicado. Essa estratégia evita compartilhar o plugin
SQLite entre workers e remove consultas do caminho crítico de navegação. Uma
futura paginação de catálogos muito maiores exigirá outra especificação.

### 6.7 `SectorCache`

Cache LRU pertencente à thread principal.

```text
chave = UniverseIdentity + SectorCoordinate
valor = UniverseSector
```

Leitura promove a entrada para a posição mais recente. Inserção acima da
capacidade remove as entradas menos recentes. Reduzir o perfil pode provocar
evicção imediata até o novo limite. Capacidade zero desabilita o cache sem mudar
o resultado canônico.

### 6.8 `SystemCompositionCache`

Cache LRU de composições completas.

```text
procedural = UniverseIdentity + system_id
catálogo   = catalog_version + system_id
```

Solicitações simultâneas para a mesma chave compartilham um único trabalho em
execução. Uma falha ou resultado parcial nunca entra no cache. Resultados
procedurais são descartáveis e nunca são gravados no SQLite.

### 6.9 `MultiMeshStarFieldView`

Substitui o conjunto de nós por estrela. Mantém lotes por tipo visual para o
conjunto detalhado ativo. Transform, escala e cor são dados de instância.

O adaptador mantém tabelas paralelas:

```text
visual_type + instance_index -> system_id
system_id -> visual_type + instance_index
```

Alterações de buffer são acumuladas e aplicadas na thread principal dentro de
`main_thread_budget_ms`. Anéis de seleção, fronteiras e outros overlays raros
podem usar lotes próprios; não reintroduzem um nó permanente por sistema.

### 6.10 `GalaxyOverviewView`

Renderiza os níveis `overview` e `cluster` sem materializar setores canônicos.
Usa o modelo de densidade da galáxia e pontos agregados determinísticos apenas
para apresentação.

Pontos agregados:

- não possuem `system_id`;
- não entram em caches canônicos;
- não podem ser selecionados;
- não criam composição de sistema;
- respeitam `cluster_point_budget`.

### 6.11 `SystemPickingIndex`

Índice espacial CPU apenas dos sistemas reais do LOD detalhado. A seleção projeta
o cursor no plano, busca o sistema mais próximo dentro da tolerância configurada
em pixels e retorna o ID. A seleção não depende de collider ou nó individual.

## 7. Níveis de detalhe

### 7.1 Visão galáctica

- Ativa acima de `cluster_max_zoom`.
- Mostra disco, bojo, barra, braços e halo agregados.
- Não solicita setores detalhados.
- Não cria composições.
- Não permite seleção individual.

### 7.2 Visão de agrupamentos

- Ativa entre `detail_max_zoom` e `cluster_max_zoom`.
- Mostra concentrações por macrorregião.
- Usa `MultiMesh` e um orçamento visual fixo.
- Não materializa cada sistema.
- Não permite seleção individual.

### 7.3 Visão detalhada

- Ativa abaixo de `detail_max_zoom`.
- Solicita setores canônicos próximos da câmera.
- Exibe sistemas reais por `MultiMesh`.
- Mantém índice de seleção.
- Cria composição completa somente sob demanda.

Durante uma transição, a visualização anterior permanece até a nova possuir dados
suficientes para ser apresentada. A transição não cria nem remove estado de
gameplay.

## 8. Geração lazy de sistemas estelares

O ponto do mapa contém apenas a definição do sistema: ID, origem, posição, estilo
visual e versão. Planetas, luas e órbitas não são necessários para desenhar esse
ponto.

A composição completa será solicitada quando ocorrer uma destas ações:

- seleção que abre o painel do sistema;
- início de expedição;
- colonização;
- combate ou regra futura que precise dos corpos internos;
- simulação de servidor que precise daquele sistema.

Fluxo procedural:

```text
system_id
  -> SystemCompositionCache
  -> trabalho já em andamento?
  -> ProceduralSystemFactory no worker
  -> resultado canônico
  -> cache
  -> consumidor atual, se ainda interessado
```

Fluxo catalogado:

```text
system_id
  -> SystemCompositionCache
  -> CatalogRuntimeSnapshot
  -> composição científica exata
  -> cache
  -> consumidor atual
```

Selecionar outro sistema não cancela a validade canônica de um trabalho anterior.
O resultado anterior pode entrar no cache, mas não pode substituir o painel da
seleção atual.

## 9. Perfis e modo Automático

### 9.1 Defaults iniciais

| Valor | Baixo | Médio | Alto | Ultra |
|---|---:|---:|---:|---:|
| `detail_max_zoom` | 240 | 400 | 600 | 900 |
| `cluster_max_zoom` | 4000 | 6000 | 10000 | 15000 |
| `max_detailed_sectors` | 128 | 256 | 512 | 1024 |
| `max_pending_requests` | 32 | 64 | 128 | 256 |
| `max_concurrent_jobs` | 1 | 2 | 3 | 4 |
| `main_thread_budget_ms` | 1.0 | 1.5 | 2.0 | 3.0 |
| `sector_cache_capacity` | 64 | 128 | 256 | 512 |
| `composition_cache_capacity` | 32 | 64 | 128 | 256 |
| `cluster_point_budget` | 25000 | 50000 | 100000 | 200000 |

Todos os valores são defaults editáveis pelo Inspector e devem ser validados.
`detail_max_zoom` deve ser menor que `cluster_max_zoom`; capacidades e orçamentos
não podem ser negativos; trabalhos simultâneos devem ser pelo menos um.

### 9.2 Controle automático

Defaults:

- perfil efetivo inicial: Médio;
- meta: 60 FPS;
- janela de amostragem: 2 segundos;
- rebaixar após 3 segundos persistentes abaixo da meta;
- elevar após 10 segundos com custo de trabalho abaixo de 85% do orçamento da meta;
- cooldown após mudança: 5 segundos;
- mudanças: um nível por vez.

O controlador usa tempo de trabalho médio e percentil 95, excluindo espera de
VSync ou limitação artificial de FPS. Assim, uma tela limitada a 60 Hz ainda pode
demonstrar folga para elevar o perfil. Ele não reage durante a tela de
carregamento, janela sem foco ou pausa do jogo. Baixo e Ultra são limites
absolutos. Alterar o perfil efetivo não reescreve a preferência do usuário.

## 10. Configuração central e preferência do jogador

`game_settings.gd` declara campos tipados para:

- quatro `PerformanceProfile` embutidos;
- perfil padrão do jogador;
- meta e tempos do modo Automático;
- tolerância de seleção em pixels;
- quantidade máxima de conclusões aplicadas por frame;
- ativação das métricas de desenvolvimento.

`game_settings.tres` contém todos os valores de produção. Nenhum adaptador define
defaults duplicados.

A preferência do jogador usa:

```text
user://performance_settings.cfg
```

Formato lógico:

```ini
[performance]
profile="auto"
```

Valores aceitos: `auto`, `low`, `medium`, `high`, `ultra`. Arquivo ausente,
ilegível ou com valor desconhecido usa o default do Inspector sem impedir a
inicialização.

A interface mínima possui:

- seletor de qualidade;
- indicação do nível efetivo no modo Automático;
- aplicar;
- restaurar padrão.

## 11. Concorrência e ciclo de vida

- Caches, scheduler e visualização pertencem à thread principal.
- Workers recebem apenas cópias ou objetos imutáveis.
- Workers não alteram Arrays ou Dictionaries compartilhados.
- Resultados entram em uma fila protegida e são consumidos na thread principal.
- Cada resultado contém chave, época, identidade e status.
- Resultado cuja identidade não corresponde à sessão atual é descartado.
- Resultado cuja época deixou de ser relevante pode alimentar o cache, mas não a
  visualização atual.
- Ao fechar a cena, o serviço deixa de aceitar tarefas, aguarda as tarefas já
  registradas e então libera caches e filas.
- Nenhum callback pode acessar nós depois da saída da árvore.

## 12. Tratamento de falhas

### 12.1 Catálogo

- Falha de abertura ou validação bloqueia a inicialização do mapa.
- Snapshot incompleto é descartado integralmente.
- Sistema catalogado ausente retorna erro explícito.
- Nunca existe fallback procedural para ID catalogado.

### 12.2 Geração procedural

- Falha não publica setor ou composição parcial.
- Uma solicitação relevante pode ser repetida uma vez.
- Segunda falha registra erro e libera a chave em execução.
- Cancelamento lógico não é erro.

### 12.3 Configuração

- `game_settings.tres` inválido falha cedo com diagnóstico agregado.
- Preferência do jogador inválida usa o default válido do projeto.
- Perfil Automático nunca seleciona um recurso inválido.

### 12.4 Apresentação

- Enquanto um SS carrega, o painel mostra estado de carregamento.
- Resultado atrasado não substitui uma seleção mais recente.
- Falha visual não altera caches canônicos.

## 13. Observabilidade

O HUD de desenvolvimento pode mostrar:

- perfil solicitado e efetivo;
- LOD atual;
- FPS médio e percentil 95 do frame;
- tamanho da fila e trabalhos ativos;
- gerações concluídas e descartadas;
- tempo médio e percentil 95 de setor e composição;
- acertos, falhas e evicções dos dois caches;
- sistemas reais e pontos agregados visíveis;
- tempo da thread principal gasto aplicando resultados.

As métricas não fazem parte da identidade do universo e podem ser desativadas sem
alterar comportamento canônico.

## 14. Estratégia de testes

### 14.1 Unidade

- seleção de LOD nos limites;
- histerese de entrada e saída;
- validação dos perfis;
- fila incremental limitada;
- prioridade centro-borda;
- deduplicação de solicitações;
- mudança de época e descarte de resultado antigo;
- LRU: hit, promoção, evicção e capacidade zero;
- ajuste de capacidade após mudança de perfil;
- fallback de preferência inválida;
- controlador Automático, cooldown e limites;
- picking por posição e tolerância;
- mapeamento `MultiMesh` entre instância e ID.

### 14.2 Determinismo

- todos os perfis produzem a mesma assinatura de setor;
- todos os perfis produzem a mesma composição de SS;
- ordem de conclusão dos workers não altera resultados;
- número de workers não altera resultados;
- cache hit e cache miss retornam valores equivalentes;
- geração não consome o RNG global;
- conteúdo catalogado continua exatamente igual ao SQLite.

### 14.3 Integração

- overview não agenda setores;
- cluster não agenda composições;
- detail agenda apenas até seus limites;
- mover a câmera invalida visualmente pedidos antigos;
- voltar a uma região cacheada não chama o gerador;
- duas seleções do mesmo SS compartilham um trabalho;
- trocar seleção impede substituição atrasada do painel;
- fechar a cena finaliza tarefas sem callback órfão;
- o arquivo SQLite permanece com hash inalterado.

### 14.4 Renderização

- não existe nó permanente por sistema detalhado;
- quantidade de instâncias corresponde às definições ativas;
- cor, escala e posição correspondem ao tipo visual;
- remover setor remove suas instâncias e entradas de picking;
- alterar perfil respeita o orçamento e preserva IDs selecionados quando ainda
  visíveis.

### 14.5 Desempenho

Testes automatizados verificam limites estruturais, não tempos dependentes de
hardware:

- fila nunca excede `max_pending_requests`;
- setores detalhados nunca excedem `max_detailed_sectors`;
- aplicação respeita o número máximo de conclusões por frame;
- zoom máximo não aloca uma coleção proporcional ao retângulo visível;
- tarefas simultâneas não excedem o perfil.

Um benchmark manual registra hardware, resolução, perfil, FPS médio, percentil 95,
fila, cache e tempo de geração nos cenários:

1. zoom máximo e deslocamento contínuo por 30 segundos;
2. transição overview -> cluster -> detail;
3. deslocamento por cem setores detalhados;
4. abertura repetida de um SS procedural;
5. abertura de um sistema catalogado;
6. alternância Automático entre dois níveis.

## 15. Critérios de aceite

- Zoom máximo não cria nem ordena uma lista de aproximadamente um milhão de
  setores.
- Overview e cluster não criam composições de sistemas.
- Cluster e overview não permitem seleção individual.
- Detail usa `MultiMesh`, sem uma hierarquia permanente por estrela.
- A fila e o conjunto de trabalhos permanecem limitados pelo perfil.
- A thread principal nunca espera um worker para atualizar um frame.
- Operações de SceneTree e `MultiMesh` ocorrem apenas na thread principal.
- Voltar para uma região ainda cacheada não executa novamente a procedure.
- Reabrir um SS ainda cacheado não recria sua composição.
- Fechar o jogo descarta caches procedurais da demo.
- Perfis diferentes preservam integralmente a identidade do universo.
- Automático começa em Médio e busca 60 FPS com histerese e cooldown.
- O usuário pode escolher um perfil e a preferência sobrevive à reinicialização.
- Os defaults continuam editáveis em um único `game_settings.tres`.
- Catálogo permanece somente leitura, sem conteúdo procedural e sem fallback.
- A suíte, validação do catálogo e smoke do Godot passam sem erros.

## 16. Fora do escopo

- Compute shaders e `RenderingDevice` para geração canônica.
- Mudança para Forward+ ou Mobile renderer.
- Cache procedural persistente em disco.
- Autoridade de servidor e sincronização multiplayer.
- Persistência completa do universo.
- Alteração das regras de composição de sistemas.
- Geração antecipada de planetas e luas de todos os pontos do mapa.
- Menu geral de opções além do seletor de desempenho.
- Paginação de um catálogo científico que não caiba em memória.
- Retrocompatibilidade entre versões do gerador.

## 17. Ordem arquitetural recomendada

A futura implementação deverá respeitar esta dependência:

1. perfis tipados e invariantes canônicos;
2. política de LOD;
3. caches LRU;
4. scheduler incremental e limitado;
5. snapshot científico em memória;
6. geração assíncrona de setores;
7. `MultiMeshStarFieldView` e picking;
8. visão agregada de cluster e overview;
9. geração lazy de composições;
10. modo Automático, preferências e métricas;
11. benchmark e ajustes dos defaults.

Essa ordem evita paralelizar ou mover para GPU um pipeline ainda não limitado e
mantém a fonte canônica independente da apresentação em todas as etapas.
