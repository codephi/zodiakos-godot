# Zoom estendido do mapa estelar

## Objetivo

Permitir que o jogador afaste a câmera até visualizar uma área maior do mapa estelar, sem alterar a interação atual nem permitir zoom ilimitado.

## Comportamento aprovado

- O zoom ortográfico inicial permanece em `50.0`.
- O limite de aproximação permanece em `20.0`.
- O limite de afastamento passa de `90.0` para `300.0`.
- A roda do mouse continua controlando o zoom com o fator atual.
- O valor permanece limitado; não haverá zoom infinito nem aceleração adicional nesta mudança.
- O HUD continuará exibindo o tamanho ortográfico corrente.

## Arquitetura

O `MapCameraController` passa a limitar o afastamento em `300.0`. Como o streaming atual usa um raio fixo adequado ao limite anterior, ele também deverá receber a extensão visível da câmera e calcular quantos setores são necessários em cada eixo.

O cálculo multiplica largura e altura visíveis pela escala configurada `10.0`
antes do arredondamento por setores. Uma margem fixa de um setor é aplicada
depois do arredondamento, e a descarga mantém sua margem adicional de histerese.

Para manter a cobertura finita em janelas degeneradas e em formatos extremos de PC ou mobile, a proporção usada pelo streaming será limitada ao intervalo `0.25..4.0`. A viewport real não será redimensionada; somente o cálculo preventivo de setores adotará esse limite seguro.

Ao mudar o zoom ou o tamanho da viewport, o controlador atualizará a projeção e enfileirará apenas os setores novos. Setores já ativos não serão regenerados. O carregamento continuará progressivo e limitado por frame.

O domínio procedural e a materialização visual permanecem inalterados. Mesmo no limite `300.0`, somente uma região finita ao redor da câmera ficará ativa.

## Testes e aceite

- O teste de câmera deve provar que afastar além do limite fixa o tamanho exatamente em `300.0`.
- Os testes de projeção devem provar os raios horizontal e vertical para o zoom máximo em uma viewport 16:9.
- Os testes de streaming devem provar que afastar aumenta a cobertura, aproximar descarrega com histerese e setores ativos não são regenerados.
- A suíte completa do Godot deve continuar passando.
- O smoke test da cena principal deve iniciar sem erros.
- No preview incorporado, com o modo **Entrada** ativo, a roda deve alcançar `300.0`, não ultrapassar esse valor e continuar mostrando estrelas por toda a área visível.

## Fora do escopo

- Zoom centrado no cursor.
- Níveis de detalhe por distância.
- Alterações no tamanho ou na quantidade de estrelas.
- Limite configurável pelo jogador.
