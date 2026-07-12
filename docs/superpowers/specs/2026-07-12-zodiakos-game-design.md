# Zodiakos: documento inicial de game design

- **Versão:** 0.6
- **Data:** 12 de julho de 2026
- **Status:** visão consolidada e decisões confirmadas
- **Plataforma inicial:** PC
- **Engine:** Godot 4
- **Expansão prevista:** mobile e multiplayer online

## 1. Visão do jogo

Zodiakos é um jogo de estratégia territorial e logística em tempo real ambientado em um universo interestelar contínuo. A representação é tridimensional, mas a jogabilidade acontece em um único plano, formando uma experiência 2.5D composta por estrelas, ligações, estruturas, unidades e Zodíacos poligonais.

O jogo não possui partidas isoladas nem uma condição final de vitória. O jogador desenvolve uma civilização ao longo do tempo, acumula pontos, conquista realizações, completa quests e enfrenta desafios progressivos. Perdas territoriais fazem parte da história daquele universo, mas não encerram o jogo.

A fantasia central é transformar uma pequena presença espacial em uma rede interestelar produtiva, defensável e politicamente relevante.

## 2. Pilares de design

### 2.1 Território visível

O domínio de uma civilização é representado diretamente no mapa. Estrelas conectadas formam rotas; rotas fechadas demarcam Zodíacos; Zodíacos válidos aceleram produção, movimento e outras ações dentro de suas fronteiras.

### 2.2 Ordens por nave

O jogador define o que cada nave deve fazer, qual estrela ou território será seu alvo e por quais estrelas ela passará. Ele desenha a rota ao arrastar uma linha imaginária entre estrelas. A nave executa a ordem e percorre a rota automaticamente, sem pilotagem direta.

### 2.3 Logística antes da força bruta

Produção só tem valor quando pode ser transportada, armazenada e aplicada. A forma da rede, a distância entre pontos e a proteção das rotas são tão importantes quanto o número de unidades militares.

### 2.4 Geografia com consequência

Exploração, contato, comércio, diplomacia, entrada em Alianças e guerra dependem de deslocamento pelo universo. A interface pode formalizar uma decisão, mas não elimina a distância física entre as civilizações.

### 2.5 Universo contínuo

O progresso é persistente. A demo salva o universo localmente e congela sua simulação quando o jogo fecha. A versão online manterá o universo ativo nos servidores mesmo quando jogadores humanos estiverem ausentes.

### 2.6 Humanos e agentes sob as mesmas regras

Jogadores humanos e agentes controlados por LLM utilizam a mesma camada de comandos estratégicos. A simulação resolve movimento, produção e combate por regras determinísticas; a LLM escolhe objetivos, prioridades e ações válidas, sem controlar a física a cada quadro.

## 3. Formatos do produto

| Aspecto | Demo single-player | Produto online |
|---|---|---|
| Execução do universo | Local | Servidor autoritativo |
| Persistência | Save local | Persistência contínua no servidor |
| Jogo fechado | Simulação congelada | Simulação continua ativa |
| Oponentes | Civilizações controladas por LLM | Humanos e civilizações controladas por LLM |
| Controle do tempo | Pausa permitida; sem aceleração | Sem pausa global |
| Ausência do jogador | Nenhuma progressão | Jogador pode delegar sua civilização a uma LLM |
| Plataforma prioritária | PC | PC, com possibilidade de extensão para mobile |

## 4. Ciclo principal de jogabilidade

A direção central é uma estratégia territorial e logística em tempo real:

1. Arrastar o mapa estelar e identificar um sistema de interesse.
2. Selecionar a estrela e enviar uma nave de pesquisa.
3. Descobrir os planetas, tipos planetários e recursos do sistema.
4. Enviar uma nave colonizadora para converter sua capacidade em Pontos de Colônia.
5. Distribuir os Pontos de Colônia entre planetas e recursos.
6. Conectar sistemas dominados e fechar um Zodíaco válido.
7. Usar os bônus territoriais para acelerar produção, transporte e expansão.
8. Investir o estoque em estruturas, ligações e novas naves.
9. Defender, atacar, pontuar e receber novos desafios.
10. Repetir o ciclo em escala crescente, sem reiniciar o universo.

O principal domínio do jogador não é a velocidade de clicar, mas a capacidade de construir uma rede eficiente, antecipar ameaças e selecionar prioridades.

## 5. Estrutura do universo

### 5.1 Geração determinística

O universo utiliza geração procedural determinística. Um seed compartilhado garante que uma determinada coordenada produza a mesma estrutura para todos os jogadores.

O mapa combina:

