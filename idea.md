# Prompt do projeto: clone de Business Tour (versão Descobrimentos)

Usa este documento como contexto inicial do projeto. Atualizado em 14/11/2026.

## 1. Objetivo

Criar um jogo de tabuleiro multijogador online, em 2D e só para computador (browser desktop), inspirado no Business Tour Online: um jogo ao estilo Monopoly em que se compram propriedades, se cobram rendas, se melhoram as propriedades e se levam os adversários à falência.

O jogo é só para jogar com amigos e tem de ter **custo zero**. O menu tem apenas duas ações: **criar sala** e **juntar a sala**. Sem matchmaking, sem modo solo, sem loja.

Copiar apenas as mecânicas e manter as mesmas dimensões do tabuleiro do original. Nome, arte, música, personagens e layout do tabuleiro têm de ser originais.

## 2. Tecnologias

- **Motor:** Godot 4.x com GDScript. Preferir a versão 4.3 ou superior, que permite exportação web sem threads (confirmar na documentação da versão usada).
- **Exportação:** Web (HTML5 + WebAssembly), com uma página HTML personalizada que carrega o PeerJS.
- **Deploy:** GitHub Pages, com repositório público. Publicação por GitHub Actions ou por pasta exportada.
- **Rede:** WebRTC através do PeerJS (servidor de sinalização público e gratuito), ligado ao Godot por `JavaScriptBridge`. Modelo host-autoritativo.
- **Custo:** zero. Não há servidor de jogo para alojar.

## 3. Esquemas

### 3.1 Instalação e publicação (programador)

```
Instalar Godot 4.x + templates de exportação Web
        |
        v
Criar projeto + repositório público no GitHub
        |
        v
Desenvolver em GDScript
(regras separadas da interface e da rede)
        |
        v
Exportar para Web (HTML personalizado com PeerJS)
        |
        v
git push -> GitHub Actions (ou pasta publicada) -> GitHub Pages
        |
        v
https://<utilizador>.github.io/<repositório>/
```

### 3.2 Como os amigos jogam

```
Abrir o link no browser do PC (sem instalar nada)
        |
        v
Escolher nome + cor do rei (8 cores)
        |
        +---------------------+----------------------+
        v                                            v
  [Criar sala]                                [Juntar a sala]
  O host recebe um código                     Escreve o código que
  de sala (ID PeerJS)                         o host partilhou
        |                                            |
        +---------------------+----------------------+
                              v
              Lobby (2 a 8 jogadores, estado "pronto")
                              |
                              v
                 O host inicia a partida
                              |
                              v
                    Jogo até haver vencedor
```

### 3.3 Rede (topologia em estrela)

```
              Jogador 2
                  ^
Jogador 8 <----  HOST  ---->  Jogador 3
                  v
              Jogador 4 ...

Servidor PeerJS público: só serve para o encontro inicial (sinalização).
```

- Os clientes enviam intenções ("lançar dado", "comprar", "melhorar", "propor compra", "pedir empréstimo"). O host valida, atualiza o estado do jogo e envia o novo estado a todos.
- Cada cliente liga-se apenas ao host, não aos outros clientes.
- Se o host sair, a partida termina (aceitável entre amigos).
- A lógica de regras fica separada do transporte, para poder trocar de PeerJS para outro sistema mais tarde.
- O estado do jogo (tabuleiro, propriedades, dinheiro, dívidas, turno) é serializável em JSON.

## 4. Jogadores e visual

- 2 a 8 jogadores, em 2D.
- Tema: reis cristãos da época dos Descobrimentos.
- Todos os reis usam o mesmo sprite base. **Só muda a cor da roupa:** vermelho, azul, roxo, amarelo, verde, laranja, rosa e castanho claro.

### 4.1 Estilo artístico

O estilo de referência é a arte de capa dos jogos Ocarina of Time e Majora's Mask (final dos anos 90 e início dos anos 2000). As imagens de referência estão numa pasta do projeto que o utilizador indicará (caminho a confirmar no início). Usar apenas o estilo: nunca copiar personagens, símbolos, composições ou elementos desses jogos.

Características a reproduzir:

