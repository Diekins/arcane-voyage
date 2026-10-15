# HUD Art Pack 01

Status: `PRODUCTION_READY` for modular visual assets; mockups are reference compositions only. No HUD layout, Godot scene or gameplay code was created.

All modular PNGs are true RGBA and avoid baked labels/text. Frames are designed for separable stretch use; recommended source patch margins are generally `top=18, bottom=18, left=24, right=24` for framed panels and `top=0, bottom=0, left=32, right=32` for horizontal bars.

## Categories

- Top frame: `frames/hud_top_frame_left.png`, `hud_top_frame_center.png`, `hud_top_frame_right.png`, `hud_top_frame_divider.png`, `hud_top_frame_cap_left.png`, `hud_top_frame_cap_right.png`.
- Player medallion: `frames/player_medallion_frame.png`.
- Orbs: `orbs/hp_orb_frame.png`, `hp_orb_fill_mask.png`, `hp_orb_glass.png`, `mana_orb_frame.png`, `mana_orb_fill_mask.png`, `mana_orb_glass.png`. Mana is `PROVISIONAL_UI_ASSET`.
- Stat and activity icons: `icons/` with 13 stat icons and `hunt`, `mission`, `boss`, `repeatable`, `targeted_hunt`, `veteran`, `normal`, `locked`, `available`, `complete`; all icon-only and no baked text.
- Navigation: `navigation/` contains four button states plus hunt, missions, inventory, mastery and systems icons.
- Action bar: `action_bar/` contains left/center/right pieces and five skill-slot states.
- Objective: `objective/objective_panel_frame.png`, `objective_progress_bg.png`, `objective_progress_fill.png`.
- Minimap: `minimap/` frame, mask and player/target/boss markers. `PROVISIONAL_UI_ASSET`; no minimap logic included.
- Panels: common large/medium/header/footer/close/tab family for Systems, Inventory, Bestiary and Equipment.
- Tooltips and badges: modular frame/arrow and eight icon-only badge states.

## Mockups

- `mockups/ARCANE_HUD_TARGET_V1_MOCKUP.png`
- `mockups/ARCANE_HUD_TARGET_V1_HUNT.png`
- `mockups/ARCANE_HUD_TARGET_V1_SYSTEMS.png`

All mockups are `1920x1080` visual references with the combat center preserved. Runtime icon recommendation is `32/48/64px` from `256x256` masters. No maps, player, mob or boss assets were replaced. No helper script remains in the pack.