- Marcos fixos inspirados em constelações conhecidas e estruturas observadas do espaço.
- Regiões autorais inspiradas visualmente em imagens astronômicas, incluindo referências do James Webb Space Telescope.
- Conteúdo procedural além dos marcos fixos.

As referências astronômicas servem como inspiração visual e espacial; Zodiakos não pretende reproduzir um catálogo científico literal.

### 5.2 Expansão do mapa

Novas regiões são materializadas conforme a exploração avança. O universo percebido pode crescer continuamente sem exigir que todo o mapa seja carregado ou armazenado de uma vez.

### 5.3 Mapa estelar interativo

O mapa estelar é a interface principal do jogo. O jogador arrasta a tela livremente e vê diretamente as estrelas das regiões visitadas pela câmera. Não existe névoa escondendo a posição dos sistemas.

O universo é materializado proceduralmente em blocos conforme o deslocamento e o nível de zoom. Estrelas distantes utilizam representações simplificadas, permitindo a sensação de continuidade sem carregar o mapa infinito de uma vez.

Ver uma estrela não revela automaticamente seu sistema solar. Antes da pesquisa, o jogador conhece sua posição e aparência externa. Depois de enviar uma nave de pesquisa, passa a conhecer seus planetas, tipos planetários e recursos.

Aliados podem compartilhar informações atualizadas de seus territórios. Quando uma Aliança é abandonada, o jogador preserva o último estado conhecido das áreas dos ex-aliados, mas deixa de receber atualizações. A interface mostra a idade dessa informação e indica que ela pode estar desatualizada.

### 5.4 Modos de exploração

Uma nave de pesquisa pode receber:

- Uma estrela específica como destino.
- Uma direção geral para avançar.
- Uma sequência de estrelas.
- Exploração automática de uma fronteira desconhecida.
- Exploração aleatória entre destinos válidos dentro de seu alcance operacional.

### 5.5 Origens de jogador

O produto online possui duas origens iniciais.

#### Membro de Aliança

O jogador escolhe uma Aliança antes de nascer. O sistema procura regiões livres próximas às maiores concentrações de membros daquela Aliança. O nascimento favorece proximidade social, comércio e proteção, mas oferece menos espaço isolado para expansão.

#### Civilização Emergente

O jogador nasce sem Aliança, em uma região distante das concentrações territoriais conhecidas. Na narrativa, sua civilização acaba de alcançar o primeiro estágio de exploração interestelar. Ela recebe maior segurança inicial, mais espaço de exploração e melhores condições para acumular recursos, mas não possui aliados ou acesso imediato a uma rede comercial.

## 6. Rede territorial e economia física

O protótipo visual estabelece os seguintes elementos conceituais:

- **Ponto de ligação:** estrela ou nó usado para ampliar a rede.
- **Demarcador de Zodíaco:** ligação que ajuda a formar a fronteira territorial.
- **Estação de ligação:** estrutura que conecta Zodíacos ou redes distintas.
- **Base de produção:** destino operacional para recursos transportados.
- **Estoque de produção:** reserva usada para criar novos demarcadores e outros elementos.
- **Laboratório:** estrutura que desbloqueia esquemas de produção.
- **Zodíaco:** área territorial delimitada por ligações pertencentes a uma civilização, formada por pelo menos três estrelas.

Qualquer sistema controlado permite extrair os recursos de seus planetas na velocidade básica de 1x. Quando o jogador conecta de ponta a ponta pelo menos três estrelas dominadas e fecha um polígono válido, ele forma um Zodíaco, captura a área interna e ativa os bônus territoriais.

Dentro de um Zodíaco íntegro:

- Recursos são capturados a 3x.
- Naves se movimentam a 3x.
- Exploração e demais ações territoriais são executadas a 3x.
- Estrelas neutras são dominadas a 3x.

A produção percorre a rede até um estoque ou base designada. Distâncias e interrupções nas ligações afetam a eficiência logística.

### 6.1 Comandos e rotas

O jogador emite ordens individualmente para cada nave. Uma ordem contém:

- A ação: explorar o mapa, prospectar um território, coletar um recurso, dominar, defender ou atacar.
- A estrela ou o território-alvo.
- Uma rota desenhada entre estrelas.

Cada linha arrastada entre duas estrelas define um trecho do percurso. Vários trechos podem formar uma rota maior. A nave segue os pontos definidos até concluir a ação, ser redirecionada ou encontrar uma interrupção válida.

Toda ligação possui um alcance máximo. Uma linha que ultrapasse esse alcance não pode ser confirmada. O jogador pode aumentar a capacidade de ligação ao desenvolver perfis especializados, como exploradores, mas nenhum aprimoramento elimina o limite de distância.

