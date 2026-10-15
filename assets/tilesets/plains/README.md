# Tileset da Planície dos Novatos (GODOT-PLAINS-TILESET-1)

Primeiro tileset/props **reais** da Planície, processados dos raws do Codex.

## Fonte (raws, fundo magenta)

`_sources/plains-tileset-core-raw.png` (grama/terra/transições/caverna/props) e
`_sources/plains-props-supplement-raw.png` (árvores/arbustos/pedras/ruínas/cerca/lago — **ainda
não usado**, reservado p/ depois). Originais do Codex em
`...\outputs\plains_tileset\raw\`.

## Processamento (Python/Pillow, script pontual)

1. **Chroma-key magenta → alpha** (`r>140 e b>140 e g<120 e r−g>55 e b−g>55`) + **despill** do
   halo magenta (reduz r/b onde ambos ≫ g).
2. **Terrain** (`grass`/`grass2`/`dirt`): recortados da 1ª linha do core (grade ~130px), centro
   interno (84%) → **64×64 opacos**.
3. **Props** (`tree`/`tree2`/`bush`/`rock`/`cave`/`log`/`flowers`): segmentados por
   **connected-components** (BFS na máscara), bbox apertado, normalizados por altura-alvo,
   **alpha preservado**.

## Como é usado (Main.gd → `_build_plains_map`)

- **grama**: `Sprite2D` único com `texture_repeat=ENABLED` + `region_rect=mapa` (tile a grama por
  todo o mundo). Há uma **base verde** (`ColorRect` z-21) por baixo como rede de segurança.
- **caminho de terra**: outro `Sprite2D` tiled numa faixa horizontal central.
- **props**: `Sprite2D` espalhados nas bordas (clareira jogável no meio); a **entrada da caverna**
  (`cave.png`) fica no portal `PLAINS_PORTAL`.

## Limitações

- **Sem colisão** (props/bordas são visuais — dá p/ atravessar).
- **Sem autotiling**: a transição grama↔terra é um corte reto (faixa), não bordas suaves; o tile de
  grama repetido pode mostrar leve costura.
- `grass2`/`log` extraídos mas ainda não usados no layout. Supplement inteiro reservado.
- **Só a Planície**; a Caverna segue com shapes (tileset próprio = pacote futuro).
