# Zodiakos: mapa estelar procedural infinito

## 1. Objetivo

Esta especificação define a primeira implementação navegável do universo procedural de Zodiakos: um mapa estelar determinístico, contínuo e aparentemente infinito em todas as direções do plano.

O jogador poderá arrastar o mapa e aplicar zoom. A aplicação gerará setores sob demanda, materializará apenas os setores próximos da câmera e removerá representações distantes sem perder a capacidade de reconstruí-las.

Esta implementação segue a [arquitetura hexagonal orientada a eventos](2026-07-12-event-driven-hexagonal-architecture-design.md). O gerador pertence ao domínio e não instancia Nodes ou meshes. O Godot atua como adaptador de apresentação.

## 2. Decisões aprovadas

- Distribuição em aglomerados com regiões vazias.
- Universo sem limites positivos ou negativos nos dois eixos lógicos.
- Seed global compartilhado e determinístico.
- Coordenadas de domínio em `(x, y)`.
- Conversão visual para o plano 3D do Godot em `(x, 0, z)`.
- Arraste com o botão esquerdo do mouse.
- Zoom pela roda do mouse.
- Streaming de setores ao mover a câmera.
- Rematerialização idêntica ao retornar a uma região descarregada.

## 3. Escopo da primeira entrega

- Coordenadas de setor com suporte a valores negativos.
- Definição imutável de estrela procedural.
- Gerador puro e determinístico.
- Aglomerados que atravessam bordas de setores.
- Estrelas isoladas e regiões vazias.
- Distância mínima entre estrelas.
- Tipos visuais ponderados.
- Câmera ortográfica com arraste e zoom.
- Carregamento e descarregamento de setores.
- Materialização com o `StarVisual` existente.
- HUD técnico com seed, setor central, setores ativos e estrelas visíveis.
- Testes headless e cena demonstrativa executável.

## 4. Fora do escopo

- Sistemas solares e planetas procedurais.
- Recursos, colonização, domínio ou alianças.
- Constelações reais e regiões inspiradas no James Webb.
- Persistência de setores modificados.
- Seleção de estrelas.
- Rotas de nave.
- Níveis de detalhe por zoom.
- Renderização com `MultiMesh`.
- Servidor multiplayer.

Esses itens serão adicionados sobre os IDs e coordenadas estáveis definidos aqui.

## 5. Regra arquitetural

```text
Domain
  UniverseGenerator
  UniverseSector
  StarDefinition
       ↓ dados somente leitura
Application Projection
  VisibleSectorProjection
       ↓
Godot Adapter
  SectorStreamController
  StarFieldView
  MapCameraController
       ↓
Visual
  StarVisual
```

O fluxo de dependência não pode ser invertido:

- O domínio não conhece `Node`, `Node3D`, `Camera3D`, `Mesh` ou `SceneTree`.
- O gerador retorna dados e nunca adiciona filhos à cena.
- A câmera não chama regras de geração internas; ela informa quais setores são necessários.
- Descarregar um setor remove somente sua representação visual.

## 6. Sistemas de coordenadas

### 6.1 Posição do universo

Uma posição lógica não é armazenada como um `Vector2` absoluto. Ela é composta por:

```text
UniversePosition
  sector: SectorCoordinate
  local: Vector2
```

`local` permanece no intervalo semiaberto `[0, 40)` em cada eixo. Essa composição evita perda de precisão ao navegar para setores muito distantes.

### 6.2 Coordenada do setor

`SectorCoordinate` é um objeto de valor com dois campos `int`:

```text
SectorCoordinate
  x: int
  y: int
```

Não será usado `Vector2i`, pois seus componentes são limitados a 32 bits. Os campos `int` do GDScript preservam o intervalo inteiro de 64 bits necessário para o mapa praticamente ilimitado.

`SectorCoordinate` fornece igualdade, chave textual estável, soma de deslocamentos pequenos e distância de Chebyshev sem converter os valores para `float`.

