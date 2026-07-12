# Zodiakos: arquitetura hexagonal orientada a eventos

## 1. Decisão

Zodiakos adotará um monólito modular com arquitetura hexagonal, modelo de domínio explícito e simulação orientada a eventos discretos.

O estado oficial do universo não ficará nos Nodes do Godot. A simulação será formada por objetos de domínio, comandos, serviços e uma agenda de eventos. O Godot será um adaptador de apresentação responsável por materializar apenas os elementos visíveis do universo.

Esta arquitetura substitui a adoção de um ECS genérico. Ela preserva as vantagens necessárias para escala, persistência e testes, mas expressa diretamente as regras estratégicas do jogo.

## 2. Motivos

As principais ações do Zodiakos são determinadas por custo e tempo:

- Naves aguardam um horário de chegada.
- Sondagens aguardam sua conclusão.
- Produções avançam em filas locais.
- Projetos podem ser pausados e retomados.
- Penalidades diplomáticas mudam com o calendário.
- A versão online continua simulando jogadores ausentes.

A maior parte dos objetos não precisa executar lógica a cada frame. Uma agenda de eventos processa somente o que vence em determinado instante, enquanto a apresentação interpola visualmente os estados conhecidos.

## 3. Objetivos

- Executar a mesma simulação na demo local e no futuro servidor.
- Permitir que jogador humano e LLM usem a mesma camada de comandos.
- Testar regras de jogo sem abrir cenas ou esperar tempo real.
- Salvar e restaurar o universo com suas ações pendentes.
- Materializar apenas a região visível do mapa no Godot.
- Manter regras de domínio independentes de interface, renderização e armazenamento.
- Permitir substituição futura dos adaptadores sem reescrever a jogabilidade.

## 4. Fora do escopo inicial

- Microsserviços.
- Event Sourcing completo.
- Processamento distribuído entre regiões do universo.
- Concorrência de escrita entre múltiplos servidores.
- Sincronização multiplayer em tempo real.
- Banco de dados remoto.
- Plugins externos de ECS ou de arquitetura.

A primeira implementação será um monólito modular dentro do projeto Godot, com persistência local e interfaces preparadas para adaptadores futuros.

## 5. Regra de dependência

As dependências apontam sempre para dentro:

```text
Presentation / Persistence / LLM
              ↓
          Application
              ↓
            Domain
```

- `Domain` não conhece Godot Nodes, arquivos, rede, interface ou LLM.
- `Application` coordena casos de uso e depende do domínio e de portas abstratas.
- Adaptadores implementam portas de persistência, relógio, apresentação e agentes externos.
- A camada visual pode ler projeções, mas não altera o domínio diretamente.

Tipos básicos do Godot, como `Vector2`, `Vector3`, `StringName`, `RefCounted` e coleções, podem ser utilizados quando não introduzirem dependência de cena ou renderização. Cor, material e qualquer outro dado exclusivamente visual permanecem fora do domínio.

## 6. Organização dos módulos

```text
scripts/
  domain/
    common/
    universe/
    travel/
    exploration/
    colonization/
    production/
    territory/
    diplomacy/
  application/
    commands/
    handlers/
    ports/
    projections/
  simulation/
    game_clock.gd
    scheduled_event.gd
    event_scheduler.gd
    simulation_engine.gd
  adapters/
    persistence/
    godot_view/
    llm/
  visuals/
  demo/
```

Os componentes geométricos existentes permanecem em `scripts/visuals/`. Eles serão consumidos pelo adaptador `godot_view` e não serão movidos para o domínio.

## 7. Modelo de domínio

### 7.1 Identidade

Toda entidade persistente recebe um identificador estável e opaco:

- `CivilizationId`
- `StarSystemId`
- `PlanetId`
- `ShipId`
- `ZodiacId`
- `ProjectId`

Na primeira versão, os IDs podem ser strings geradas de maneira centralizada. Nenhuma regra depende do caminho de um Node ou da posição de um objeto na árvore de cenas.

