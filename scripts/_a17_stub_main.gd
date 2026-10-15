extends Node
## Stub do host (Main) para o self-test A17: registra as chamadas dos hooks visuais de viagem da Hunt.
var entered := 0
var exited := 0
var last_ground := ""
var last_friendly := ""
var last_anchor := Vector2.ZERO
var _autoplay = null   # HuntHost faz _main.get("_autoplay") → null → sem Progression legada no teste

func on_hunt_enter(gid: String, friendly: String, anchor: Vector2) -> void:
	entered += 1; last_ground = gid; last_friendly = friendly; last_anchor = anchor

func on_hunt_exit() -> void:
	exited += 1