### 6.3 Normalização de posição

Cada setor mede `40 × 40` unidades lógicas. Quando um deslocamento move a posição local para fora desse intervalo, `UniversePosition` transfere setores inteiros para `SectorCoordinate` e normaliza o restante.

Exemplo no eixo X:

```text
sector_delta = floor(local_x / 40)
sector.x += sector_delta
local_x -= sector_delta × 40
```

O uso de `floor`, e não truncamento, é obrigatório para valores negativos. Assim, mover da origem para `local_x = -0,1` resulta no setor `-1` com posição local `39,9`.

Uma estrela exatamente na borda positiva é normalizada para o setor seguinte e pertence a um único setor.

### 6.4 Conversão visual e origem flutuante

O adaptador escolhe o setor central da câmera como `render_origin`. Todos os Nodes usam posições relativas a ele:

```text
relative_x = (star.sector.x - render_origin.x) × 40 + star.local.x
relative_z = (star.sector.y - render_origin.y) × 40 + star.local.y
world_position = Vector3(relative_x, 0, relative_z)
```

Como somente setores próximos são materializados, as diferenças entre coordenadas cabem em valores pequenos. Ao cruzar uma borda, o adaptador altera `render_origin` e reposiciona os containers ativos. A câmera visual permanece perto da origem e não acumula coordenadas gigantes.

O eixo vertical visual do Godot é sempre `Y = 0`, exceto pequenos deslocamentos usados apenas para sobreposição visual.

## 7. Seed e mistura determinística

A seed da demo será:

```text
0x5A4F4449414B4F53
```

O valor representa `ZODIAKOS` em bytes ASCII e permanece fixo para todos os jogadores da primeira versão.

`SeedMixer` combina:

- Seed global.
- Coordenada X do setor proprietário.
- Coordenada Y do setor proprietário.
- Tipo de geração.
- Índice do aglomerado ou estrela.

Não será usado o estado aleatório global do Godot. Cada operação cria seu próprio `RandomNumberGenerator` com seed derivada.

O resultado não pode depender:

- Da ordem em que setores são solicitados.
- Da posição atual da câmera.
- Do frame atual.
- Do horário do sistema.
- De setores previamente carregados.

## 8. Identidade estável das estrelas

Cada estrela recebe um ID textual determinístico.

Estrela de aglomerado:

```text
cluster:<owner_x>:<owner_y>:<cluster_index>:<star_index>
```

Estrela isolada:

```text
isolated:<owner_x>:<owner_y>:<star_index>
```

O ID não usa a coordenada arredondada da estrela. Pequenas mudanças futuras no algoritmo ficam explicitamente vinculadas a uma nova versão do gerador.

`generator_version` começa em `1`. Saves futuros armazenarão essa versão para evitar reconstrução silenciosa com outro algoritmo.

## 9. Modelo de dados

### 9.1 `StarDefinition`

Objeto somente leitura após sua criação:

- `id: StringName`
- `sector: SectorCoordinate`
- `local_position: Vector2`
- `visual_type: StringName`
- `source: StringName`
- `owner_sector: SectorCoordinate`
- `generator_version: int`

`source` aceita:

- `cluster`
- `isolated`

Não contém cor, material, Node ou referência ao `StarVisual`.

### 9.2 `UniverseSector`

- `coordinate: SectorCoordinate`
- `stars: Array[StarDefinition]`
- `generator_version: int`

A coleção de estrelas é ordenada por ID antes de ser retornada. Isso estabiliza testes, serialização futura e materialização.

### 9.3 `UniverseGeneratorConfig`

Constantes iniciais:

| Parâmetro | Valor |
| --- | ---: |
| Tamanho do setor | 40 unidades |
| Aglomerados por setor proprietário | 0 a 2 |
| Estrelas candidatas por aglomerado | 8 a 20 |
| Raio do aglomerado | 8 a 18 unidades |
| Estrelas isoladas candidatas | 0 a 3 |
| Distância mínima | 1,5 unidade |
| Máximo aceito por setor | 64 estrelas |
| Versão do gerador | 1 |

