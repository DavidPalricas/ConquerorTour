# ConquerorTour

Jogo de tabuleiro multijogador online (2 a 8 jogadores) para browser desktop, com reis da
Época dos Descobrimentos. Godot 4.7, GDScript, WebRTC por PeerJS, custo zero.
As regras estão em [idea.md](idea.md).

## Estrutura (`game/`)

| Pasta | O que tem |
| --- | --- |
| `core/` | Regras puras, sem interface nem rede: estado serializável, economia, banco (Lucifer), vitória, resolução do turno, bot |
| `engine/` | `MatchEngine`: máquina de estados do turno (um estado por fase), só corre no host |
| `config/` | `game_config.tres`: todos os valores económicos, multiplicadores e tempos |
| `network/` | `Transport` (interface), `PeerJsTransport` (web) e `LocalTransport` (editor/desktop) |
| `autoloads/` | `EventBus` (só sinais), `Session` (sala, host/cliente), `Settings` (idioma, nome, cor) |
| `board/` | `BoardTile` e `Board` (`@tool`), bandeiras, ícones e construções |
| `players/` | Rei (sprite base + roupa tingida) e paleta das 8 cores |
| `ui/` | Menu, lobby e ecrã da partida |
| `patterns/` | Padrões reutilizados: `Require` e FSM (`FSM`, `State`, `Transition`) |
| `translations/` | `strings.csv` (`en_GB`, `pt_PT`) |
| `tests/` | Testes headless das regras e partida completa de ponta a ponta |
| `tools/` | Gerador da arte provisória |

## Editar o tabuleiro

Abrir `board/board.tscn`. Cada casa é uma instância de `board_tile.tscn`: no Inspetor muda-se
o tipo, o nome (chave de tradução) e o império. A ordem dos nós é a ordem de jogo e as
posições são calculadas a partir dela.

## Correr

No editor ou no desktop, "Criar sala" abre uma sala local onde se adicionam jogadores que
partilham o ecrã (modo de desenvolvimento). O jogo online só funciona no export Web.

```
godot --headless --path game --import
godot --headless --path game res://tests/test_runner.tscn    # regras
godot --headless --path game res://tests/smoke_match.tscn    # partida completa
godot --headless --path game --export-release "Web" ../build/web/index.html
```

O export Web tem de ser servido por HTTP (por exemplo `python -m http.server` em `build/web`).

## Publicar

O workflow `.github/workflows/deploy.yml` corre os testes, exporta e publica no GitHub Pages a
cada push para `main`. Nas definições do repositório: Pages > Source > "GitHub Actions".