- Ilustração pintada, com aspeto de tinta ou aerógrafo digital, e não pixel art nem vetor plano.
- Cores muito saturadas, com céus em gradiente (azuis profundos e roxos) e luzes quentes (amarelo e laranja) em contraste.
- Iluminação dramática, com brilhos suaves, luz de contorno e pequenas partículas ou estrelas.
- Personagens estilizados, com olhos grandes e expressivos e sombreado suave com textura pintada subtil.
- Composição em camadas, com um elemento central forte e muitos pormenores secundários à volta.

Aplicação ao jogo 2D:

- **Ilustrações grandes** (ecrã de título, lobby, fundo do tabuleiro, cartas da Lucifer Roulette): estilo pintado completo.
- **Elementos pequenos de jogo** (reis, casas, bandeiras, construções): versão simplificada do mesmo estilo, com contornos suaves e 2 a 3 tons de sombra, para ler bem em tamanho pequeno e ser viável de produzir.
- **Reis:** o mesmo sprite base, com a roupa numa camada separada em tons de cinzento, tingida com a cor do jogador no Godot (`modulate` ou shader), em vez de repintar 8 versões.

## 5. Regras desta versão

### 5.1 O que muda em relação ao original

| Original | Esta versão |
| --- | --- |
| Propriedades agrupadas por cor ou textura | Cidades importantes dos impérios da época. O grupo (monopólio) é definido pela **bandeira do império** a que pertencem |
| 4 praias | **4 principais igrejas cristãs** |
| Ilha perdida (prisão) | **Inferno** |
| Casa de viajar | **Chamada do Papa**: permite ir para uma cidade |
| Casa de impostos | **Imposto** de 10% do valor investido, pago ao Lucifer (ver 5.7) |
| Casas de chance | **Lucifer Roulette**, com o mesmo objetivo (eventos aleatórios bons e maus) |
| Banco | **Lucifer** é o banco: o dinheiro que lhe é pago sai do jogo e os empréstimos vêm dele |

### 5.2 Evolução das propriedades (4 níveis)

1. **Terreno** (bandeira)
2. **Barraca**
3. **Casa**
4. **Castelo** (funciona como o hotel do Monopoly)

### 5.3 Condições de vitória (iguais ao original)

Ganha quem conseguir primeiro uma destas:

- **1 monopólio em linha**
- **3 monopólios** (impérios completos)
- **As 4 principais igrejas cristãs**

Quem não consegue pagar uma dívida vai à falência, perde as propriedades e é eliminado.

### 5.4 Cidades e impérios

Os nomes das cidades podem ser arbitrários, desde que correspondam a cidades importantes dos maiores impérios e civilizações da época dos Descobrimentos. Cada império forma um grupo (monopólio) e é identificado pela sua bandeira. Impérios a usar:

- Português
- Espanhol
- Britânico
- Francês
- Otomano
- Holandês
- Chinês
- Japonês

### 5.5 Casas do tabuleiro no Godot

Cada casa do tabuleiro tem de ser fácil de editar pelo programador através do Inspetor do Godot, sem mexer em código:

- Cada casa é uma cena reutilizável (por exemplo `BoardTile`) com um script que usa variáveis `@export`.
- No Inspetor edita-se o **nome da cidade** (que é uma **chave de tradução**, por exemplo `CITY_LISBON`, ver 5.10) e o **império**, que é uma `enum`.
- A **bandeira atualiza-se automaticamente** a partir do império escolhido, incluindo no próprio editor (script `@tool`). O nome da cidade atualiza também o texto da casa.
- O monopólio é calculado a partir da `enum`: todas as casas com o mesmo império formam um grupo. Não se mantêm listas de grupos à mão.
- Montar ou rearranjar o tabuleiro resume-se a duplicar casas e alterar só o nome e o império.
- As casas especiais (partida, igrejas, Inferno, Chamada do Papa, imposto, Lucifer Roulette) seguem o mesmo princípio, com um campo de tipo.

Exemplo da estrutura esperada (caminhos de ficheiros ilustrativos):

