extends Node

# Persistent network hub that lives at /root/NetHub across scene changes
# Carries cross-scene RPCs to avoid "Node not found" errors when scenes switch

var game_started: bool = false

func _ready():
	name = "NetHub"
	# Persist across scene changes
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure we are attached under /root
	if get_parent() != get_tree().root:
		get_tree().root.add_child(self)
		owner = null
	print("[NetHub] Ready. Is server=", multiplayer.is_server())

func _get_lobby() -> Node:
	return get_node_or_null("/root/MultiplayerLobby")

func _get_world() -> Node:
	return get_node_or_null("/root/world")

# Host -> Clients: announce game started in a scene-agnostic way
@rpc("any_peer", "call_local", "reliable")
func relay_game_started():
	print("[NetHub] relay_game_started received on peer ", multiplayer.get_unique_id())
	game_started = true
	var lobby := _get_lobby()
	if lobby and lobby.has_method("_on_game_started"):
		lobby._on_game_started()
		return
	# Fallback: transition directly if lobby node is gone
	print("[NetHub] Lobby node missing, transitioning directly to world")
	get_tree().change_scene_to_file("res://scenes/world.tscn")

# Client -> Server: ask for game status (works even if server left lobby)
@rpc("any_peer", "call_remote", "reliable")
func request_game_status():
	var sender := multiplayer.get_remote_sender_id()
	print("[NetHub] request_game_status from ", sender, ", started=", game_started)
	rpc_id(sender, "apply_game_status", game_started)

# Server -> Client: apply game status
@rpc("any_peer", "call_local", "reliable")
func apply_game_status(started: bool):
	print("[NetHub] apply_game_status started=", started)
	if started:
		relay_game_started()

# Client -> Server: tell server the client's world scene is ready
@rpc("any_peer", "call_remote", "reliable")
func client_world_ready(peer_id: int):
	var world := _get_world()
	if world and world.has_method("_on_client_world_ready"):
		world._on_client_world_ready(peer_id)
		return
	print("[NetHub] Warning: Server world not ready to receive client_world_ready from ", peer_id)
