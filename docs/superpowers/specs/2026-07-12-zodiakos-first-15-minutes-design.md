# Zodiakos: primeiros 15 minutos da demo

- **Versão:** 0.2
- **Data:** 12 de julho de 2026
- **Status:** recorte vertical para revisão
- **Documento-base:** [Game Design v0.10](2026-07-12-zodiakos-game-design.md)

## 1. Objetivo

Os primeiros 15 minutos devem provar o ciclo mais importante de Zodiakos:

1. Navegar pelo mapa estelar.
2. Escolher entre sondar um sistema ou colonizá-lo diretamente.
3. Colonizar seus planetas.
4. Distribuir Força de Trabalho.
5. Produzir uma nova nave.
6. Dominar três sistemas.
7. Ligá-los e formar o primeiro Zodíaco.
8. Perceber imediatamente o benefício territorial de 3x.

O recorte termina quando o jogador fecha seu primeiro Zodíaco. O universo não termina; uma nova quest apresenta sinais da civilização LLM e conduz ao próximo ciclo.

## 2. Princípios da experiência inicial

### 2.1 Aprender fazendo

Não existe tutorial separado. Uma cadeia curta de quests contextuais apresenta uma ação quando ela se torna útil. Os controles do mapa continuam livres durante todo o fluxo.

### 2.2 Objetivos por estado

As quests não dependem de uma estrela específica nem de um cronômetro rígido. Elas observam o estado do universo. Qualquer sistema elegível pode satisfazer pesquisa, colonização e ligação.

### 2.3 Sem espera vazia

Viagens e construções iniciais são curtas. Enquanto uma nave viaja ou um projeto avança, o jogador pode mover a câmera, inspecionar sistemas ou preparar a próxima ordem.

### 2.4 Sem bloqueio procedural

A geração continua procedural e determinística, mas a região natal precisa garantir sistemas válidos, recursos suficientes e uma geometria capaz de formar o primeiro triângulo.

### 2.5 Liberdade com proteção inicial

O jogador pode ignorar a sugestão da quest e escolher outras estrelas. A civilização LLM não pode atacar o núcleo inicial durante os primeiros 15 minutos.

## 3. Estado inicial

Na demo, o jogador começa como uma Civilização Emergente.

### 3.1 Sistema natal

- Um sistema já pesquisado e colonizado.
- Nível 1.
- Três planetas.
- Uma Base de Produção e um Estoque.
- Seis pontos de Força de Trabalho.
- Modo inicial: Extração.
- Distribuição inicial: quatro pontos em Metal e dois em Energia.

### 3.2 Unidades

- Uma nave de expedição nível 1.
- Uma nave colonizadora nível 1.
- Nenhum guarda.
- Nenhum operário em trânsito.

### 3.3 Estoque

| Recurso | Quantidade inicial |
|---|---:|
| Créditos | 300 |
| Metal | 30 |
| Energia | 15 |
| Influência Cultural | 0 |
| Ciência | 0 |

Metal e Energia são os dois recursos materiais do recorte vertical. O catálogo completo de recursos será definido em sua especificação própria.

### 3.4 Capacidades básicas

- Uma nave colonizadora nível 1 fornece três pontos de Força de Trabalho.
- Ela consegue iniciar presença em até três planetas.
- Cada recurso aceita de zero a dez pontos.
- Uma ligação territorial custa cinco unidades de Metal.
- O alcance básico permite conectar os três sistemas garantidos da região natal.

Esses números são constantes de teste para a demo e podem ser alterados apenas durante a etapa de balanceamento.

## 4. Garantias da região natal

O gerador procedural reserva uma região de segurança ao redor do sistema natal.

### 4.1 Sistemas próximos

- Pelo menos seis estrelas ficam visíveis nas proximidades.
- Pelo menos duas estrelas não dominadas estão dentro do alcance básico de ligação.
- O sistema natal e essas duas estrelas formam um triângulo válido.
- Nenhum dos três lados ultrapassa o alcance básico.
- O triângulo possui área visual suficiente para o preenchimento do Zodíaco ser legível.

