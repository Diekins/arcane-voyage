# Créditos e licenças

## Motor

- **Godot Engine 4.6** — licença MIT. <https://godotengine.org/license>

## Arte de terceiros

| Recurso | Autor / fonte | Licença | Onde é usado |
|---|---|---|---|
| Tileset **"Dirt and Grass – Forager Inspired"** (tiles 16×16, autotile de 47 peças para grama e terra) | OpenGameArt — <https://opengameart.org/content/dirt-and-grass-forager-inspired> | **CC0** (domínio público; atribuição não exigida, mas registrada aqui por cortesia) | Base do sistema de autotile do editor de mapas auxiliar (*Arcane Voyage Studio*, ferramenta web à parte). **Os arquivos desse tileset não fazem parte desta pasta do cliente Godot.** |

Nenhum outro arquivo de licença, atribuição ou crédito de terceiros foi encontrado no projeto
(busca por `LICENSE`, `CREDITS`, `CC0`, `CC-BY`, `OpenGameArt`, `itch.io`, `Kenney`, `Freesound`).
O projeto não embarca fontes tipográficas próprias (usa a fonte padrão do Godot).

## Arte e áudio produzidos no projeto

- **Sprites, tilesets, HUD, VFX e mockups de interface** em `assets/` foram gerados durante o
  desenvolvimento com ferramentas de IA e depois processados por scripts próprios (Python/Pillow em
  `tools/art/` — chroma-key, recorte em strips, validação de tiles).
- **Áudio ambiente** em `assets/audio/` foi **sintetizado proceduralmente** pelos scripts de
  `tools/audio/` (ruído moldado com NumPy/SoundFile) — não há amostras de terceiros.
- As imagens em `assets/ui/hud_target_v1/mockups/` são **composições de referência visual**
  (alvo de arte), não capturas do jogo em execução.