```gdscript
@tool
extends Node2D

enum Empire { PORTUGAL, SPAIN, BRITAIN, FRANCE, OTTOMAN, NETHERLANDS, CHINA, JAPAN }

const FLAGS := {
	Empire.PORTUGAL: preload("res://flags/portugal.png"),
	# ... uma bandeira por império
}

@export var city_name: String = "":
	set(value):
		city_name = value
		_refresh()

@export var empire: Empire = Empire.PORTUGAL:
	set(value):
		empire = value
		_refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	$Label.text = city_name
	$Flag.texture = FLAGS[empire]
```

### 5.6 Regras adicionais definidas

- **Tabuleiro:** 9 casas por linha, contando os cantos, o que dá **32 casas** no total (28 fora dos cantos), com as mesmas dimensões do original. O original é para 4 jogadores e esta versão chega a 8: o tabuleiro não cresce, as peças que partilham a mesma casa ficam ligeiramente deslocadas.
- **Composição do tabuleiro (por defeito, ajustável):**
  - 4 cantos: **Partida** (ponto de partida e meta, onde se recebe o salário), **Inferno**, **Chamada do Papa** e **Imposto**.
  - 28 casas fora dos cantos: **4 igrejas**, **2 Lucifer Roulette** e **22 cidades**.
  - As 22 cidades repartem-se pelos 8 impérios: **6 impérios com 3 cidades e 2 impérios com 2 cidades**.
  - A ordem das casas é definida no editor (ver 5.5), por isso pode mudar sem tocar no código.
- **Monopólio em linha:** o jogador tem de comprar tudo numa linha do tabuleiro. As casas especiais não contam, porque não podem ser compradas. As igrejas contam.
- **Comprar e melhorar:** só se compra ou melhora uma propriedade ao cair nela. Não é preciso ter o monopólio completo para melhorar.
- **Renda de grupo:** assim que o jogador tem 2 propriedades do mesmo grupo (império), a renda de cada propriedade desse grupo aumenta 25%. O aumento é sempre de 25% e não acumula.
- **Negociação de compra** (substitui a antiga compra forçada a preço fixo): ver 5.8.
- **Igrejas:** ninguém as pode comprar ao dono, mas podem ser destruídas pela *King's Invasion*, e é isso que as distingue dos castelos. A renda de cada igreja aumenta 50% por cada igreja adicional, em valor composto. Exemplo: com uma igreja a renda é 50k, com duas cada uma passa a 75k e com três cada uma passa a 112,5k.
- **Inferno:** o jogador fica preso 3 turnos e não sai antes com os dados. Enquanto está preso não compra nem melhora propriedades, mas recebe as rendas pagas por outros jogadores que caem nas propriedades dele.
- **Chamada do Papa:** o jogador só pode ir para uma das suas propriedades ou para uma sem dono.
- **Lucifer Roulette:** sai uma carta. Cartas definidas até agora: *Lucifer Debt* (ativa-se automaticamente quando sai, e o jogador paga uma única vez a renda da propriedade onde cair, desde que seja sua; o dinheiro não vai para ninguém), *Lucifer Gift* (cada jogador dá uma quantia de dinheiro), *King's Invasion* (o jogador que tirou a carta escolhe uma propriedade de outro jogador e destrói-a por inteiro; o terreno fica livre para qualquer jogador comprar; os castelos não podem ser escolhidos, as igrejas podem) e *Shield* (protege a propriedade do jogador, quando não é um castelo, uma única vez, de ser destruída ou de ser comprada por outro, incluindo a 3x). Haverá outras, como pagar o dobro ou pagar metade.
- **Jogador que cai:** é substituído por um bot com um algoritmo simples (se tiver dinheiro, compra a propriedade onde cai). O jogador volta pelo mesmo link e com o mesmo nome e retoma o controlo.
- **Valores económicos:** dinheiro inicial, salário ao passar pela partida, preços, rendas, custo de cada nível e percentagem do imposto ficam para ajustar depois. Ficam **todos num único ficheiro de configuração** (`Resource` ou JSON), com valores provisórios, e nunca espalhados pelo código. O mesmo ficheiro guarda os tempos (por exemplo os 20 s da resposta à proposta) e os multiplicadores (1,5x, 3x, 2x do empréstimo, 10% do imposto, 25% da renda de grupo, 50% das igrejas).