### 4.2 Planetas e recursos

Cada um dos dois sistemas elegíveis possui:

- De dois a três planetas.
- Pelo menos um planeta com Metal.
- Pelo menos um planeta com Energia.
- No máximo três planetas, permitindo que uma nave colonizadora nível 1 estabeleça presença em todos eles.

### 4.3 Segurança

- Nenhum sistema inimigo nasce dentro do triângulo inicial.
- A civilização LLM começa fora da região de segurança.
- Durante o período de proteção, ela pode pesquisar e colonizar, mas não pode atacar o jogador.
- A proteção termina depois do primeiro Zodíaco ou após 15 minutos, o que acontecer por último.

## 5. Modelo temporal da demo

Os valores abaixo servem para calibrar a experiência e não representam o relógio final do produto online.

- Um ciclo econômico acontece a cada cinco segundos.
- Cada ponto em Metal ou Energia produz uma unidade por ciclo antes dos bônus.
- Cada ponto em Produção Industrial gera um ponto industrial por ciclo.
- Uma nave de expedição leva de 20 a 30 segundos entre estrelas da região natal.
- Uma nave colonizadora leva de 35 a 50 segundos no mesmo percurso.
- Uma nave de guerra leva de 22 a 32 segundos no mesmo percurso.
- A sondagem de um sistema leva cinco segundos após a chegada da expedição.
- A colonização acontece imediatamente quando a nave chega e é consumida.
- Nenhuma viagem consome combustível ou cobra uma tarifa adicional.
- A pausa interrompe viagens, pesquisa, economia, produção e decisões da LLM.

## 6. Custos iniciais

| Item | Créditos | Metal | Energia | Progresso industrial |
|---|---:|---:|---:|---:|
| Nave de expedição nível 1 | 60 | 5 | 5 | 30 |
| Nave colonizadora nível 1 | 100 | 10 | 5 | 60 |
| Ligação territorial | 0 | 5 | 0 | 0 |

Com seis pontos de Força de Trabalho, uma nave colonizadora exige dez ciclos industriais, ou 50 segundos. Os custos são retirados quando o projeto entra na fila.

## 7. Sequência dos primeiros 15 minutos

Os tempos são metas de experiência, não limites impostos ao jogador.

### 7.1 Minutos 0 a 2: observar e selecionar

**Quest:** `Um céu ao alcance`

O jogo começa com a câmera enquadrando o sistema natal e as estrelas próximas.

O jogador aprende a:

- Arrastar o mapa.
- Aplicar zoom.
- Selecionar uma estrela.
- Pausar e retomar a simulação.

Ao selecionar uma estrela não sondada, o painel informa posição, distância, tempo estimado por classe de nave e ações disponíveis. Recursos e planetas ainda não aparecem.

As ações `Sondar` e `Colonizar` aparecem desde o primeiro clique. `Atacar` também aparece quando houver uma nave de guerra disponível. Nenhuma delas depende de sondagem prévia.

**Conclusão:** selecionar uma estrela não sondada dentro do alcance da nave.

### 7.2 Minutos 2 a 4: pesquisar

**Quest:** `Conhecer antes de investir`

O caminho recomendado seleciona a nave de expedição, escolhe `Sondar` e arrasta uma linha do sistema natal até o destino.

Durante o desenho:

- Linha verde indica rota válida.
- Linha vermelha indica distância acima do alcance.
- O alcance máximo aparece como referência visual.
- Confirmar a linha envia a nave.

Na chegada, a sondagem revela planetas, tipos planetários, Metal, Energia e características do sistema.

A nave de expedição não é consumida. Depois da análise, ela permanece no sistema e pode receber outra rota.