A interface deve indicar o alcance disponível durante o desenho da linha e mostrar claramente quando a estrela de destino está fora dele.

### 6.2 Nave de pesquisa

Ao selecionar uma estrela, o jogador pode enviar uma nave de pesquisa. Quando ela chega ao destino, revela:

- Quantidade de planetas do sistema.
- Tipo de cada planeta.
- Entre um e três tipos de recurso por planeta.
- Características e bônus próprios do sistema.
- Possibilidades de colonização.

A nave de pesquisa não utiliza combustível consumível. Seus limites operacionais são definidos pelo alcance máximo das ligações, pela velocidade e pelas capacidades de seu perfil.

### 6.3 Colonização e Pontos de Colônia

A nave colonizadora é mais cara que a nave de pesquisa. Cada unidade transporta uma capacidade limitada de colonização e consegue atender apenas uma quantidade máxima de planetas.

Quando chega ao sistema escolhido:

1. A nave colonizadora é consumida permanentemente.
2. Sua capacidade é transformada em Pontos de Colônia vinculados ao sistema.
3. O jogador distribui esses pontos entre os planetas pesquisados.
4. Dentro de cada planeta, os pontos são distribuídos entre seus recursos.
5. Novas naves colonizadoras acrescentam capacidade ao mesmo sistema.

Cada recurso possui uma barra horizontal segmentada de 0 a 10. Cada segmento preenchido representa um Ponto de Colônia dedicado à extração daquele recurso. O nível aplicado determina quanto do potencial natural do recurso é aproveitado.

Os Pontos de Colônia podem ser redistribuídos entre os planetas e recursos do sistema. A produção resultante combina:

- Potencial natural do planeta.
- Pontos de Colônia aplicados ao recurso.
- Características e bônus do sistema solar.
- Tecnologias e especializações da civilização.
- Bônus territorial do Zodíaco.

Ao clicar em um sistema pesquisado, o painel apresenta os planetas em linhas ou cartões, seus tipos, seus recursos e as barras de Pontos de Colônia. O jogador usa esse painel para concentrar ou diversificar sua produção.

### 6.4 Unidades operacionais iniciais

- **Operário:** transporta uma carga por vez e procura a base de produção designada quando estiver carregado.
- **Guarda:** patrulha pontos do Zodíaco, reage a invasões e participa da quebra de elos inimigos.
- **Nave colonizadora:** transforma-se em Pontos de Colônia e consolida a ocupação dos planetas de um sistema.

Essas unidades executam suas tarefas automaticamente, mas cada nave recebe do jogador uma ação, um alvo e uma rota. O sistema valida e realiza o deslocamento dentro da rede.

## 7. Conflito e conquista

O conflito acontece sobre a rede territorial:

1. Guardas atacam e quebram um elo de um Zodíaco adversário.
2. Após a abertura, naves colonizadoras são enviadas para consolidar a conquista.
3. Uma estrela ocupada exige três naves colonizadoras consecutivas para mudar de controle, conforme a regra apresentada no protótipo.
4. A quantidade de guardas influencia a velocidade ou a pressão da conquista.
5. Um upgrade pode permitir que guardas capturem operários e naves colonizadoras encontrados durante o deslocamento.

### 7.1 Cerco por fechamento de área

Estrelas neutras ou inimigas dentro de um Zodíaco não mudam de dono automaticamente. O fechamento cria vantagens para conquistá-las:

- Estrelas neutras são dominadas a 3x.
- Contra uma estrela inimiga cercada, o proprietário do Zodíaco recebe vantagem de ataque ou conquista de 5x.
- Outros jogadores da mesma Aliança recebem vantagem de 2x contra essa estrela.
- A estrela inimiga continua pertencendo ao adversário até a conclusão da conquista.

Os modificadores de 5x e 2x são as regras específicas para conquistar estrelas inimigas cercadas; o bônus territorial geral permanece em 3x para movimento, recursos e outras ações.

### 7.2 Reorganização e ruptura do Zodíaco

O Zodíaco só concede vantagens enquanto sua borda formar um polígono fechado com pelo menos três estrelas. Se uma estrela da borda for conquistada ou uma ligação for rompida, o sistema tenta reorganizar automaticamente o contorno:

1. O sistema identifica as estrelas sobreviventes que eram vizinhas do ponto perdido.
2. Mede a distância entre elas usando a capacidade de ligação disponível.
3. Se a nova ligação estiver dentro do alcance e formar um polígono válido, ela é criada automaticamente.
4. O Zodíaco assume o novo contorno e mantém seus bônus dentro da área restante.
5. Se nenhuma reorganização válida for possível, o Zodíaco é desativado imediatamente.