### 7.2 Entidades principais

#### `UniverseState`

Raiz do estado persistente da demo. Contém seed, civilizações, sistemas materializados, naves, territórios e agenda de eventos.

#### `StarSystem`

Contém coordenada, estrela, planetas conhecidos, proprietário, nível, Força de Trabalho, modo econômico, recursos e fila de produção.

#### `Planet`

Contém tipo, porte, recursos naturais e distribuição local de Força de Trabalho.

#### `Ship`

Contém classe, nível, proprietário, localização atual, estado operacional e ordem ativa. A nave não contém Node3D nem referência a mesh.

Estados iniciais da nave:

- `IDLE`
- `TRAVELING`
- `SURVEYING`
- `AWAITING_ORDER`
- `CONSUMED`

#### `Civilization`

Contém recursos globais, ciência, cultura, sistemas conhecidos, relações diplomáticas e configuração de delegação para LLM.

#### `Zodiac`

Contém civilização proprietária, estrelas de borda, ligações e validade atual do polígono territorial.

### 7.3 Objetos de valor

- `GameTimestamp`: tempo lógico em milissegundos.
- `UniverseCoordinate`: posição determinística no plano do universo.
- `TravelRoute`: sequência não vazia de sistemas.
- `ResourceAmount`: tipo e quantidade não negativa.
- `WorkforceAllocation`: distribuição validada de Força de Trabalho.
- `CommandResult`: sucesso ou falha de negócio estruturada.

Objetos de valor são imutáveis depois de validados sempre que isso for viável em GDScript.

## 8. Camada de comandos

Toda mutação começa por um comando. Interface, LLM e testes não alteram entidades diretamente.

Comandos iniciais:

- `SendShipCommand`
- `SurveySystemCommand`
- `ColonizeSystemCommand`
- `AssignWorkforceCommand`
- `StartProductionCommand`
- `PauseSimulationCommand`
- `ResumeSimulationCommand`

Cada comando contém apenas intenção e dados necessários. Por exemplo, `SendShipCommand` contém:

- Identificador da civilização autora.
- Identificador da nave.
- Rota solicitada.
- Horário em que o comando foi emitido.

Um handler executa o fluxo:

1. Carrega o estado necessário por uma porta de repositório.
2. Valida autorização e invariantes de domínio.
3. Aplica a transição de estado.
4. Agenda eventos futuros.
5. Persiste a unidade de trabalho.
6. Retorna um `CommandResult`.

Falhas de negócio não usam exceções para fluxo normal. Elas retornam códigos estáveis, como:

- `SHIP_NOT_FOUND`
- `SHIP_NOT_IDLE`
- `ROUTE_OUT_OF_RANGE`
- `INSUFFICIENT_RESOURCES`
- `TARGET_NOT_ELIGIBLE`
- `SIMULATION_PAUSED`

## 9. Relógio do jogo

`GameClock` é uma porta consultada pela simulação. Ela fornece `now()` sem expor diretamente `Time.get_unix_time_from_system()` ao domínio.

Implementações previstas:

- `LocalPausableClock`: usado na demo; pausa e retoma sem acelerar.
- `FakeGameClock`: usado em testes; avança para um horário definido.
- `ServerGameClock`: usado no online; deriva do relógio autoritativo do servidor.

Na demo, pausar congela o tempo lógico. Fechar o jogo salva esse tempo e nenhuma duração offline é aplicada ao carregar.

## 10. Agenda de eventos discretos

`EventScheduler` mantém eventos ordenados por:

1. Horário de execução.
2. Prioridade do tipo de evento.
3. Identificador sequencial para desempate determinístico.

Cada `ScheduledEvent` possui:

- `event_id`
- `event_type`
- `due_at`
- `aggregate_id`
- `payload`
- `status`

Status possíveis:

- `PENDING`
- `PROCESSING`
- `COMPLETED`
- `CANCELLED`
- `FAILED`

