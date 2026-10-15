class_name HuntPresenceView extends Node
## FATIA A16.1E — gerente CLIENT-SIDE de avatares remotos (§26/§31). Recebe a lista de HuntPresenceSnapshot (do
## servidor, via HUNT_QUERY PRESENCE) e CRIA/atualiza/remove RemoteHunterAvatar nodes. Interest management já vem do
## servidor (só a mesma shard §90). NÃO é autoridade local (§25): só reflete o snapshot. Remoção sem ghost (§31).

var _avatars: Dictionary = {}   # character_id → RemoteHunterAvatar

## Aplica a lista de presença (snapshots públicos). Cria os novos, atualiza os existentes, remove os que saíram (§31).
func apply_presence(snapshots: Array) -> void:
	var present: Dictionary = {}
	for snap in snapshots:
		var cid := str(snap.get("character_id", ""))
		if cid == "": continue
		present[cid] = true
		var av: RemoteHunterAvatar
		if _avatars.has(cid):
			av = _avatars[cid]
		else:
			av = RemoteHunterAvatar.new(); av.name = "avatar_" + cid; add_child(av); _avatars[cid] = av
		av.apply_snapshot(snap)
	# remove quem saiu do interest set (§31 sem ghost)
	var to_remove: Array = []
	for cid in _avatars:
		if not present.has(cid): to_remove.append(cid)
	for cid in to_remove:
		(_avatars[cid] as RemoteHunterAvatar).remove()
		_avatars.erase(cid)

func avatar_of(character_id: String) -> RemoteHunterAvatar:
	return _avatars.get(character_id, null)

func avatar_count() -> int: return _avatars.size()

func has_avatar(character_id: String) -> bool: return _avatars.has(character_id)