Quando o Zodíaco é desativado:

- Produção, movimento e ações retornam à velocidade aplicável fora do Zodíaco.
- Estrelas neutras perdem o bônus de captura.
- Estrelas inimigas deixam de sofrer as vulnerabilidades de 5x e 2x.

Por exemplo, se um Zodíaco quadrilateral `A-B-C-D` perder a estrela `B`, o sistema tenta conectar `A` a `C`. Se a distância estiver dentro do alcance, o Zodíaco continua como o triângulo `A-C-D`. Se estiver fora, o contorno se rompe.

O protótipo também propõe que um Zodíaco cercado possa tentar iniciar outro Zodíaco no ponto livre mais próximo fora do cerco. Os números, tempos e condições exatas serão tratados na especificação de combate, sem bloquear o primeiro protótipo do ciclo territorial.

## 8. Agentes controlados por LLM

### 8.1 Demo

Na demo, todas as civilizações adversárias são controladas por LLM. Cada agente recebe apenas o estado de jogo que sua civilização poderia conhecer e escolhe comandos disponíveis também ao jogador humano.

A LLM decide, por exemplo:

- Qual região explorar.
- Onde expandir a rede.
- O que produzir.
- Quais rotas proteger.
- Quando atacar ou recuar.
- Como responder a contatos e propostas disponíveis na versão simulada.

Movimentação, custos, produção, dano e validação de comandos permanecem sob controle do motor determinístico do jogo.

### 8.2 Produto online

Além de controlar civilizações próprias, a LLM poderá atuar como representante temporária de um jogador ausente. O jogador configurará prioridades e limites antes de delegar sua civilização. A simulação continuará no servidor, e o agente utilizará as mesmas ações permitidas ao humano.

## 9. Alianças

### 9.1 Criação e capacidade

- Criar uma Aliança não exige recursos nem estruturas.
- Toda nova Aliança começa com três vagas: uma para o fundador e duas adicionais.
- As vagas adicionais podem ser públicas ou reservadas para convites.
- Administradores controlam essa distribuição.
- A capacidade da Aliança cresce de acordo com a riqueza agregada de seus membros.

A fórmula que converte riqueza em vagas pertence ao design econômico da versão online e não faz parte do escopo da demo de jogabilidade.

### 9.2 Entrada em uma Aliança

Uma Civilização Emergente não entra em uma Aliança apenas por menu. Ela precisa enviar uma nave até o território de um membro, chegar fisicamente ao destino e solicitar adesão. A entrada depende de aprovação e de uma vaga disponível.

Membros de uma Aliança começam com todos os demais integrantes disponíveis para comunicação e comércio.

### 9.3 Mudança de Aliança

Para mudar de Aliança, o jogador também envia uma nave até o território de um membro do novo grupo e solicita adesão. Quando a solicitação é aceita:

- O jogador sai automaticamente da Aliança anterior.
- Zodíacos, estruturas, unidades e recursos continuam pertencendo ao jogador.
- O patrimônio passa a representar a nova filiação.
- Uma vulnerabilidade é criada em favor da Aliança abandonada.

### 9.4 Vulnerabilidade de cisão

Durante a vulnerabilidade, ataques da antiga Aliança causam dano multiplicado contra o desertor:

| Período após a saída | Dano recebido da antiga Aliança |
|---|---:|
| Primeiro mês | 5x |
| Segundo mês | 4x |
| Terceiro mês | 3x |
| Quarto mês | 2x |
| A partir do quinto mês | 1x |

O relógio usa o tempo real do servidor e continua correndo enquanto o jogador está offline. Mudanças sucessivas acumulam vulnerabilidades independentes contra todas as Alianças abandonadas, cada uma com seu próprio calendário.

## 10. Descoberta, comércio e diplomacia

### 10.1 Rede de contatos

Um jogador precisa descobrir outro antes de negociar com ele. O contato pode ocorrer por:

- Encontro durante uma expedição.
- Descoberta da civilização no mapa.
- Adição à lista de amigos.
- Participação na mesma Aliança.

### 10.2 Interface de negociação

Comércio e acordos são realizados por uma interface estruturada. Uma proposta identifica participantes, oferta, contrapartida, duração e condições. Esse formato permite que humanos e agentes LLM negociem sob as mesmas regras.

Os acordos previstos incluem:

- Permissão para atravessar fronteiras.
- Permissão para explorar territórios dominados.
- Acordos comerciais.
- Pacto de defesa.
- Pacto de guerra ou ofensiva conjunta.

