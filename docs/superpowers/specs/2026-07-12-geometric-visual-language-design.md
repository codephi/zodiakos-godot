# Zodiakos: linguagem visual geométrica da primeira fase

## 1. Objetivo

Esta especificação define a representação visual 3D da primeira fase do Zodiakos. O objetivo é validar leitura do mapa, seleção, deslocamento e domínio territorial antes da produção da identidade visual definitiva.

Todos os elementos tridimensionais desta fase devem usar apenas meshes geométricos básicos nativos do Godot. Modelos externos, texturas detalhadas, partículas e animações complexas ficam fora do escopo.

## 2. Princípios

- Priorizar legibilidade na câmera distante e na visão superior do mapa.
- Usar cenas e materiais reutilizáveis, configurados por dados.
- Manter baixa complexidade geométrica para permitir futura extensão ao mobile.
- Comunicar função por tamanho e cor em conjunto.
- Separar a cor funcional do elemento da cor de sua civilização.
- Não criar detalhes que não contribuam para a jogabilidade da demo.

## 3. Vocabulário de meshes

| Elemento | Mesh básico | Função visual |
| --- | --- | --- |
| Estrela | `SphereMesh` | Ponto central de um sistema solar |
| Planeta | `SphereMesh` | Corpo explorável e produtor de recursos |
| Nave | `PrismMesh` | Unidade móvel orientada para seu destino |
| Indicador circular | `TorusMesh` | Seleção, domínio ou proprietário |
| Rota e ligação | `BoxMesh` fino | Conexão temporária ou territorial entre estrelas |
| Área de Zodíaco | Superfície plana semitransparente | Território fechado de uma civilização |

Nenhum desses elementos recebe um modelo artístico alternativo durante a primeira fase.

## 4. Estrelas

Cada estrela é uma esfera com material emissivo simples. Seu tamanho e sua cor representam seu tipo visual.

Tipos iniciais:

| Tipo visual | Cor | Escala relativa |
| --- | --- | --- |
| Azul | Azul-branco | 1,30 |
| Branca | Branco | 1,10 |
| Amarela | Amarelo suave | 1,00 |
| Laranja | Laranja | 0,90 |
| Vermelha | Vermelho suave | 0,80 |

Esses tipos são uma linguagem de jogo, não uma simulação astronômica rigorosa. A cor natural da estrela nunca é substituída pela cor de uma civilização.

Um `TorusMesh` no plano de jogo representa seleção ou domínio. Quando indica domínio, o anel usa a cor da civilização proprietária. Uma estrela selecionada recebe também aumento discreto de intensidade ou escala do anel, sem partículas.

## 5. Naves

Todas as classes usam a mesma base `PrismMesh`. O eixo frontal do prisma aponta para o próximo destino da rota. Não existem modelos exclusivos por classe nesta fase.

As classes são diferenciadas por tamanho e cor:

| Classe | Cor funcional | Escala relativa | Papel |
| --- | --- | --- | --- |
| Expedição | Azul-ciano | 0,70 | Sondagem rápida e reutilizável |
| Colonizadora | Amarelo-âmbar | 1,00 | Entrega de Força de Trabalho |
| Guerra | Vermelho | 1,30 | Ataque, defesa e escolta |

A civilização proprietária é indicada por um pequeno `TorusMesh` ou base circular sob a nave. Esse indicador usa a cor da civilização e não altera a cor funcional da classe.

O movimento inicial usa apenas translação e rotação no plano. Não há animação esquelética, rastro de partículas, chama de motor ou balanço tridimensional.

## 6. Planetas

Planetas são esferas simples exibidas no painel tridimensional do sistema ou quando o sistema estiver selecionado. Eles não precisam permanecer renderizados no mapa em escala distante.

O tamanho representa o porte do planeta. A cor representa seu tipo:

| Tipo | Cor base |
| --- | --- |
| Rochoso | Cinza ou marrom |
| Gasoso | Ocre ou violeta |
| Gelado | Azul-claro |
| Vulcânico | Cinza-escuro com emissão laranja simples |

Não são usadas texturas de superfície, atmosferas, anéis detalhados ou órbitas animadas. Recursos e produção são apresentados pela interface, não por detalhes aplicados ao mesh.

## 7. Rotas, ligações e território

Rotas de nave usam segmentos temporários de `BoxMesh` fino entre os pontos definidos pelo jogador. Ligações territoriais usam o mesmo princípio geométrico, mas possuem material visual diferente e permanecem no mapa.

- Rota: linha temporária, mais fina, associada à ordem de uma nave.
- Ligação: linha permanente, na cor da civilização proprietária.
- Zodíaco: superfície plana semitransparente sob as estrelas e naves.

A área do Zodíaco não deve bloquear a leitura das estrelas, naves ou ligações. A transparência e a ordem de renderização precisam evitar cintilação e sobreposição ambígua.

## 8. Componentes reutilizáveis

A implementação deve ser baseada em cenas parametrizadas:

- Uma cena de estrela recebe tipo visual, escala e estado de domínio.
- Uma cena de nave recebe classe, civilização, posição e direção.
- Uma cena de planeta recebe tipo e porte.
- Um componente de anel recebe cor, raio e estado visual.
- Um componente de segmento recebe origem, destino, espessura, cor e permanência.

Materiais devem ser compartilhados sempre que possível. Variações de cor podem usar parâmetros ou instâncias de material controladas, evitando a criação manual de recursos duplicados.

## 9. Limites técnicos

- Usar somente primitivas nativas ou superfícies planas simples geradas pelo jogo.
- Manter baixa contagem de segmentos em esferas e toros.
- Não depender de pós-processamento para comunicar informação essencial.
- Não usar colisões complexas; a seleção deve empregar volumes simples ou cálculo de distância.
- Manter todos os elementos de jogabilidade sobre o mesmo plano lógico.
- A câmera pode ser tridimensional, mas nenhuma unidade ganha liberdade de movimento fora desse plano.

## 10. Tratamento de estados inválidos

- Uma classe de nave desconhecida usa a aparência de expedição e registra um aviso de desenvolvimento.
- Um tipo de estrela desconhecido usa a aparência amarela padrão.
- Um tipo de planeta desconhecido usa a aparência rochosa padrão.
- A ausência de cor da civilização usa cinza neutro.
- Segmentos de rota com origem e destino coincidentes não são renderizados.

Esses fallbacks evitam meshes invisíveis ou falhas do mapa durante o desenvolvimento procedural.

## 11. Validação

A linguagem visual será considerada suficiente para a primeira fase quando:

1. As três classes de nave forem distinguíveis em visão superior por tamanho e cor.
2. A direção de movimento de uma nave for reconhecível pela orientação do prisma.
3. O jogador distinguir a cor natural da estrela da cor de domínio.
4. Planetas rochosos, gasosos, gelados e vulcânicos forem reconhecíveis sem texturas.
5. Rotas temporárias, ligações permanentes e áreas de Zodíaco não forem confundidas.
6. O mapa mantiver leitura clara com várias estrelas, naves e ligações simultâneas.
7. A cena funcionar com o renderizador Compatibility sem depender de partículas ou pós-processamento.

## 12. Fora do escopo

- Modelos artísticos finais de naves, estações ou estruturas.
- Texturas realistas de estrelas e planetas.
- Efeitos de partículas, rastros e explosões.
- Animações complexas e deformações.
- Variações visuais por nível de nave.
- Skins, cosméticos e identidade visual exclusiva de Alianças.
- Otimização final e níveis de detalhe específicos por plataforma.

Esses itens poderão substituir ou ampliar a linguagem geométrica somente depois que a jogabilidade principal estiver validada.
