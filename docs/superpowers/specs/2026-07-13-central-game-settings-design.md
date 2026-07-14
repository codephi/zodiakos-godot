# Design: configurações centrais do jogo

**Data:** 2026-07-13
**Status:** aprovado

## Objetivo

Manter todos os valores ajustáveis do Zodiakos em um único arquivo `game_settings.tres`, editável pelo Inspector do Godot. Novos sistemas deverão adicionar seus parâmetros ajustáveis a esse mesmo recurso, evitando constantes de balanceamento espalhadas pelo código.

## Fonte única

O arquivo `res://config/game_settings.tres` será a única fonte dos valores de produção. O recurso ficará organizado por categorias recolhíveis no Inspector.

O script `res://scripts/config/game_settings.gd` definirá somente o esquema tipado, as categorias e a validação. Seus campos não possuirão valores de produção que possam divergir do `.tres`; o arquivo central deverá declarar explicitamente cada valor utilizado pelo jogo.

Arquivos adicionais poderão existir para testes e integração, mas não poderão duplicar valores configuráveis. Consumidores poderão receber o recurso por injeção ou carregar a mesma instância central, conforme a fronteira do sistema.

## O que é configuração

Configuração é qualquer valor que possa ser alterado para balancear, personalizar ou ajustar o comportamento e a apresentação do jogo sem mudar o algoritmo.

Entram no recurso central:

- limites, velocidade e valor inicial de câmera ou zoom;
- margens, limites e orçamento de carregamento do mapa;
- seed, escala e parâmetros da geração procedural;
- limites de quantidade, distância, raio e densidade;
- tipos visuais selecionáveis pelo gerador;
- cores, tamanhos, subdivisões e intensidade de materiais;
- parâmetros ajustáveis de iluminação e câmeras de demonstração.

Não entram no recurso central:

- índices de laço, contadores temporários e coordenadas calculadas;
- tolerâncias estritamente matemáticas que fazem parte da implementação de um algoritmo;
- nomes de classes, caminhos de scripts e sinais;
- posições e entidades que são conteúdo de uma cena, e não parâmetros globais;
- estados salvos de uma partida ou preferências pessoais do jogador.

## Categorias iniciais

### Câmera do mapa

- zoom mínimo: `20.0`;
- zoom máximo: `300.0`;
- zoom inicial: `50.0`;
- fator por passo: `0.88`;
- altura da câmera: `40.0`;
- limiar de arraste: `4.0` pixels.

### Streaming do mapa

- margem de carregamento: `10` setores;
- margem adicional de descarregamento: `1` setor;
- proporção mínima de viewport: `0.25`;
- proporção máxima de viewport: `4.0`;
- setores processados por frame: `2`.

### Universo procedural

- seed global: `0x5A4F4449414B4F53`;
- versão do gerador: `1`;
- tamanho do setor: `40.0`;
- clusters por setor: `0` a `2`;
- estrelas por cluster: `8` a `20`;
- raio de cluster: `8.0` a `18.0`;
- estrelas isoladas máximas: `3`;
- distância mínima entre estrelas: `1.5`;
- estrelas máximas por setor: `64`;
- tipos visuais: `yellow`, `red`, `white`, `orange` e `blue`.

### Visuais geométricos

- paleta de estrelas, planetas, naves, seleção, alianças e estado neutro;
- quantidade de segmentos e anéis das esferas;
- quantidade de segmentos dos anéis de seleção;
- dimensões base das naves e espessura das conexões;
- opacidade das áreas zodiacais;
- multiplicador de emissão dos materiais.

### Iluminação e demonstração

- energia da luz ambiente do mapa;
- parâmetros ajustáveis da câmera, luz e ambiente da demonstração geométrica;
- cor do proprietário utilizada pela demonstração.

As posições dos objetos da demonstração permanecem como conteúdo da cena e não serão tratadas como configurações globais.

## Arquitetura e dependências

`GameSettings` será um `Resource` tipado. O `.tres` será carregado uma vez por caminho e tratado como somente leitura durante a execução.

Os adaptadores Godot, como câmera, streaming e visuais, poderão consumir diretamente o recurso central. Regras de domínio receberão somente os parâmetros de que precisam por injeção, preservando a separação entre simulação e apresentação. A geração procedural continuará determinística: seed, versão e parâmetros virão do mesmo snapshot de configuração durante toda a sessão.

Nenhum sistema manterá uma cópia local de um valor configurável. Constantes estruturais continuarão próximas do algoritmo que representam.

## Validação e falhas

O recurso fornecerá uma validação que retorna todos os problemas encontrados. A inicialização e os testes deverão rejeitar configurações inválidas antes de criar o universo.

Serão validados pelo menos:

- `camera_min_zoom <= camera_initial_zoom <= camera_max_zoom`;
- fator de zoom maior que `0.0` e menor que `1.0`;
- dimensões, distâncias e raios positivos;
- mínimos menores ou iguais aos máximos correspondentes;
- margens e orçamentos de streaming não negativos;
- proporção mínima positiva e menor ou igual à máxima;
- lista de tipos visuais não vazia e sem valores vazios;
- limite máximo por setor suficiente para comportar a geração configurada.

O jogo não substituirá silenciosamente um valor inválido por outro. O erro deverá identificar o campo e impedir a inicialização daquele sistema.

## Migração

A migração manterá os valores atuais, portanto não deverá alterar o mapa gerado, a aparência ou a sensação do zoom. Cada consumidor será atualizado para ler o recurso central, e as constantes antigas serão removidas depois que os testes provarem a equivalência.

O arquivo `AGENTS.md` receberá a regra: todo novo valor ajustável de jogo, mapa, câmera, geração ou apresentação deve ser declarado no esquema e configurado em `game_settings.tres`. Valores internos que não são ajustáveis permanecem no código.

## Testes

- carregar `game_settings.tres` e confirmar que todos os grupos atuais possuem valores válidos;
- testar cada relação inválida importante com um recurso criado em memória;
- provar que câmera, streaming e geração usam valores fornecidos pelo recurso;
- confirmar que a seed e os parâmetros migrados preservam a saída procedural existente;
- executar a suíte completa e o smoke test do Godot;
- verificar que não restaram constantes configuráveis duplicadas nos consumidores migrados;
- manter todos os arquivos manuscritos abaixo de 1.000 linhas.

## Fora de escopo

- menu de configurações para o jogador;
- alteração de configurações durante uma sessão;
- configurações específicas de uma partida salva;
- preferências locais como volume, resolução e atalhos;
- sincronização de configurações por servidor.
