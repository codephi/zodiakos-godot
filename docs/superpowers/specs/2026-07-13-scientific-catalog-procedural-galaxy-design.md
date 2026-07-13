# Zodiakos: catálogo científico SQLite e galáxia procedural

## 1. Objetivo

Esta especificação define como Zodiakos combinará um catálogo científico curado, armazenado diretamente em SQLite, com uma galáxia procedural determinística. Cada ponto do mapa representa um sistema estelar, que pode conter uma ou mais estrelas, planetas, luas e corpos menores.

O SQLite contém somente objetos catalogados. Todo conteúdo não catalogado é gerado em memória e pode ser reconstruído usando a seed, as versões e as coordenadas. O jogo nunca grava sistemas procedurais no catálogo.

Esta especificação substitui as decisões de extensão, distribuição uniforme por aglomerados e representação de cada ponto como estrela isolada da especificação [mapa estelar procedural infinito](2026-07-12-infinite-procedural-star-map-design.md). Permanecem válidos o streaming por setores, as coordenadas negativas, a origem flutuante, o carregamento sob demanda e a separação entre domínio e apresentação.

## 2. Decisões aprovadas

- Existe uma única Via Láctea no universo do jogo.
- A galáxia é finita e gigantesca; além do halo existe vazio.
- O mapa jogável usa o plano galáctico `x,y`; a coordenada científica `z` é preservada como metadado.
- Cada ponto clicável representa um sistema estelar, não uma estrela individual.
- Sistemas múltiplos continuam sendo um único ponto no mapa.
- Sistemas científicos funcionam como âncoras imutáveis da geração.
- O SQLite é a única fonte de verdade do catálogo; não existe CSV nem etapa de importação.
- Somente corpos explicitamente catalogados pertencem a sistemas científicos.
- A geração procedural nunca completa sistemas científicos com conteúdo fictício.
- Objetos procedurais são gerados sob demanda e nunca são inseridos no SQLite.
- Seed global, versão do algoritmo e versão do catálogo determinam a identidade da galáxia.
- Não haverá retrocompatibilidade entre versões da geração nesta fase do projeto.
- Alterar o catálogo ou o algoritmo cria uma nova versão integral da galáxia.

## 3. Escopo

### 3.1 Incluído

- Esquema relacional do catálogo científico.
- Sistemas, estrelas, planetas, luas e corpos menores conhecidos.
- Designações canônicas, nomes próprios, aliases e fontes.
- Coordenadas observacionais e galactocêntricas.
- Validação do banco SQLite.
- Acesso somente leitura durante o jogo.
- Modelo de densidade da Via Láctea.
- Geração procedural determinística por setor.
- Precedência dos sistemas científicos.
- Identidade e nomenclatura dos sistemas procedurais.
- Tratamento determinístico das bordas entre setores.
- Testes do catálogo e da geração.

### 3.2 Fora do escopo

- Mineração ou exploração econômica de corpos menores.
- Colonização, recursos ou Força de Trabalho.
- Interface de edição do catálogo dentro do jogo.
- Atualização automática por catálogos externos.
- Banco remoto ou autoridade multiplayer.
- Persistência de conteúdo procedural imutável.
- Compatibilidade de saves entre versões do catálogo ou gerador.
- Nomeação de objetos por jogadores.

## 4. Princípios arquiteturais

O desenho segue a [arquitetura hexagonal orientada a eventos](2026-07-12-event-driven-hexagonal-architecture-design.md).

```text
SQLite científico
      ↓
SqliteScientificCatalogRepository
      ↓ implementa
ScientificCatalogRepository
      ↓
LoadGalaxySector
  ├── GalacticDensityModel
  ├── SectorGenerator
  ├── ProceduralSystemFactory
  └── DynamicNamingService
      ↓
GalaxySectorProjection
      ↓
Adaptador visual Godot
```

- O domínio não conhece SQLite, queries, arquivos ou Nodes.
- A aplicação coordena catálogo e geração por meio de portas.
- O adaptador SQLite converte linhas em objetos de domínio somente leitura.
- A apresentação recebe projeções e não consulta o banco diretamente.
- O gerador não instancia meshes e não acessa a SceneTree.
- Trocar SQLite por um serviço remoto no futuro não altera as regras do gerador.

## 5. Arquivo SQLite

O catálogo será armazenado em:

```text
data/catalog/zodiakos_catalog.sqlite
```

