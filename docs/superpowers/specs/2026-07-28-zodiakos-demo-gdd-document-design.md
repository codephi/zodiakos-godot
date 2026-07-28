# Zodiakos: design editorial do GDD da demo

- **Data:** 28 de julho de 2026
- **Status:** aprovado para implementação
- **Público:** parceiros de desenvolvimento
- **Escopo:** primeira demo single-player
- **Formato de entrega:** DOCX em português

## 1. Objetivo do documento

O documento apresentará a demo de Zodiakos como um recorte vertical implementável. A leitura começa pela promessa da experiência e percorre os primeiros 15 minutos antes de detalhar os sistemas, conteúdos, parâmetros, interface e critérios de validação necessários.

O GDD deve permitir que um parceiro compreenda:

- o diferencial territorial e logístico de Zodiakos;
- o fluxo jogável que a demo precisa provar;
- quais sistemas pertencem ao recorte;
- quais regras estão confirmadas;
- quais números são parâmetros iniciais de teste;
- quais tópicos permanecem fora do escopo ou pendentes de balanceamento.

## 2. Fontes e autoridade

O conteúdo será consolidado a partir de:

1. `2026-07-12-zodiakos-game-design.md`, como fonte das regras gerais e do escopo da demo;
2. `2026-07-12-zodiakos-first-15-minutes-design.md`, como fonte principal do recorte vertical;
3. `2026-07-12-star-map-timed-travel.md`, apenas como referência de viabilidade técnica e arquitetura planejada, nunca como evidência de funcionalidade já implementada.

Em caso de diferença, a especificação dos primeiros 15 minutos prevalece para números, fluxo e garantias da região inicial. O documento não apresentará o plano técnico como software concluído.

## 3. Abordagem editorial

O GDD seguirá uma abordagem narrativa de recorte vertical:

1. apresentar a fantasia, os pilares e a proposta da demo;
2. mostrar o ciclo principal em uma leitura rápida;
3. conduzir o leitor pela experiência dos primeiros 15 minutos;
4. decompor essa experiência nos sistemas necessários;
5. encerrar com escopo, riscos, critérios de aceite e metas de playtest.

O produto online, alianças, comércio, mobile e multiplayer aparecerão somente como horizonte futuro. Combate completo e conquista inimiga serão tratados como exclusões do recorte.

## 4. Estrutura

1. Capa e ficha do projeto
2. Resumo da demo
3. Fantasia central e diferenciais
4. Pilares de design
5. Ciclo principal de jogabilidade
6. Experiência dos primeiros 15 minutos
7. Estado inicial e garantias da região natal
8. Sistemas da demo
9. Naves e ordens
10. Interface e feedback
11. Civilização adversária controlada por LLM
12. Tempo, pausa, save e retomada
13. Conteúdo e parâmetros iniciais
14. Tratamento de erros e casos de borda
15. Escopo, exclusões e dependências
16. Critérios funcionais e metas de playtest
17. Pendências de balanceamento e próximos passos

## 5. Tratamento visual

O documento usará o preset `compact_reference_guide`, adequado a uma referência de produção densa e escaneável, com capa no padrão `editorial_cover`.

Tokens principais:

- página US Letter, retrato, margens de 1 polegada;
- Calibri 11 pt, corpo com espaçamento 1,25 e 6 pt depois;
- Heading 1 em 16 pt, Heading 2 em 13 pt e Heading 3 em 12 pt;
- listas reais com marcador a 0,187 polegada e texto a 0,375 polegada;
- tabelas em geometria DXA fixa, com margens internas explícitas;
- cabeçalho discreto com nome do projeto e identificação da demo;
- rodapé com versão e número de página.

Overrides nomeados de marca:

- **Zodiakos Navy:** `#10182B`, usado em capa e títulos principais;
- **Stellar Cyan:** `#35C9D0`, usado em pequenos acentos e indicadores;
- **Nebula Violet:** `#7967D8`, usado em destaques secundários;
- **Space Mist:** `#EAF0F6`, usado em cabeçalhos de tabela e caixas informativas;
- **Deep Space:** `#F7F9FC`, fundo claro de callouts.

Os overrides não alteram a geometria nem o ritmo tipográfico do preset. O documento não dependerá de ilustrações externas; utilizará hierarquia, linhas, caixas discretas e fluxos simples construídos com elementos nativos do Word.

## 6. Formas de conteúdo

- Prosa curta para visão, fantasia e decisões de design.
- Bullets agrupados para pilares, requisitos e conteúdo.
- Sequências numeradas para fluxos e tratamento de erros.
- Tabelas somente para custos, estoque, tempos, unidades e matriz de escopo.
- Callouts para promessa da demo, regras críticas e distinção entre confirmado e balanceável.
- Linha do tempo visual para os primeiros 15 minutos.

## 7. Regras editoriais

- Usar linguagem de produção clara, sem tom publicitário excessivo.
- Separar regra confirmada, parâmetro inicial e pendência.
- Não inventar lore, recursos, classes ou mecânicas ausentes nas fontes.
- Não promover conteúdos fora da demo a requisitos do recorte.
- Explicar siglas e o papel da LLM na primeira ocorrência.
- Manter o GDD entre aproximadamente 15 e 20 páginas, priorizando legibilidade.

## 8. Validação

Antes da entrega:

1. revisar o texto contra as duas especificações de design;
2. verificar ausência de placeholders, contradições e escopo indevido;
3. auditar preset, estilos, listas e geometria das tabelas;
4. renderizar o DOCX em PNG;
5. inspecionar visualmente todas as páginas;
6. corrigir quebras, clipping, tabelas comprimidas e espaços vazios excessivos;
7. repetir a renderização até o documento estar limpo.

## 9. Critério de conclusão

O documento está pronto quando um parceiro consegue descrever o ciclo da demo, identificar seus sistemas obrigatórios, estimar frentes de trabalho e reconhecer claramente o que não deve ser implementado neste recorte.