O modelo de cumprimento, rompimento e reputação dos tratados será especificado junto ao multiplayer online; ele não é necessário para validar a jogabilidade territorial da demo.

## 11. Crédito interestelar

Crédito é a moeda comum do universo. As decisões confirmadas são:

- Jogadores podem obter créditos por comércio.
- A conquista de territórios ocupados concede créditos ou riqueza ao conquistador.
- A riqueza agregada influencia a capacidade de uma Aliança.

A natureza desses créditos de conquista - transferência do derrotado ou emissão do sistema -, a emissão inicial, os mecanismos de retirada de moeda, a inflação e a conversão de riqueza em vagas foram deliberadamente retirados do escopo atual. Esse conjunto formará uma especificação monetária própria antes da implementação da economia online.

## 12. Progressão contínua

Não existe vitória final. O progresso será comunicado por:

- Pontuação acumulada.
- Conquistas permanentes.
- Quests.
- Desafios contextuais ao longo da expansão.
- Crescimento territorial, logístico, tecnológico e diplomático.

Quests e desafios devem orientar o jogador sem transformar o universo em uma sequência linear de missões.

## 13. Escopo da primeira demo

A demo deve provar que o núcleo territorial é compreensível, estratégico e divertido.

### Incluído

- Aplicação para PC construída em Godot 4.
- Universo local gerado deterministicamente.
- Save e retomada do mesmo universo.
- Simulação em tempo real com pausa e sem aceleração.
- Câmera e elementos 3D sobre um único plano de jogo.
- Mapa estelar procedural, contínuo e navegável por arraste.
- Nave de pesquisa que revela planetas, tipos e recursos de um sistema.
- Nave colonizadora consumida e convertida em Pontos de Colônia.
- Painel do sistema com distribuição de 0 a 10 pontos por recurso.
- Ordens individuais e rotas desenhadas entre estrelas.
- Alcance máximo de ligação e expansão dessa capacidade por perfis especializados.
- Criação de ligações e Zodíacos com pelo menos três estrelas.
- Produção, transporte e estoque.
- Operário, guarda e nave colonizadora.
- Expansão, defesa e conquista territorial básica.
- Uma ou mais civilizações adversárias comandadas por LLM.
- Pontuação e desafios suficientes para sustentar o teste do ciclo principal.

### Fora da primeira demo

- Servidor persistente.
- Multiplayer entre humanos.
- Simulação enquanto o aplicativo estiver fechado.
- Delegação offline da civilização a uma LLM.
- Administração completa de Alianças.
- Mercado e modelo monetário interestelar completo.
- Diplomacia persistente entre jogadores humanos.
- Versão mobile.

## 14. Critérios de validação da demo

A demo cumpre seu objetivo quando permite:

1. Criar um universo, fechá-lo e retomá-lo sem perder o estado.
2. Arrastar e ampliar o mapa para visualizar regiões procedurais.
3. Selecionar uma estrela e enviar uma nave de pesquisa.
4. Visualizar os planetas, tipos planetários e recursos revelados.
5. Enviar uma nave colonizadora e convertê-la em Pontos de Colônia.
6. Distribuir de 0 a 10 pontos entre os recursos dos planetas.
7. Capturar recursos de um sistema isolado na velocidade básica.
8. Definir uma ação e desenhar a rota de uma nave entre estrelas.
9. Fechar um Zodíaco com pelo menos três estrelas e observar os bônus de 3x.
10. Ver um operário transportar produção até uma base ou estoque.
11. Investir a produção em expansão ou unidades.
12. Observar um adversário LLM pesquisar, colonizar e expandir usando comandos válidos.
13. Cercar uma estrela inimiga e aplicar as vantagens territoriais de conquista.
14. Perder um ponto de borda e observar o Zodíaco se reorganizar quando existir uma ligação substituta dentro do alcance.
15. Romper um Zodíaco sem ligação substituta válida e remover seus bônus.
16. Conquistar uma estrela com naves colonizadoras.
17. Acumular pontuação e receber um novo desafio sem encerrar o universo.

## 15. Próximas especificações de design

O próximo documento detalhará a experiência dos primeiros minutos da demo e transformará o ciclo principal em regras operacionais. Depois dele, o design será separado nos seguintes módulos:

1. Geração e exploração do universo.
2. Rede territorial, geometria e Zodíacos.
3. Produção, transporte e estoque.
4. Unidades, combate, invasão e conquista.
5. Agentes LLM e interface de comandos.
6. Progressão, pontuação, conquistas e desafios.
7. Interface, câmera e controles para PC.
8. Arquitetura do universo online.
9. Alianças, comércio, diplomacia e moeda interestelar.