No editor e nas ferramentas de manutenção, o banco pode ser aberto para escrita. Durante o jogo, ele é sempre aberto em modo somente leitura.

Não existe representação paralela em CSV, JSON ou recursos Godot. O arquivo SQLite é a fonte única dos objetos científicos. Scripts SQL de migração poderão registrar mudanças de esquema, mas não constituem um segundo catálogo de dados.

Todas as alterações de manutenção devem ocorrer dentro de transações. Uma alteração só é considerada válida depois das verificações de integridade e do incremento de `catalog_version`.

## 6. Identidade dos objetos catalogados

Todo objeto recebe um ID textual estável no namespace `catalog:`:

```text
catalog:sol
catalog:earth
catalog:moon
catalog:alpha-centauri
catalog:proxima-centauri-b
catalog:1p-halley
```

O ID não é exibido como nome científico e não muda quando um alias ou nome próprio é corrigido.

Cada objeto diferencia:

- `canonical_designation`: designação principal usada pelo catálogo.
- `proper_name`: nome próprio oficial, quando existir.
- `aliases`: outras designações científicas ou nomes reconhecidos.

Exemplo conceitual:

```text
id: catalog:99942-apophis
canonical_designation: (99942) Apophis
proper_name: Apophis
aliases: [2004 MN4]
```

O catálogo preserva as designações científicas reais; ele não converte objetos conhecidos para o padrão procedural de Zodiakos.

## 7. Esquema relacional

### 7.1 `catalog_metadata`

Contém uma única linha ativa:

- `schema_version: INTEGER`
- `catalog_version: INTEGER`
- `catalog_name: TEXT`
- `coordinate_model_version: INTEGER`
- `created_at_utc: TEXT`
- `updated_at_utc: TEXT`

`catalog_version` participa da seed procedural. `schema_version` controla a compatibilidade estrutural do adaptador.

### 7.2 `catalog_objects`

Tabela-base para identidade comum:

- `id: TEXT PRIMARY KEY`
- `object_kind: TEXT NOT NULL`
- `canonical_designation: TEXT NOT NULL`
- `proper_name: TEXT NULL`
- `discovery_year: INTEGER NULL`
- `notes: TEXT NULL`

Valores aceitos para `object_kind`:

- `stellar_system`
- `star`
- `planet`
- `moon`
- `minor_body`

A combinação normalizada de tipo e designação canônica deve ser única.

### 7.3 `stellar_systems`

Relação um-para-um com `catalog_objects`:

- `object_id: TEXT PRIMARY KEY`
- `ra_deg: REAL NULL`
- `dec_deg: REAL NULL`
- `distance_pc: REAL NULL`
- `coordinate_epoch: TEXT NULL`
- `galactocentric_x_pc: REAL NOT NULL`
- `galactocentric_y_pc: REAL NOT NULL`
- `galactocentric_z_pc: REAL NOT NULL`
- `system_class: TEXT NULL`

As coordenadas observacionais podem ser desconhecidas para um marco criado especificamente para o jogo, mas as três coordenadas galactocêntricas são obrigatórias para qualquer sistema usado pelo mapa.

### 7.4 `stars`

- `object_id: TEXT PRIMARY KEY`
- `system_id: TEXT NOT NULL`
- `component: TEXT NOT NULL`
- `spectral_type: TEXT NULL`
- `mass_solar: REAL NULL`
- `radius_solar: REAL NULL`
- `temperature_k: REAL NULL`
- `luminosity_solar: REAL NULL`

`component` usa letras maiúsculas como `A`, `B` e `C`. A combinação `system_id, component` é única.

### 7.5 `planets`

- `object_id: TEXT PRIMARY KEY`
- `system_id: TEXT NOT NULL`
- `planet_letter: TEXT NULL`
- `planet_class: TEXT NULL`
- `mass_earth: REAL NULL`
- `radius_earth: REAL NULL`
- `equilibrium_temperature_k: REAL NULL`

Para exoplanetas, `planet_letter` preserva a letra científica publicada, normalmente iniciada em `b`. Planetas do Sistema Solar mantêm suas designações e nomes oficiais e deixam `planet_letter` como `NULL`. Letras não são inventadas quando essa convenção não se aplica.

### 7.6 `moons`

- `object_id: TEXT PRIMARY KEY`
- `system_id: TEXT NOT NULL`
- `planet_id: TEXT NOT NULL`
- `satellite_designation: TEXT NULL`
- `mass_kg: REAL NULL`
- `radius_km: REAL NULL`