Parâmetros ficam centralizados e não são duplicados na apresentação.

## 10. Geração de aglomerados

### 10.1 Setor proprietário

Cada aglomerado pertence ao setor usado para gerar seu centro. Suas estrelas podem cair no setor proprietário ou em um vizinho.

Para gerar um setor alvo, o algoritmo examina os nove setores proprietários no quadrado `3 × 3` centrado nele. O raio máximo de 18 unidades é menor que o tamanho do setor, portanto um aglomerado não alcança além dos vizinhos imediatos.

### 10.2 Centro

Para cada setor proprietário:

1. Derivar a seed de aglomerados.
2. Escolher deterministicamente entre zero e dois aglomerados.
3. Posicionar cada centro em qualquer ponto interno do setor.
4. Escolher raio entre 8 e 18.
5. Escolher de 8 a 20 estrelas candidatas.

### 10.3 Espalhamento

Cada candidata usa ângulo uniforme entre `0` e `TAU`.

A distância ao centro usa:

```text
distance = cluster_radius × pow(random_0_to_1, 1.8)
```

O expoente concentra mais estrelas próximo do centro e preserva uma borda irregular.

Uma pequena variação elíptica determinística em X e Y evita aglomerados perfeitamente circulares. A razão entre os eixos fica entre `0,65` e `1,0`, com rotação aleatória por aglomerado.

## 11. Estrelas isoladas e vazios

Cada setor proprietário gera de zero a três candidatas isoladas.

- Há chance explícita de produzir zero.
- Uma isolada pode ser rejeitada pela distância mínima.
- Um setor sem candidatas aceitas é válido.
- Nenhuma estrela artificial é inserida para preencher regiões vazias.

Essa regra permite corredores de baixa densidade e vazios entre aglomerados.

## 12. Distância mínima global

A distância mínima de `1,5` unidade vale também através das bordas de setor.

Procedimento:

1. Gerar todas as candidatas vindas dos nove setores proprietários relevantes.
2. Converter temporariamente cada candidata para coordenadas relativas ao setor alvo, nunca para uma posição global absoluta em `Vector2`.
3. Manter candidatas dentro do setor alvo ou a até `1,5` unidade de sua borda.
4. Atribuir a cada candidata uma prioridade determinística derivada de seu ID.
5. Comparar candidatas cuja distância seja menor que `1,5`.
6. Manter apenas a candidata com menor prioridade numérica.
7. Depois da resolução, normalizar setor e posição local e retornar somente estrelas pertencentes ao setor alvo.

Como setores adjacentes geram o mesmo conjunto de candidatas na área compartilhada, ambos tomam a mesma decisão na borda.

Se mais de 64 estrelas forem aceitas, o setor mantém as 64 de menor prioridade. Esse limite é um mecanismo de segurança, não uma meta de densidade.

## 13. Tipos visuais

O tipo é derivado de uma rolagem determinística independente da posição.

| Tipo | Peso inicial |
| --- | ---: |
| Amarela | 35% |
| Vermelha | 25% |
| Branca | 20% |
| Laranja | 15% |
| Azul | 5% |

Os nomes usados pelo domínio são:

- `yellow`
- `red`
- `white`
- `orange`
- `blue`

O adaptador passa o nome diretamente à paleta visual existente. Os pesos não representam uma distribuição astronômica científica; servem à leitura do protótipo.

## 14. Streaming de setores

### 14.1 Controlador

`SectorStreamController` recebe a `UniversePosition` lógica da câmera. Seu `sector` já define o setor central, sem divisão de coordenadas absolutas.

Parâmetros iniciais:

- `load_radius = 2`
- `unload_radius = 3`

O raio usa distância de Chebyshev:

