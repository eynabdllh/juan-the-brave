extends Node
class_name MultiplayerManager

const DEFAULT_PORT := 24555
const MAX_CLIENTS := 8

var is_server: bool = false
var _peer: ENetMultiplayerPeer
var _spawned_players := {} # peer_id -> Node
var _active_slippers := {} # owner_peer_id -> Node (server-only)
func _ready() -> void:
	# Do nothing until menu calls us
	pass

func start_local() -> void:
	# Start a local authoritative server and go straight to world
	if not multiplayer.multiplayer_peer:
		_peer = ENetMultiplayerPeer.new()
		var err := _peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
		if err != OK:
			push_error("Failed to create server: %s" % err)
			return
		multiplayer.multiplayer_peer = _peer
		is_server = true
		_connect_mp_signals()
	# Mark for local coop so world spawns Player 2
	if has_node("/root/global"):
		get_node("/root/global").local_coop = true
	_goto_world()

func start_host() -> void:
	# Normal host (LAN). No local coop by default
	if multiplayer.multiplayer_peer:
		return
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if err != OK:
		push_error("Failed to create server: %s" % err)
		return
	multiplayer.multiplayer_peer = _peer
	is_server = true
	_connect_mp_signals()
	if has_node("/root/global"):
		get_node("/root/global").local_coop = false
	_goto_world()

func start_client(host_ip: String) -> void:
	# Join LAN host
	if multiplayer.multiplayer_peer:
		return
	if host_ip.is_empty():
		host_ip = "127.0.0.1"
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(host_ip, DEFAULT_PORT)
	if err != OK:
		push_error("Failed to connect: %s" % err)
		return
	multiplayer.multiplayer_peer = _peer
	is_server = false
	_connect_mp_signals()
	if has_node("/root/global"):
		get_node("/root/global").local_coop = false
	_goto_world()

func _connect_mp_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)

func _goto_world() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")

@rpc("authority", "reliable")
func _rpc_request_spawn_player(requester_id: int) -> void:
	# Placeholder for future networked player spawn; safe no-op for current singleplayer world
	if not is_server:
		return
	if _spawned_players.has(requester_id):
		return
	# Implement actual spawn later when networked_player.tscn is available
	_spawned_players[requester_id] = null

func request_spawn_self() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	rpc_id(1, "_rpc_request_spawn_player", multiplayer.get_unique_id())

@rpc("authority", "reliable")
func _rpc_throw_slipper(owner_peer_id: int, start_pos: Vector2, dir: Vector2, speed: float) -> void:
	# Placeholder server-side slipper creation; safe no-op if scene not present
	if not is_server:
		return
	if _active_slippers.has(owner_peer_id):
		var prev = _active_slippers[owner_peer_id]
		if is_instance_valid(prev):
			prev.queue_free()
		_active_slippers.erase(owner_peer_id)
	var scene: PackedScene = load("res://scenes/slipper.tscn")
	if scene == null:
		return
	var s := scene.instantiate()
	s.name = "Slipper_%d" % owner_peer_id
	s.global_position = start_pos
	s.set("owner_peer_id", owner_peer_id)
	if s.has_method("server_launch"):
		s.server_launch(dir, speed)
	get_tree().current_scene.add_child(s)
	_active_slippers[owner_peer_id] = s

@rpc("authority", "reliable")
func _rpc_despawn_slipper(owner_peer_id: int) -> void:
	if not is_server:
		return
	if _active_slippers.has(owner_peer_id):
		var s = _active_slippers[owner_peer_id]
		if is_instance_valid(s):
			s.queue_free()
	_active_slippers.erase(owner_peer_id)

func _on_peer_connected(id: int) -> void:
	if is_server:
		_rpc_request_spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	if is_server:
		_rpc_despawn_slipper(id)
		_spawned_players.erase(id)

func _on_connection_failed() -> void:
	push_error("Connection failed.")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	push_error("Disconnected from server.")
	multiplayer.multiplayer_peer = null