Uma lua pertence obrigatoriamente a um planeta do mesmo sistema.

### 7.7 `minor_bodies`

- `object_id: TEXT PRIMARY KEY`
- `system_id: TEXT NOT NULL`
- `minor_body_type: TEXT NOT NULL`
- `orbit_class: TEXT NULL`
- `mass_kg: REAL NULL`
- `radius_km: REAL NULL`
- `albedo: REAL NULL`

Tipos iniciais:

- `asteroid`
- `comet`
- `dwarf_planet`
- `trans_neptunian`
- `meteoroid`
- `interstellar_object`

Meteoros não são corpos persistentes e não entram nesta tabela; o objeto espacial correspondente é um meteoroide. Chuvas de meteoros e outros fenômenos ficam fora do escopo.

### 7.8 `orbits`

Centraliza relações orbitais sem chaves polimórficas frágeis:

- `orbiter_id: TEXT PRIMARY KEY`
- `primary_object_id: TEXT NOT NULL`
- `semi_major_axis_au: REAL NULL`
- `eccentricity: REAL NULL`
- `inclination_deg: REAL NULL`
- `orbital_period_days: REAL NULL`
- `longitude_ascending_node_deg: REAL NULL`
- `argument_periapsis_deg: REAL NULL`
- `mean_anomaly_deg: REAL NULL`
- `elements_epoch: TEXT NULL`

O centro orbital pode ser uma estrela, um planeta ou o próprio sistema estelar, usado como baricentro para órbitas circumbinárias. O validador impede autorreferência, ciclos e relações entre sistemas incompatíveis.

### 7.9 `aliases`

- `id: INTEGER PRIMARY KEY`
- `object_id: TEXT NOT NULL`
- `catalog_name: TEXT NOT NULL`
- `alias: TEXT NOT NULL`

A combinação `catalog_name, alias` é única. `catalog_name` identifica a origem da designação, como `Gaia DR3`, `HIP`, `HD`, `2MASS` ou `MPC`.

### 7.10 `sources` e `object_sources`

`sources`:

- `id: TEXT PRIMARY KEY`
- `title: TEXT NOT NULL`
- `authors: TEXT NULL`
- `publication_year: INTEGER NULL`
- `doi: TEXT NULL`
- `url: TEXT NULL`
- `accessed_at_utc: TEXT NULL`

`object_sources`:

- `object_id: TEXT NOT NULL`
- `source_id: TEXT NOT NULL`
- `source_role: TEXT NOT NULL`

A chave primária composta é `object_id, source_id, source_role`. O papel diferencia fontes de posição, órbita, propriedades físicas e nomenclatura.

## 8. Sistema de coordenadas

O catálogo utiliza um sistema cartesiano galactocêntrico destro:

- Origem no centro da Via Láctea.
- `+X` aponta do centro galáctico para a posição projetada do Sol.
- `+Y` aponta na direção adotada para a rotação galáctica.
- `+Z` aponta para o polo norte galáctico.
- A unidade é parsec.

O Sol fica aproximadamente em `X = +8150 pc`, coerente com a distância galactocêntrica adotada pelo modelo. Os valores exatos, a posição vertical do Sol e a transformação observacional pertencem à versão do modelo de coordenadas registrada em `coordinate_model_version`.

O mapa usa:

```text
map_position = (galactocentric_x_pc, galactocentric_y_pc)
```

`galactocentric_z_pc` permanece acessível no painel científico, mas não desloca o ponto para fora do plano jogável.

## 9. Consultas espaciais

O catálogo é curado e contém uma fração pequena dos sistemas procedurais. Não serão exigidas extensões `R*Tree`.

Índices B-tree serão mantidos para:

- `stellar_systems(galactocentric_x_pc)`
- `stellar_systems(galactocentric_y_pc)`
- `stars(system_id)`
- `planets(system_id)`
- `moons(system_id, planet_id)`
- `minor_bodies(system_id)`
- `aliases(object_id)`
- `object_sources(object_id)`

O repositório consulta sistemas dentro do retângulo do setor acrescido da margem de exclusão. A filtragem final nos dois eixos acontece no adaptador.

## 10. Identidade da galáxia

A identidade global é calculada a partir de:

```text
universe_identity = hash(
  global_seed,
  generator_version,
  catalog_version,
  coordinate_model_version,
  generation_config_snapshot
)
```

A seed de um setor é:

```text
sector_seed = hash(
  universe_identity,
  sector_x,
  sector_y
)
```