Eventos iniciais:

- `ShipArrivedEvent`
- `SurveyCompletedEvent`
- `ProductionCompletedEvent`
- `ColonizationCompletedEvent`

O scheduler nunca chama a interface ou manipula Nodes. Ele entrega eventos vencidos ao `SimulationEngine`, que seleciona o handler correspondente.

## 11. Motor de simulação

`SimulationEngine.advance()` executa:

1. Consulta o horário lógico atual.
2. Retira da agenda todos os eventos vencidos, respeitando um limite por ciclo.
3. Executa cada evento dentro de uma unidade de trabalho.
4. Marca sucesso ou falha.
5. Publica mudanças para as projeções.

O limite por ciclo evita travamentos quando muitos eventos vencem simultaneamente. Eventos restantes são processados nos ciclos seguintes sem mudar sua ordem determinística.

Na demo, o motor pode ser chamado a partir de um único Node coordenador. A chamada por frame serve apenas para verificar eventos vencidos; as entidades individuais não recebem `_process()`.

## 12. Fluxo de viagem

```text
SendShipCommand
    ↓
SendShipHandler
    ↓ valida propriedade, estado, rota e alcance
Ship.begin_travel(route, departure, arrival)
    ↓
EventScheduler.schedule(ShipArrivedEvent)
    ↓
Repository.save(universe)
```

Enquanto viaja, a nave armazena partida, chegada, origem e destino. Sua posição visual é uma projeção calculada por interpolação entre esses horários. A interpolação não altera o estado persistente.

Quando `ShipArrivedEvent` vence:

1. O handler confirma que a ordem ativa ainda corresponde ao evento.
2. Move a nave para o destino.
3. Limpa a viagem concluída.
4. Agenda sondagem, colonização ou combate quando a ordem exigir.
5. Publica a mudança para a apresentação.

Eventos antigos tornam-se inofensivos pela verificação do identificador da ordem ativa.

## 13. Produção e pausa

Projetos industriais armazenam trabalho necessário e trabalho acumulado. Ao ativar produção, o sistema agenda sua conclusão com base na Força de Trabalho atual.

Ao sair do modo industrial ou pausar:

1. Calcula o progresso até o horário atual.
2. Preserva o trabalho acumulado.
3. Cancela o evento de conclusão anterior.

Ao retomar:

1. Calcula o tempo restante usando a capacidade atual.
2. Agenda novo `ProductionCompletedEvent`.

Esse modelo preserva progresso sem atualizar a produção a cada frame.

## 14. Persistência

A demo usa snapshots versionados. Um snapshot contém:

- `schema_version`
- Seed do universo.
- Horário lógico.
- Estado das entidades.
- Agenda de eventos pendentes.
- Contadores usados para gerar IDs e desempatar eventos.

O adaptador inicial salva em JSON para facilitar inspeção durante o protótipo. Tipos de domínio são convertidos por mapeadores explícitos; não são serializados por reflexão da árvore de Nodes.

O carregamento valida versão, campos obrigatórios, IDs duplicados e referências inexistentes. Um arquivo inválido não substitui o estado carregado em memória e gera erro legível ao jogador.

Snapshots devem ser escritos primeiro em arquivo temporário e substituídos somente após a escrita completa, reduzindo risco de save corrompido.

## 15. Universo procedural

`UniverseGenerator` é um serviço determinístico que recebe seed e coordenada de setor. O domínio mantém apenas setores já materializados ou alterados.

Sistemas ainda não modificados podem ser reconstruídos pelo seed. Colonização, descoberta, exploração, produção e domínio transformam o sistema em estado persistente.

O gerador não instancia meshes. O adaptador visual solicita uma projeção do setor e decide quais componentes geométricos materializar.

## 16. Apresentação Godot

O adaptador `GodotUniverseView` observa uma `UniverseProjection` somente leitura.

Responsabilidades:

