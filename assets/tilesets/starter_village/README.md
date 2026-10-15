# Tileset / assets — Vila dos Novatos (GODOT-STARTER-VILLAGE-1)

Assets da **Vila dos Novatos** (`starter_village`), o hub inicial seguro. Processados dos 3 raws
do Codex (chroma-key magenta/verde → alpha + connected-components + escala), em `_sources/`.

## Conteúdo

### Landmarks (escala por altura) — `starter_village/`
| Arquivo | O que é | ~px |
|---|---|---|
| `guild_hall.png` | Salão da guilda (telhado azul, maior) | 259×200 |
| `tavern.png` | Taverna/estalagem (telhado verde, espadas) | 202×190 |
| `house_red.png` | Casa (telhado vermelho) | 179×160 |
| `healer.png` | Santuário da curandeira (tenda branca/azul) | 212×165 |
| `bank.png` | Banco/armazém (casa pequena azul) | 184×150 |
| `fountain.png` | Fonte central ornamentada | 151×132 |
| `spawn_shrine.png` | Santuário de surgimento (cristal azul) | 148×120 |
| `gate.png` | Portão/arco da vila (visual do portal → Planície) | 301×150 |
| `quest_board.png` | Mural de missões | 199×120 |
| `signpost.png` | Placa de direções | 65×112 |
| `notice.png` | Placa pequena | 85×96 |
| `plaza.png` | **Tile de praça (cobblestone, GERADO seamless 96×96)** | 96×96 |

> Grama e terra **reusam** os tiles da Planície (`../plains/grass.png`, `../plains/dirt.png`).

### Props de vida cotidiana — `starter_village/props/`
`garden`, `flowerbed`, `flowers_a`, `flowers_b`, `firewood`, `cart`, `table`, `hearth` (fogueira c/
panela), `barrels`, `barrel`, `crate`, `market`, `lantern` (poste de luz), `fence`, `dummy` (boneco
de treino), `target` (alvo de tiro ao arco), `scarecrow` (espantalho).

### Cidadãos (NPCs) — `../../actors/npcs/village/`
`elder.png` (Anciã Maelis), `guard.png` (Guarda Tomas), `farmer.png` (Fazendeiro Bran) — strips
**64×64** de **4 frames idle down-facing** cada (a 1ª linha down-facing de cada personagem no raw
de cidadãos). `talk` = pulso procedural (não há linha `talk` desenhada nesta versão).

## Como é montado (Main.gd)

- `_build_village_map`: base verde + grama (reusa Planície) + **praça de pedra** (`plaza.png` tilado)
  + **estrada de terra** (reusa `dirt`) até o portão + bordas.
- `_scatter_village_props`: prédios em anel ao redor da praça + fonte + santuário + mural + props,
  cada **prédio/fonte/portão/props grandes com blocker** na base (flores/canteiros atravessáveis).
- `_build_village`: 3 cidadãos (`_build_villager`, idle + `[E]` falar) + **portão → `plains`**.
  **Sem boss/mob** (hub seguro).

## Limitações
- Serviços (guilda/taverna/curandeira/banco/mercado) são **visuais** — sem loja/cura/stash reais.
- Cidadãos: **só idle + fala** (sem walk/patrulha; `talk` procedural).
- **Sem autotiling/depth-sort**; sobreposição por `z_index` fixo.
- Região **client-side** (ainda fora do `regions.json`); nome via `Main._region_display_name`.
- Nem todos os pedaços dos raws foram usados (priorizei os mais limpos) — reprocessar de `_sources/`.