```text
max(abs(delta_x), abs(delta_y))
```

Assim, o raio de carregamento forma um quadrado `5 × 5` de até 25 setores. O raio de descarregamento mantém uma margem e evita recriar setores ao oscilar perto de uma borda.

### 14.2 Carregamento

Quando o setor central muda:

1. Calcular coordenadas desejadas no raio 2.
2. Gerar somente coordenadas ainda não ativas.
3. Criar um container visual por setor.
4. Materializar suas estrelas.
5. Remover containers além do raio 3.

O processamento ocorre em lotes com limite inicial de dois novos setores por frame. O setor central tem prioridade, seguido pelos mais próximos da câmera.

### 14.3 Descarregamento

Ao descarregar:

- `StarVisual` volta ao pool ou é liberado.
- O container do setor é removido.
- Nenhum dado procedural imutável é salvo.
- Nenhuma alteração é enviada ao domínio.

O número de setores ativos permanece limitado a 49 no estado estável.

## 15. Apresentação das estrelas

`StarFieldView` recebe um `UniverseSector` e cria uma representação para cada `StarDefinition`.

Para cada estrela:

1. Calcular a posição relativa ao `render_origin` e convertê-la para `Vector3(x, 0, z)`.
2. Obter ou criar um `StarVisual`.
3. Aplicar `visual_type`.
4. Não exibir anel de proprietário nesta fase.
5. Associar o ID aos metadados do Node para depuração futura.

Todos os visuais de um setor ficam sob um Node3D nomeado por coordenada:

```text
Sector_-3_7
```

## 16. Câmera do mapa

### 16.1 Projeção

A câmera é ortográfica, posicionada acima do plano e orientada diretamente para baixo. `MapCameraController` mantém uma `UniversePosition` lógica separada do transform visual.

- Posição visual mantida perto de `(local_x, camera_height, local_y)`.
- Rotação: `-90°` em X.
- Altura é constante e não participa do zoom.
- Zoom altera `Camera3D.size`.

### 16.2 Arraste

- Pressionar botão esquerdo inicia a captura.
- Mover o mouse desloca a câmera no sentido oposto ao delta.
- Soltar encerra a captura.
- O fator de deslocamento considera o tamanho ortográfico e a altura do viewport.
- Não existe limite de posição.
- Cruzar uma borda normaliza a posição lógica e redefine a origem flutuante visual.

O controle diferencia clique de arraste por um limiar de quatro pixels. Isso preserva espaço para seleção de estrelas em uma etapa posterior.

### 16.3 Zoom

- Roda para cima aproxima.
- Roda para baixo afasta.
- `minimum_size = 20`.
- `maximum_size = 90`.
- Cada passo multiplica o tamanho por `0,88` ou seu inverso.
- O zoom é centralizado inicialmente na câmera, não no cursor.

Os limites garantem leitura dos meshes e mantêm a área visível coberta pelo raio de streaming.

## 17. HUD técnico

A cena demonstra:

- Seed em hexadecimal.
- Coordenada do setor central.
- Quantidade de setores ativos.
- Quantidade de estrelas materializadas.
- Tamanho ortográfico atual.

O HUD é exclusivo de desenvolvimento e não pertence ao domínio.

## 18. Cena demonstrativa

Nova cena principal:

```text
InfiniteStarMapDemo
  MapCamera
  SectorStreamController
  SectorRoot
  DebugHud
  WorldEnvironment
```

A cena geométrica anterior permanece no repositório como catálogo visual, mas `project.godot` passa a abrir `InfiniteStarMapDemo`.

Ao iniciar:

1. A câmera nasce na origem lógica.
2. O streaming solicita os setores próximos.
3. Setores são materializados progressivamente.
4. O jogador pode arrastar e aplicar zoom imediatamente.

## 19. Tratamento de erros

