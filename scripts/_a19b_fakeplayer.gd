extends Node2D
## Fake player mínimo p/ os self-tests de FIELD FIX 01B: Node2D VISÍVEL no tree com `locked` (sem _ready/_process do
## PlayerController real, que exige setup de região/animator). Só o contrato que o MissionHost toca.
var locked := false