Nenhum resultado depende da ordem de carregamento, câmera, frame, horário do sistema ou estado aleatório global do Godot.

Alterar catálogo, coordenadas, modelo de densidade ou parâmetros versionados muda `universe_identity`. Nesta fase, saves anteriores não são migrados.

## 11. Forma científica da galáxia

`GalacticDensityModel` calcula uma densidade contínua combinando:

- Disco exponencial.
- Bojo central.
- Barra galáctica.
- Braços espirais com segmentos, ramificações e esporões.
- Variações hierárquicas e agrupadas.
- Halo estelar esparso.
- Transição até o limite exterior e o vazio.

O modelo não tenta representar cada estrela real da Via Láctea. Ele gera uma amostra jogável de sistemas cuja distribuição preserva estruturas estatísticas reconhecíveis.

Os parâmetros ajustáveis, como raio galáctico, escalas do disco, dimensões da barra, braços, densidade-base, contraste, ruído, distância mínima e tamanho de setor, ficam exclusivamente em `game_settings.tres`, conforme a regra central de configuração do projeto.

## 12. Geração de um setor

`LoadGalaxySector` executa:

1. Recebe coordenada do setor e snapshot imutável da configuração.
2. Calcula os limites galactocêntricos do setor.
3. Consulta sistemas catalogados no setor e na margem vizinha.
4. Materializa as âncoras científicas antes de qualquer candidato procedural.
5. Calcula a densidade galáctica local.
6. Gera candidatos procedurais usando `sector_seed`.
7. Atribui ID e prioridade determinísticos a cada candidato.
8. Rejeita candidatos dentro da distância mínima de qualquer âncora científica.
9. Resolve conflitos entre candidatos, inclusive nas bordas.
10. Retorna somente os sistemas cujo setor proprietário é o setor solicitado.
11. Gera a composição interna somente quando ela for solicitada pela aplicação.

Fora do limite da galáxia, o setor retorna vazio. Setores vazios são resultados válidos.

## 13. Precedência do catálogo

Sistemas catalogados são inseridos primeiro e sempre vencem conflitos espaciais.

Quando um candidato procedural estiver perto demais de um sistema científico:

- O sistema científico permanece exatamente em sua coordenada catalogada.
- O candidato procedural é descartado.
- Nenhum deslocamento artificial é aplicado à âncora.
- Outro candidato só aparece se o algoritmo determinístico daquele setor já o tiver produzido e ele passar nas validações.

Como `catalog_version` participa de `universe_identity`, qualquer alteração do catálogo também recompõe toda a amostra procedural, não apenas a vizinhança da âncora. Essa é uma escolha explícita de ausência de retrocompatibilidade.

## 14. Consistência entre setores

Cada candidato pertence a um único setor proprietário. Para resolver proximidade através de bordas:

1. O setor alvo considera candidatos próprios e dos setores vizinhos capazes de alcançar sua margem.
2. Todos usam IDs e prioridades derivados apenas de seed e coordenadas.
3. Em um conflito abaixo da distância mínima, vence a menor prioridade numérica.
4. Âncoras científicas vencem qualquer prioridade procedural.
5. Depois da resolução, cada setor retorna somente seus candidatos proprietários aceitos.

Setores carregados em ordens diferentes produzem exatamente o mesmo resultado.

## 15. Sistemas procedurais

Um sistema aceito recebe ID estável:

```text
proc:<generator-version>:<catalog-version>:<sector-x>:<sector-y>:<candidate-index>
```

`ProceduralSystemFactory` deriva uma nova seed desse ID e gera:

- Uma ou mais estrelas.
- Propriedades estelares coerentes com os parâmetros do modelo.
- Planetas.
- Luas.
- Corpos menores.
- Relações orbitais.

O conteúdo interno não é salvo enquanto permanecer imutável. Sondagem, colonização ou outras mudanças futuras poderão materializar estado persistente sem transformar o catálogo científico em banco de gameplay.

Para um sistema catalogado, `ProceduralSystemFactory` nunca é chamado. O sistema retorna exatamente as estrelas e os corpos presentes no SQLite, mesmo quando o catálogo estiver incompleto.

## 16. Nomenclatura procedural

Designações científicas reais variam por categoria e autoridade. Zodiakos usará um namespace próprio, inspirado nessas convenções sem se apresentar como nomenclatura oficial.

O sistema usa coordenadas galácticas quantizadas e um ordinal determinístico:

```text
ZDK-GX+008150-GY+000120-03
```