- Coordenada de setor vazia ou inválida não é aceita pelas interfaces tipadas.
- Um setor sem estrelas retorna uma coleção vazia válida.
- Um tipo visual desconhecido usa o fallback amarelo já definido na paleta.
- Uma estrela com posição não finita é rejeitada pelo gerador e registra erro de desenvolvimento.
- Falha ao criar um visual não invalida o setor; a próxima estrela continua sendo processada.
- Containers duplicados para a mesma coordenada são impedidos pelo mapa de setores ativos.
- O limite de estrelas por setor impede densidade acidental extrema.

## 20. Desempenho

Metas da primeira versão:

- No máximo 49 containers de setor ativos em estado estável.
- No máximo 64 estrelas por setor.
- Até dois setores novos materializados por frame.
- Nenhuma estrela possui `_process()` próprio.
- O gerador não consulta a SceneTree.
- Materiais continuam reutilizando a paleta geométrica.

`MultiMesh`, geração em thread e cache persistente serão considerados somente depois de medir esta implementação.

## 21. Estratégia de testes

### 21.1 Coordenadas

- Origem pertence ao setor `(0, 0)`.
- Deslocar `(-0,1, -0,1)` desde a origem normaliza para setor `(-1, -1)` e posição local próxima de `(39,9, 39,9)`.
- Pontos na borda positiva pertencem ao setor seguinte.
- Conversão setor → limites → setor preserva o intervalo semiaberto.
- Coordenadas além do intervalo de 32 bits permanecem exatas em `SectorCoordinate`.
- A posição renderizada permanece pequena mesmo em setores logicamente distantes.

### 21.2 Determinismo

- Mesmo seed e coordenada produzem estrelas idênticas.
- Ordem diferente de solicitação não altera setores.
- Descarregar e gerar novamente produz o mesmo resultado.
- Seeds diferentes alteram o resultado.

### 21.3 Aglomerados e fronteiras

- Um aglomerado pode produzir estrelas em dois setores.
- Uma estrela de borda aparece em somente um setor.
- Não existem IDs duplicados numa região `3 × 3`.
- A distância mínima é respeitada através das bordas.
- Setores vazios são aceitos.

### 21.4 Tipos

- Todo tipo retornado pertence à paleta permitida.
- O tipo de uma estrela não muda entre gerações.
- Pesos são avaliados por teste estatístico com tolerância ampla sobre uma amostra fixa.

### 21.5 Streaming

- Mudar de setor solicita novas coordenadas.
- Setor já ativo não é gerado duas vezes.
- Setor além do raio de descarregamento é removido.
- Total ativo não ultrapassa 49 após estabilização.
- Remover representação não modifica `UniverseSector`.

### 21.6 Câmera

- Arraste altera X e Z sem alterar Y.
- Zoom respeita os limites 20 e 90.
- Posição negativa seleciona corretamente setores negativos.

### 21.7 Integração

- Cena principal carrega sem erro no renderizador Compatibility.
- Setores aparecem após os primeiros frames.
- HUD reflete contagens reais.
- Smoke test headless permanece executável.

## 22. Critérios de aceitação

A primeira versão estará concluída quando:

1. O jogador puder arrastar continuamente em qualquer direção sem encontrar borda.
2. Novas estrelas surgirem à medida que a câmera atravessa setores.
3. Setores distantes forem removidos e o total ativo permanecer limitado.
4. Retornar a uma região mostrar exatamente as mesmas estrelas.
5. Aglomerados atravessarem bordas sem cortes alinhados à grade.
6. Existirem regiões densas, regiões esparsas e vazios.
7. Coordenadas negativas funcionarem da mesma forma que positivas.
8. Zoom permanecer entre os limites definidos.
9. Nenhum Node ou mesh existir dentro do módulo de domínio.
10. Navegar para coordenadas além de 32 bits não causar perda da identidade do setor nem posições visuais gigantes.
11. Todos os testes automatizados e o smoke check do Godot passarem sem erros.