### 5.7 Valor investido, imposto e Lucifer (banco)

- **Valor investido** de uma propriedade = custo base do terreno + custo base das construções, pela tabela de preços. **Nunca** depende do preço que o dono pagou numa compra. Evita que o preço suba em espiral só por trocar de dono.
- O mesmo valor serve para a negociação (5.8), o imposto e o cálculo do património.
- **Património** de um jogador = dinheiro + soma do valor investido de todas as suas propriedades (igrejas incluídas).
- **Casa de impostos:** o jogador paga **10% do seu valor investido total** (terreno, construções e igrejas) ao Lucifer. O dinheiro sai do jogo. A percentagem é ajustável.
- O **Lucifer é o banco**: o dinheiro que lhe é pago desaparece e os empréstimos vêm dele.

### 5.8 Negociação de compra

- Ao cair numa propriedade de outro jogador, o jogador **paga primeiro a renda normal** (a renda é sempre devida, haja ou não proposta).
- Depois pode fazer **uma proposta de compra por visita**, com um preço entre **1,5x e 3x o valor investido** (terreno + construções).
- **Abaixo de 3x**, o dono **aceita ou recusa**. Se recusar, não acontece mais nada (a renda já foi paga).
- **A 3x a compra é forçada:** o dono não pode recusar. É a forma de travar o líder.
- Se o dono aceitar ou for forçado, recebe o valor total pago e fica sem a propriedade (terreno e construções passam ao comprador).
- Não se podem comprar igrejas nem castelos, nem propriedades protegidas por *Shield*.
- O dono tem **20 segundos** para responder. Sem resposta, conta como recusa. Se o dono for um bot, aceita quando a oferta for pelo menos 2x.
- O dinheiro recebido pelo dono entra nas regras da penhora (5.9) se ele tiver dívida.

### 5.9 Empréstimos do Lucifer

- **Quando se pede:** só quando o jogador **não consegue pagar** um pagamento obrigatório (renda, imposto ou carta). Não se pede empréstimo por vontade própria.
- **Montante:** exatamente o que falta para pagar esse pagamento. O jogador não escolhe o valor nem fica com troco.
- **Limite:** o montante em falta tem de ser **no máximo 2x o património** do jogador. Se for superior, não há empréstimo e o jogador vai à falência.
- **Um empréstimo de cada vez.** Com dívida ativa e sem dinheiro para um novo pagamento, o jogador vai à falência.
- **Sem juros.** O custo do empréstimo é a penhora.
- **Penhora:** todo o dinheiro que o jogador receber (rendas, salário da partida, cartas, vendas) vai para o Lucifer até a dívida estar saldada. O dinheiro do próprio empréstimo fica de fora. Se receber mais do que a dívida restante, o excedente fica com o jogador.
- Na falência, a dívida desaparece e as propriedades ficam livres.

### 5.10 Idiomas (localização)

- O jogo tem **2 idiomas**: **inglês britânico (`en_GB`)** e **português de Portugal (`pt_PT`)**. O jogador escolhe no menu e a escolha fica guardada no browser.
- **Nenhum texto visível fica escrito no código ou nas cenas.** Tudo o que o jogador lê (nomes de cidades, impérios, igrejas, casas especiais, cartas da Lucifer Roulette, botões, mensagens, erros) é uma **chave** (por exemplo `CITY_LISBON`, `CARD_LUCIFER_DEBT_TITLE`, `UI_CREATE_ROOM`) com tradução no sistema do Godot.
- Usar o sistema de tradução nativo do Godot, com um ficheiro **CSV** (`translations/strings.csv`, colunas `keys`, `en_GB`, `pt_PT`), fácil de editar numa folha de cálculo. Os controlos (`Label`, `Button`) traduzem as chaves automaticamente. Para texto composto por código, usar `tr()`. Texto com valores variáveis usa marcadores (por exemplo `"{player} pagou {amount}"`), nunca concatenação, porque a ordem das palavras muda entre línguas.
- A **lógica e a rede só trocam identificadores e números**, nunca texto traduzido. Cada cliente traduz localmente, por isso dois jogadores podem jogar em línguas diferentes na mesma sala.
- Os identificadores de cartas, casas, impérios e eventos são `enum` ou chaves estáveis, nunca texto de apresentação.
- Os formatos de dinheiro seguem o idioma escolhido.
- Acrescentar uma terceira língua deve resumir-se a uma nova coluna no CSV.