Componentes:

```text
Estrela A:   ZDK-GX+008150-GY+000120-03 A
Estrela B:   ZDK-GX+008150-GY+000120-03 B
Planeta b:   ZDK-GX+008150-GY+000120-03 b
Planeta c:   ZDK-GX+008150-GY+000120-03 c
Lua de b:    ZDK-GX+008150-GY+000120-03 b-I
Asteroide:   ZDK-GX+008150-GY+000120-03 SB-001
Cometa:      ZDK-GX+008150-GY+000120-03 C-001
```

Regras:

- Estrelas usam letras maiúsculas.
- Planetas usam letras minúsculas iniciadas em `b`.
- No procedural, a ordem planetária é orbital para garantir estabilidade; ela não simula ordem humana de publicação.
- Luas usam numeral romano subordinado ao planeta.
- Corpos menores usam código de tipo e ordinal local.
- O ordinal final do sistema impede colisão entre candidatos na mesma coordenada quantizada.
- Designações procedurais são calculadas em tempo de execução e não entram no SQLite.

## 17. Validação do SQLite

O catálogo deve ser validado antes de ser aceito por uma build e novamente ao iniciar o universo.

### 17.1 Integridade técnica

- O arquivo existe e pode ser aberto como somente leitura.
- `PRAGMA integrity_check` retorna sucesso.
- `PRAGMA foreign_key_check` não retorna violações.
- `schema_version` é suportada pelo adaptador.
- `catalog_version` e `coordinate_model_version` são positivas.
- Existe exatamente uma linha em `catalog_metadata`.

### 17.2 Integridade relacional

- Todo subtipo possui um `catalog_object` do tipo correspondente.
- Todo objeto possui exatamente um subtipo compatível.
- IDs e designações normalizadas não se repetem.
- Toda estrela, planeta, lua e corpo menor pertence a um sistema existente.
- Toda lua aponta para um planeta do mesmo sistema.
- Toda órbita aponta para objetos existentes e compatíveis.
- Não existem ciclos ou autorreferências orbitais.
- Componentes estelares são únicos dentro do sistema; letras planetárias não nulas também são únicas.

### 17.3 Integridade numérica

- Coordenadas galactocêntricas são finitas.
- Distâncias, massas, raios e períodos conhecidos não são negativos.
- Excentricidade conhecida não é negativa.
- Albedo conhecido fica no intervalo permitido.
- Valores científicos desconhecidos permanecem `NULL`; não são substituídos por zero.

## 18. Falhas e comportamento seguro

São falhas fatais para a inicialização do universo:

- Banco ausente ou ilegível.
- Banco corrompido.
- Versão de esquema incompatível.
- Metadados ausentes ou duplicados.
- Violações de chaves ou relações científicas.
- Erro de consulta que impeça localizar âncoras.

O jogo não inicia uma galáxia somente procedural como fallback, pois isso alteraria silenciosamente as posições disponíveis para todos os jogadores.

Campos científicos opcionais podem ser `NULL` e devem aparecer como desconhecidos na projeção. Eles não invalidam o objeto quando não participarem da posição ou identidade.

## 19. Manutenção do catálogo

O fluxo de manutenção é:

```text
abrir SQLite para manutenção
  → iniciar transação
  → inserir ou corrigir objetos e fontes
  → incrementar catalog_version
  → executar validações
  → confirmar transação
  → versionar o arquivo SQLite
```

Não existe sincronização automática com NASA, ESA, Gaia, SIMBAD, MPC ou outros catálogos. Cada inclusão é deliberada, curada e acompanhada de fonte.

Adicionar um planeta, lua ou corpo menor a um sistema científico exige registro explícito. A ausência de um corpo significa que ele não aparece no jogo naquela versão do catálogo.

## 20. Estratégia de testes

### 20.1 Esquema e catálogo

- Abrir o banco válido em modo somente leitura.
- Recusar `schema_version` incompatível.
- Recusar banco com chave estrangeira quebrada.
- Recusar designação duplicada.
- Recusar planeta sem sistema.
- Recusar lua sem planeta ou pertencente a outro sistema.
- Recusar órbita cíclica.
- Aceitar propriedades científicas opcionais como `NULL`.

### 20.2 Casos científicos de referência

- Carregar o Sistema Solar com Sol, planetas, luas e corpos menores cadastrados.
- Carregar um sistema com múltiplas estrelas.
- Carregar um exoplaneta com letra minúscula.
- Carregar um planeta circumbinário cujo centro orbital é o sistema.
- Confirmar aliases múltiplos para o mesmo objeto.

