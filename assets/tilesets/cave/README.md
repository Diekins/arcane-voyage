# Tileset da Caverna Esquecida (GODOT-CAVE-TILESET-1)

Primeiro tileset/props **reais** da Caverna, processados do raw do Codex.

## Fonte (raw, fundo magenta)

`_sources/crystal-cave-tileset-raw.png` (1536×1024) — chão de pedra/rachado, paredes, cristais
cianos, estalagmites, poças, trilhos, saída-arco, buracos, glow. Original em
`...\outputs\cave_tileset\raw\`.

## Processamento (Python/Pillow)

1. **Chroma-key magenta → alpha** + despill.
2. **Terrain** (`cave_floor`/`cave_floor2`): recortados da 1ª linha (grade), centro interno → **64×64
   opacos** (pedra escura; floor2 tem glints cianos).
3. **Props** (`crystal`/`crystal2`/`stalagmite`/`rock`/`pool`/`cave_exit`): segmentados por
   **connected-components**, bbox apertado, normalizados por altura, **alpha preservado**.

## Como é usado (Main.gd → `_build_cave_map`)

- **chão**: `Sprite2D` único `texture_repeat` + `region_rect=mapa` (pedra por toda a Caverna);
  base escura de segurança por baixo; bordas escuras (`_add_map_borders`).
- **arena do Golem**: 4 `crystal.png` ao redor de `CAVE_GOLEM`, marcando o boss space.
- **biome**: estalagmites + crystal2 espalhados, poça decorativa, buraco.
- **saída**: `cave_exit.png` (arco) no `CAVE_PORTAL`, com **paredes laterais bloqueantes** e a
  **boca aberta** p/ o `[E]`.

## Colisão (blockers, GODOT-WORLD-FEEL-2)

Cristais grandes, estalagmites e as paredes da saída entram em `_blockers` (Rect2) → o Errante
**não atravessa**. Poça/buraco/crystal2 pequenos são **atravessáveis**. O Golem **não** é bloqueado
(é alvo de combate). **Mobs ainda atravessam** obstáculos (limitação temporária).

## Limitações

- Floor tilado pode mostrar leve **costura**; **sem autotiling** (paredes são moldura + props,
  não bordas auto-conectadas); **sem depth-sort**.
- Trilhos/minecart/barris/lanterna/glow do raw **não usados** (reservados).