### 5.11 Decisões confirmadas (14/11/2026)

- **Dados:** dois dados de 6 faces. **Dobles dão turno extra.**
- **Construção:** ao cair numa propriedade sem dono ou própria, aparece um **pop-up de compra**. Mostra **de uma vez** todos os níveis disponíveis, cada um com o seu preço acumulado (numa propriedade livre: terreno, barraca e casa; o jogador escolhe até onde constrói). O **castelo só aparece se a propriedade já tiver casa**, e então é a única opção.
- **Chamada do Papa:** o jogador escolhe a casa para onde vai (livre ou sua). Se a viagem passar pela casa de partida, **recebe o salário**.
- **Shield:** uma propriedade com Shield **não admite proposta de compra**, nem forçada a 3x. A proposta nem chega a ser feita, por isso o Shield não se gasta. Continua a gastar-se ao travar uma *King's Invasion*.
- **Falência:** o jogador **perde logo**. O dinheiro que sobra não vai para o credor e as propriedades ficam livres.
- **Cartas extra** (pagar o dobro, pagar metade): confirmadas, aplicam-se à próxima renda paga.

Implementado e testado no código (14/11/2026).

### 5.12 Ecrã da partida (14/11/2026)

- **Vista isométrica** do tabuleiro. O chão das casas (cor, bandeira, textos) acompanha a perspetiva; construções, ícones e reis ficam de pé.
- **Cartões dos jogadores** nos quatro cantos do ecrã (dois por canto a partir de 5 jogadores), com o retrato do rei na cor do jogador, o dinheiro e o nome.
  - No **Inferno**, aparece por cima do cartão um aviso a vermelho com os turnos que faltam para sair.
  - Com **dívida**, aparece no cartão um texto pequeno a vermelho com o que falta pagar.
- **Dados:** o botão de lançar fica no centro do ecrã. Os dados têm animação a rodar e, por cima, aparece o **total** (por exemplo 10, e não 5 + 5).
- **Pop-up de compra:** cada opção mostra o ícone do que se compra (terreno, barraca, casa, castelo ou igreja) por cima do nome e do preço.

## 6. A confirmar

Sem pontos em aberto nas regras acima. Se surgir uma regra ambígua durante o desenvolvimento, propor um valor por defeito e confirmar com o utilizador.

## 7. Instruções de trabalho

- Responder em português europeu e ser direto: apontar pontos fracos das decisões, em vez de concordar por defeito.
- Começar por um protótipo local com 2 jogadores no mesmo ecrã (tabuleiro, dado, compra, renda, falência). A rede só entra depois.
- Antes de construir o resto, validar a parte técnica mais arriscada: exportar um projeto Godot vazio para o GitHub Pages e ligar dois separadores do browser por PeerJS.
- Manter a lógica de jogo independente da interface e da rede.
- Usar apenas arte, nomes e sons originais ou com licença livre.
- **Textos:** desde o primeiro dia, qualquer texto visível usa chaves do CSV de tradução (5.10), mesmo nos testes e placeholders.
- **Arte provisória:** não tentar reproduzir o estilo pintado. Usar formas e cores simples como placeholders (reis, casas, bandeiras, fundo), com nomes de ficheiro estáveis, para a arte final os substituir depois sem mexer no código.
- **Primeira tarefa:** criar a estrutura do projeto Godot e a lógica de regras em GDScript puro (sem interface nem rede), cobrindo tabuleiro, dado, compra, renda, negociação, empréstimo, imposto e falência, com testes executados em modo headless. Antes de começar, confirmar o caminho do executável do Godot e a pasta da arte de referência.
- Quando faltar uma regra, propor um valor por defeito e perguntar.