O jogador pode ignorar a recomendação e enviar a nave colonizadora diretamente. Nesse caso, a quest é superada, e as informações do sistema são reveladas somente quando a colonizadora chega.

**Conclusão:** sondar um sistema ou assumir o risco de colonizá-lo diretamente.

### 7.3 Minutos 4 a 6: primeira colonização

**Quest:** `Uma nova morada`

No painel do sistema sondado, o jogador escolhe `Colonizar`. Também é possível escolher uma estrela ainda não sondada diretamente no mapa. A nave colonizadora inicial percorre a rota mais lentamente e é consumida ao chegar.

O sistema recebe três pontos de Força de Trabalho. O jogador os distribui entre os planetas e recursos usando barras horizontais de zero a dez.

Uma distribuição sugerida aparece, mas não é aplicada automaticamente.

**Conclusão:** manter pelo menos um ponto em um recurso do novo sistema.

### 7.4 Minutos 6 a 9: produção industrial

**Quest:** `Preparar a próxima expansão`

O jogador retorna ao sistema natal e muda seu modo de Extração para Produção Industrial.

O jogo explica que:

- A extração fica pausada.
- Toda a Força de Trabalho avança a fila.
- Trocar de modo pausa a fila sem perder progresso.

O jogador adiciona uma nave colonizadora nível 1 à fila. Enquanto ela é construída, a nave de expedição pode receber uma rota até o segundo sistema elegível.

**Conclusão:** concluir a segunda nave colonizadora e sondar ou selecionar outro sistema.

### 7.5 Minutos 9 a 12: terceiro sistema

**Quest:** `Três pontos definem uma fronteira`

O jogador envia a nova nave colonizadora ao segundo sistema, sondado ou não, e distribui seus três pontos de Força de Trabalho.

Agora existem três sistemas dominados:

- Sistema natal.
- Primeira colônia.
- Segunda colônia.

**Conclusão:** possuir três sistemas capazes de formar um triângulo válido.

### 7.6 Minutos 12 a 15: primeiro Zodíaco

**Quest:** `Fechar o Zodíaco`

O jogador escolhe `Criar ligação` e arrasta linhas entre os três sistemas dominados.

Rotas de nave e ligações territoriais são visualmente distintas:

- Rota é uma linha temporária associada a uma ordem de nave.
- Ligação é uma linha territorial permanente entre dois sistemas dominados.

Ao confirmar a terceira ligação:

1. O polígono é validado.
2. A região recebe preenchimento visual com a cor do jogador.
3. Um indicador mostra `Zodíaco ativo: 3x`.
4. Produção, movimento e ações dentro da área passam a receber o bônus.
5. O antes e depois da produção aparece por alguns segundos no painel.

**Conclusão:** formar o primeiro Zodíaco válido.

## 8. Transição para o jogo livre

Depois do primeiro Zodíaco:

- A cadeia de introdução é concluída.
- O jogador recebe uma conquista inicial.
- Um sinal de atividade revela a direção geral da civilização LLM.
- A próxima quest sugere produzir uma nave de guerra e preparar uma fronteira.
- Cultura, Ciência e evolução de sistemas passam a ser apresentados por quests independentes.
- A proteção contra ataques pode terminar.

O jogador continua no mesmo universo e pode ignorar qualquer nova quest.

## 9. Interface mínima

### 9.1 Barra superior

- Créditos.
- Metal.
- Energia.
- Pausa e velocidade 1x.

Influência Cultural e Ciência aparecem na barra depois da conclusão do primeiro Zodíaco, quando suas quests introdutórias são liberadas.

### 9.2 Mapa

- Estrelas e sistemas dominados.
- Naves em deslocamento.
- Rotas temporárias.
- Ligações territoriais.
- Alcance durante o desenho.
- Preenchimento dos Zodíacos.

### 9.3 Painel do sistema