### 20.3 Determinismo procedural

- Mesma identidade do universo e mesmo setor produzem sistemas idênticos.
- Ordem diferente de carregamento não altera resultados.
- Descarregar e gerar novamente produz o mesmo setor.
- Alterar `catalog_version` altera `universe_identity`.
- Alterar `generator_version` altera `universe_identity`.
- O relógio e a ordem dos frames não alteram a geração.

### 20.4 Integração catálogo-procedural

- Sistema científico sempre aparece na coordenada exata.
- Candidato procedural conflitante é descartado.
- Conflitos de borda têm o mesmo vencedor em ambos os setores.
- Sistema científico não recebe nenhum corpo procedural.
- Sistema procedural recebe composição derivada exclusivamente de seu ID.
- Nenhuma operação da geração modifica o arquivo SQLite.

### 20.5 Nomes

- Designações catalogadas são preservadas sem conversão.
- Nome procedural é único dentro de uma versão da galáxia.
- Mesmo objeto procedural recebe sempre o mesmo nome.
- Estrelas, planetas, luas e corpos menores usam os sufixos definidos.
- Coordenadas negativas geram nomes inequívocos.

## 21. Migração do protótipo atual

A implementação futura deverá:

1. Preservar a câmera, origem flutuante e infraestrutura de streaming existentes.
2. Trocar o significado de cada ponto de estrela isolada para sistema estelar.
3. Substituir a distribuição atual pelo modelo de densidade da galáxia finita.
4. Introduzir as portas do catálogo sem levar SQLite ao domínio.
5. Adicionar precedência e exclusão ao redor de âncoras científicas.
6. Adicionar geração interna de sistemas em módulo separado.
7. Manter todos os valores ajustáveis em `game_settings.tres`.
8. Preservar as alterações locais existentes no Inspector durante a migração.

A migração não tentará manter os mesmos sistemas da geração anterior. A nova versão cria uma galáxia diferente por decisão explícita do projeto.

## 22. Critérios de aceitação

O desenho estará implementado corretamente quando:

1. O SQLite for a única fonte dos objetos científicos.
2. O jogo abrir o catálogo somente para leitura.
3. O domínio não depender de SQLite nem de Nodes.
4. Sol e outros sistemas cadastrados aparecerem nas coordenadas definidas.
5. Somente corpos cadastrados aparecerem em sistemas científicos.
6. O restante da galáxia for gerado deterministicamente sob demanda.
7. A distribuição formar disco, bojo, barra, braços, agrupamentos, halo e vazio externo.
8. Sistemas procedurais não forem gravados no catálogo.
9. A ordem de carregamento dos setores não alterar a galáxia.
10. Nomes procedurais forem únicos, reproduzíveis e baseados em coordenadas.
11. Alterar a versão do catálogo ou do algoritmo produzir uma nova identidade de galáxia.
12. Banco inválido impedir a inicialização com erro explícito.
13. Todos os testes de esquema, determinismo, borda e precedência passarem no Windows.

## 23. Referências científicas e técnicas

- [The Milky Way's Stellar Disk — Bland-Hawthorn & Gerhard](https://arxiv.org/abs/1602.07702)
- [The Stellar Mass Distribution and Star Formation History of the Galactic Disk — Bovy & Rix](https://arxiv.org/abs/1309.0809)
- [The Structure of the Milky Way's Bar — Wegg, Gerhard & Portail](https://arxiv.org/abs/1504.01401)
- [Trigonometric Parallaxes of High-Mass Star-Forming Regions — Reid et al.](https://arxiv.org/abs/1910.03357)
- [Gaia EDR3: Mapping the Milky Way disc with OB stars — Poggio et al.](https://arxiv.org/abs/2103.01970)
- [NASA Exoplanet Archive — nomenclatura de planetas](https://exoplanetarchive.ipac.caltech.edu/docs/faq.html)
- [IAU Working Group on Star Names](https://www.iau.org/WG280/WG280/Home.aspx)
- [Minor Planet Center — designações provisórias](https://docs.minorplanetcenter.net/mpc-ops-docs/designations/provisional-designations/)
- [Minor Planet Center — designação de cometas](https://docs.minorplanetcenter.net/mpc-ops-docs/designations/cometary-designation-system/)
- [Godot SQLite](https://github.com/2shady4u/godot-sqlite)