- Determinar setores visíveis pela câmera.
- Criar ou reutilizar `StarVisual`, `ShipVisual` e `PlanetVisual`.
- Atualizar posição, orientação, cor e seleção.
- Remover ou devolver ao pool objetos que saem da região visível.
- Interpolar viagens usando horários do domínio.

Proibições:

- Um visual não debita recursos.
- Um botão não move uma nave diretamente.
- Um Node3D não é usado como localização oficial.
- Remover um visual não remove a entidade do universo.

## 17. Integração da LLM

A LLM acessa uma projeção limitada ao conhecimento de sua civilização. Ela produz comandos iguais aos da interface humana.

Fluxo:

1. `LlmObservationBuilder` cria a observação permitida.
2. A LLM escolhe uma intenção estruturada.
3. `LlmCommandAdapter` converte a intenção em comando.
4. O mesmo handler usado pelo jogador valida e executa.
5. Resultados inválidos retornam códigos, permitindo nova decisão.

A LLM não escreve no repositório, não agenda eventos diretamente e não controla movimento por frame.

## 18. Erros, determinismo e idempotência

- Comandos possuem um `command_id` para impedir repetição acidental.
- Eventos possuem um `event_id` estável.
- Handlers verificam o estado atual antes de aplicar uma conclusão.
- Ordem de eventos empatados é determinada por prioridade e sequência persistida.
- Valores aleatórios derivam de seed e contexto explícito.
- Erros técnicos interrompem a unidade de trabalho e preservam o estado anterior.
- Erros de negócio retornam `CommandResult` sem modificar o estado.

Na demo há um único escritor. O servidor multiplayer adicionará controle de versão otimista por agregado quando múltiplas requisições puderem competir.

## 19. Estratégia de testes

### Domínio

Testes unitários sem SceneTree:

- Transições válidas e inválidas de nave.
- Validação de rotas.
- Consumo e preservação de recursos.
- Pausa e retomada de produção.
- Formação e rompimento de Zodíaco.

### Simulação

Testes com `FakeGameClock`:

- Evento não executa antes do vencimento.
- Evento executa exatamente uma vez.
- Eventos empatados mantêm ordem determinística.
- Pausa impede avanço lógico.
- Retomada preserva duração restante.

### Aplicação

Testes de handlers com repositório em memória:

- Jogador e LLM chegam ao mesmo resultado usando o mesmo comando.
- Falhas não persistem mutações parciais.
- Repetir `command_id` não duplica ação.

### Adaptadores

- Round-trip de snapshot preserva estado e eventos.
- Projeção visual materializa somente objetos visíveis.
- Smoke tests confirmam que cenas geométricas continuam carregando.

## 20. Migração da implementação atual

A implementação será incremental:

1. Manter a cena demonstrativa e os componentes geométricos atuais.
2. Criar `GameClock`, `ScheduledEvent` e `EventScheduler` com testes.
3. Criar o primeiro recorte vertical de domínio: nave, rota e viagem.
4. Criar `SendShipCommand` e `ShipArrivedEvent`.
5. Substituir o movimento estático da demo por uma projeção da viagem.
6. Adicionar snapshot local.
7. Evoluir para exploração, colonização e produção em módulos separados.

Cada etapa deve deixar uma demonstração executável e não introduzir dependência do domínio para a camada visual.

## 21. Critérios de aceitação arquitetural

A arquitetura estará corretamente estabelecida quando:

1. Uma viagem completa puder ser testada sem abrir uma cena.
2. Avançar um relógio falso executar a chegada imediatamente no teste.
3. A mesma viagem puder ser iniciada por interface ou adaptador de LLM.
4. Fechar e reabrir a demo preservar nave, ordem e evento de chegada.
5. Pausar a demo preservar exatamente o tempo restante.
6. A cena materializar e remover visuais sem alterar o domínio.
7. Nenhum objeto de domínio depender de Node, SceneTree, Mesh ou Control.
8. A simulação produzir o mesmo resultado para o mesmo estado, comandos e seed.