- Nome e nível.
- Planetas e tipos.
- Recursos.
- Barras de Força de Trabalho.
- Modo ativo.
- Produção por ciclo.
- Fila industrial.
- Ações de sondar, colonizar, atacar e criar ligação quando aplicáveis.

### 9.4 Rastreador de quests

- Um objetivo ativo.
- Explicação curta.
- Progresso observado pelo estado do jogo.
- Opção de minimizar.

## 10. Tratamento de erros

### 10.1 Rota ou ligação fora do alcance

- A linha fica vermelha.
- A distância atual e o limite aparecem juntos.
- A ação não pode ser confirmada.
- Estrelas intermediárias válidas recebem destaque discreto.

### 10.2 Recursos insuficientes

- O item permanece visível na fila.
- Recursos ausentes são destacados.
- O painel indica qual sistema pode produzi-los.
- A ordem só entra na fila depois de todos os custos estarem disponíveis.

### 10.3 Destino ocupado durante a viagem

- A nave para no último sistema seguro da rota.
- O jogador recebe uma notificação.
- A nave aguarda uma nova ordem e não é perdida automaticamente.

### 10.4 Polígono inválido

- A ligação final mostra uma prévia sem preenchimento.
- O motivo da invalidação aparece no mapa.
- O custo da nova ligação só é consumido quando ela puder ser confirmada.
- Ligações territoriais construídas anteriormente permanecem ativas.

## 11. Save e retomada

O jogo salva automaticamente depois de:

- Pesquisa concluída.
- Colonização concluída.
- Alteração de Força de Trabalho.
- Mudança de modo.
- Entrada, pausa, retomada, conclusão ou cancelamento de projeto.
- Criação ou ruptura de ligação.
- Formação ou desativação de Zodíaco.

Ao fechar o aplicativo, um save final registra o estado completo. Ao retornar, o universo continua exatamente do ponto salvo, sem produção ou deslocamento durante a ausência.

## 12. Civilização LLM durante a introdução

A civilização adversária utiliza as mesmas ações do jogador, mas respeita a região de segurança.

- Não recebe recursos ou visão privilegiada.
- Pode sondar, colonizar diretamente, distribuir Força de Trabalho e formar seu próprio Zodíaco.
- Decide por eventos ou em intervalos de 15 segundos, nunca a cada quadro.
- Não pode emitir ordens de ataque durante a proteção inicial.
- Se uma resposta da LLM for inválida ou indisponível, mantém a ordem anterior e tenta novamente no próximo intervalo.

A primeira aparição serve como promessa do conflito futuro, não como combate obrigatório dentro dos 15 minutos.

## 13. Critérios de sucesso do recorte

### 13.1 Funcionais

- O jogador pode completar todo o fluxo sem reiniciar o universo.
- Qualquer sistema elegível pode cumprir as quests.
- O seed sempre oferece pelo menos um triângulo inicial válido.
- Save e retomada preservam todas as etapas.
- Pausar interrompe toda a simulação.
- O Zodíaco aplica o bônus de 3x imediatamente.

### 13.2 Teste de experiência

- Um novo jogador emite sua primeira ordem em até dois minutos.
- Pelo menos 80% dos testadores formam um Zodíaco em até 15 minutos sem ajuda externa.
- Pelo menos 80% identificam corretamente que sondagem revela planetas e recursos, mas não é obrigatória para colonizar.
- Pelo menos 80% compreendem que a nave colonizadora vira Força de Trabalho.
- Pelo menos 80% conseguem explicar por que fechar uma área é vantajoso.

## 14. Fora deste recorte

- Combate completo.
- Conquista de sistemas inimigos.
- Alianças.
- Comércio e diplomacia.
- Mercado e emissão monetária.
- Árvore tecnológica completa.
- Progressão detalhada de Cultura e Ciência.
- Evolução completa de sistemas e naves.
- Mobile.
- Servidor persistente.

Esses sistemas permanecem no GDD mestre, mas não bloqueiam a construção do primeiro recorte jogável.
