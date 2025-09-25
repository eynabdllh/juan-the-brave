extends Node2D

@export var key_scene: PackedScene
@export var networked_player_scene: PackedScene

var total_enemies = 0
var enemies_defeated = 0
var multiplayer_spawner: MultiplayerSpawner
var ready_peers: Dictionary = {}
var spawned_peers: Dictionary = {}
var _spawning_started: bool = false
var spawner_ready: Dictionary = {}

func _enter_tree():
	# Ensure this scene's root name matches expected network paths
	if name != "world":
		print("[World] Renaming root from ", name, " to 'world' for network path consistency")
		name = "world"
	print("[World] _enter_tree at path: ", get_path())
	# Ensure MultiplayerSpawner exists and is registered BEFORE replication starts
	var existing := get_node_or_null("MultiplayerSpawner")
	if not existing:
		var sp := MultiplayerSpawner.new()
		sp.name = "MultiplayerSpawner"
		sp.spawn_path = NodePath(".")
		sp.spawn_limit = 10
		add_child(sp)
		multiplayer_spawner = sp
		# Configure spawnable scenes EARLY so replication can reconstruct nodes
		var scene_path := "res://scenes/networked_player.tscn"
		if networked_player_scene:
			scene_path = networked_player_scene.resource_path
		sp.clear_spawnable_scenes()
		sp.add_spawnable_scene(scene_path)
		# Use custom spawn on all peers for deterministic creation
		sp.spawn_function = Callable(self, "_world_custom_spawn")
		# Connect spawned early to switch camera ASAP
		if not sp.is_connected("spawned", Callable(self, "_on_world_spawner_spawned")):
			sp.spawned.connect(Callable(self, "_on_world_spawner_spawned"))
		print("[World] MultiplayerSpawner created and configured in _enter_tree with scene: ", scene_path)
		# Server considers its own spawner ready immediately
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			spawner_ready[1] = true
			print("[World][Server] Spawner ready (host)")
	else:
		multiplayer_spawner = existing
		# Ensure configuration exists on existing spawner too
		var scene_path2 := "res://scenes/networked_player.tscn"
		if networked_player_scene:
			scene_path2 = networked_player_scene.resource_path
		multiplayer_spawner.clear_spawnable_scenes()
		multiplayer_spawner.add_spawnable_scene(scene_path2)
		# Use custom spawn on all peers for deterministic creation
		multiplayer_spawner.spawn_function = Callable(self, "_world_custom_spawn")
		if not multiplayer_spawner.is_connected("spawned", Callable(self, "_on_world_spawner_spawned")):
			multiplayer_spawner.spawned.connect(Callable(self, "_on_world_spawner_spawned"))
		print("[World] MultiplayerSpawner already present and configured in _enter_tree with scene: ", scene_path2)
		# Server considers its own spawner ready immediately
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			spawner_ready[1] = true
			print("[World][Server] Spawner ready (host, existing)")

	# Notify the server that this world's spawner is ready
	if multiplayer.has_multiplayer_peer():
		var my_id := multiplayer.get_unique_id()
		if multiplayer.is_server():
			_on_client_world_ready(my_id)
		else:
			# Defer by one frame to ensure world and spawner are fully registered
			call_deferred("_deferred_notify_world_ready", my_id)

func _deferred_notify_world_ready(peer_id: int) -> void:
	var hub := get_node_or_null("/root/NetHub")
	# Wait briefly until the MultiplayerSpawner exists locally
	var tries := 0
	while tries < 40: # up to ~2 seconds @ 0.05s
		if get_node_or_null("MultiplayerSpawner") != null:
			break
		tries += 1
		await get_tree().create_timer(0.05).timeout
	if tries >= 40:
		print("[World][Client] Warning: MultiplayerSpawner not found after wait. Proceeding anyway.")
	# Also ensure we are fully connected before sending RPCs
	tries = 0
	while not _is_connected() and tries < 200: # up to ~10 seconds
		tries += 1
		await get_tree().create_timer(0.05).timeout
	if hub:
		hub.rpc_id(1, "client_world_ready", peer_id)
	else:
		# Fallback direct RPC to world node
		rpc_id(1, "_on_client_world_ready", peer_id)

func _ready():
	print("World scene loaded")
	print("[World] _ready at path: ", get_path())

	# Ensure NetHub exists (persistent cross-scene RPC anchor)
	if not get_node_or_null("/root/NetHub"):
		var hub_script := load("res://scripts/net_hub.gd")
		if hub_script:
			var hub = hub_script.new()
			# Avoid 'Parent node is busy setting up children' by deferring the add
			get_tree().root.call_deferred("add_child", hub)
			print("[World] NetHub instantiated under /root")
	
	# Reset per-world tracking
	ready_peers.clear()
	spawned_peers.clear()

	# Recreate multiplayer connection using preserved state
	var multiplayer_restored = false
	if has_node("/root/MultiplayerAutoload"):
		# If a peer already exists (carried over from lobby), do not recreate
		if multiplayer.has_multiplayer_peer():
			multiplayer_restored = true
		else:
			multiplayer_restored = _recreate_multiplayer_connection()
	
	print("Multiplayer peer exists: ", multiplayer.has_multiplayer_peer())
	print("Multiplayer restored: ", multiplayer_restored)
	if multiplayer.has_multiplayer_peer():
		print("Multiplayer peer ID: ", multiplayer.get_unique_id())
		print("Is server: ", multiplayer.is_server())
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	total_enemies = enemies.size()
	
	if total_enemies == 0:
		print("No enemies in this level.")
	else:
		for enemy in enemies:
			enemy.died.connect(Callable(self, "_on_enemy_defeated"))
		print("Level started with ", total_enemies, " enemies.")
	
	# Remove single player if it exists (we'll use networked players instead)
	var single_player = get_node_or_null("player")
	if single_player:
		print("Removing single player instance")
		single_player.queue_free()
	
	# Set up multiplayer spawner for networked players
	_setup_multiplayer_spawner()

	# Client: after spawner exists locally AND connection is established, ACK to server
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		var my_id := multiplayer.get_unique_id()
		call_deferred("_client_send_spawner_ready_when_connected", my_id)
	# Fallback: if we are the server and spawner_ready for 1 wasn't set in _enter_tree, set it now
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and get_node_or_null("MultiplayerSpawner") and not spawner_ready.has(1):
		spawner_ready[1] = true
		print("[World][Server] Spawner ready (host, fallback in _ready)")
	# Ensure host always spawns even if a client ACK is late
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		call_deferred("_ensure_host_spawn")
	
	# Wait a few frames so the scene tree settles
	await get_tree().process_frame
	await get_tree().process_frame
	# Give clients extra time to finish loading to avoid RPC path issues
	await get_tree().create_timer(0.8).timeout
	
	# Handshake: notify server this peer's world is ready; server will spawn after all peers ready
	if multiplayer.has_multiplayer_peer():
		var my_id := multiplayer.get_unique_id()
		var hub := get_node_or_null("/root/NetHub")
		if multiplayer.is_server():
			_on_client_world_ready(my_id)
		else:
			# Only send immediately if connected; otherwise rely on the deferred notifier
			if _is_connected():
				if hub:
					hub.rpc_id(1, "client_world_ready", my_id)
				else:
					# Fallback to direct world RPC
					rpc_id(1, "_on_client_world_ready", my_id)
	else:
		print("No multiplayer connection found - spawning single player for testing")
		_spawn_single_player_fallback()

func _setup_multiplayer_spawner():
	# Check if MultiplayerSpawner already exists in the scene
	multiplayer_spawner = get_node_or_null("MultiplayerSpawner")

	if not multiplayer_spawner:
		# Create MultiplayerSpawner for the world scene
		multiplayer_spawner = MultiplayerSpawner.new()
		multiplayer_spawner.name = "MultiplayerSpawner"
		multiplayer_spawner.spawn_path = NodePath(".")
		multiplayer_spawner.spawn_limit = 10
		add_child(multiplayer_spawner)
		print("Created new MultiplayerSpawner")
	else:
		print("Using existing MultiplayerSpawner")

	# Add networked player scene
	var scene_path = "res://scenes/networked_player.tscn"
	if networked_player_scene:
		scene_path = networked_player_scene.resource_path

	# Clear existing spawnable scenes and add ours
	multiplayer_spawner.clear_spawnable_scenes()
	multiplayer_spawner.add_spawnable_scene(scene_path)
	# Use custom spawn consistently
	multiplayer_spawner.spawn_function = Callable(self, "_world_custom_spawn")
	print("Added spawnable scene: ", scene_path)

	# Connect spawned to switch camera ASAP
	if not multiplayer_spawner.is_connected("spawned", Callable(self, "_on_world_spawner_spawned")):
		multiplayer_spawner.spawned.connect(Callable(self, "_on_world_spawner_spawned"))

# Custom spawn used by MultiplayerSpawner on all peers
func _world_custom_spawn(data: Dictionary) -> Node:
	var scene_path: String = String(data.get("scene", "res://scenes/networked_player.tscn"))
	var peer_id: int = int(data.get("peer_id", 1))
	var authority: int = int(data.get("authority", peer_id))
	var name_str: String = str(data.get("name", "Player_" + str(peer_id)))
	var pos: Vector2 = data.get("position", Vector2.ZERO)

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("[World] _world_custom_spawn: Failed to load scene: " + scene_path)
		return null
	var inst: Node = packed.instantiate()
	inst.name = name_str
	if inst is Node2D:
		(inst as Node2D).global_position = pos
	# Assign authority BEFORE the instance enters the tree (MultiplayerSpawner will add it)
	inst.set_multiplayer_authority(authority)
	var sync: MultiplayerSynchronizer = inst.get_node_or_null("MultiplayerSynchronizer")
	if sync:
		sync.set_multiplayer_authority(authority)
		# Ensure replication config exists so spawn-time state is replicated
		if sync.replication_config == null and inst.has_method("_setup_multiplayer_sync"):
			inst.call("_setup_multiplayer_sync")
	return inst

func _spawn_multiplayer_players():
	if not multiplayer.is_server():
		print("Client: Waiting for server to spawn players")
		return
	# Guard against re-entry/duplicates
	if _spawning_started == false:
		_spawning_started = true
	
	print("Server: Spawning players...")
	
	# Spawn host player (peer ID 1)
	_spawn_networked_player(1)
	
	# Spawn client players
	for peer_id in multiplayer.get_peers():
		print("Spawning player for peer: ", peer_id)
		_spawn_networked_player(peer_id)

func _on_world_spawner_spawned(node: Node) -> void:
	# Runs on all peers when a node is spawned via MultiplayerSpawner
	if node == null:
		return
	var auth_val := -1
	if node.has_method("get_multiplayer_authority"):
		auth_val = node.call("get_multiplayer_authority")
	print("[World] Spawned ", node.name, " auth=", auth_val, " path=", node.get_path())
	# Ensure visibility
	if node is Node2D:
		(node as Node2D).visible = true
	# If this is our local player, make its camera current
	if multiplayer.has_multiplayer_peer() and node.has_method("get_multiplayer_authority"):
		var auth: int = node.call("get_multiplayer_authority")
		if auth == multiplayer.get_unique_id() and node.has_node("world_camera"):
			var cam = node.get_node("world_camera")
			if cam and cam.has_method("make_current"):
				cam.call("make_current")
	# Update player name label immediately based on authority (prevents lingering default text)
	var _label := node.get_node_or_null("player_name_label")
	if _label and _label is Label and node.has_method("get_multiplayer_authority"):
		var _auth_id: int = node.call("get_multiplayer_authority")
		(_label as Label).text = "Player " + str(_auth_id)
		(_label as Label).visible = true
	# Safety: ensure synchronizer has replication config
	var sync: MultiplayerSynchronizer = node.get_node_or_null("MultiplayerSynchronizer")
	if sync and sync.replication_config == null and node.has_method("_setup_multiplayer_sync"):
		node.call("_setup_multiplayer_sync")

func _get_expected_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	ids.append(1) # Server is peer 1
	for pid in multiplayer.get_peers():
		ids.append(pid)
	return ids

func _is_connected() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return false
	var p := multiplayer.multiplayer_peer
	if p == null:
		return false
	var status := p.get_connection_status()
	return status == MultiplayerPeer.CONNECTION_CONNECTED or multiplayer.is_server()

func _client_send_spawner_ready_when_connected(peer_id: int) -> void:
	var tries := 0
	while (not _is_connected() or get_node_or_null("MultiplayerSpawner") == null) and tries < 200:
		tries += 1
		await get_tree().create_timer(0.05).timeout
	if _is_connected() and get_node_or_null("MultiplayerSpawner"):
		rpc_id(1, "client_spawner_ready", peer_id)
		print("[World][Client] Spawner ready ACK sent for ", peer_id)

@rpc("any_peer", "call_remote", "reliable")
func client_spawner_ready(peer_id: int) -> void:
	# Only server processes the ACK
	if not multiplayer.is_server():
		return
	spawner_ready[peer_id] = true
	print("[World][Server] Spawner ready from ", peer_id, " => ", spawner_ready.keys())

@rpc("any_peer", "call_remote", "reliable")
func _on_client_world_ready(peer_id: int) -> void:
	# Only the server coordinates spawning
	if not multiplayer.is_server():
		return
	ready_peers[peer_id] = true
	var expected_ids := _get_expected_peer_ids()
	print("World: Ready from ", peer_id, ". Have=", ready_peers.keys(), " Expected=", expected_ids)
	if spawned_peers.is_empty():
		# First-time spawn: require ALL expected IDs to be ready
		var all_ready := true
		for id in expected_ids:
			if not ready_peers.has(id):
				all_ready = false
				break
		# Also require spawner-ready ACKs from each peer
		if all_ready:
			for id in expected_ids:
				if not spawner_ready.has(id):
					all_ready = false
					break
		if all_ready:
			# Additional guard: avoid spawning host-only while clients are still transitioning
			# If there are connected peers, wait until at least 2 peers are ready (host + one client)
			var connected_count := multiplayer.get_peers().size()
			if connected_count > 0 and ready_peers.size() < 2:
				print("[World][Server] Clients exist but not yet ready; deferring spawn...")
				return
			# Grace period to ensure clients have registered world + spawner
			print("[World][Server] All peers ready. Waiting grace before spawning...")
			# Extra grace frames and time to ensure spawners are registered on all peers
			await get_tree().process_frame
			await get_tree().create_timer(1.0).timeout
			await get_tree().process_frame
			# Re-check spawner_ready for all expected peers right before spawning
			var still_all_ready := true
			for id in expected_ids:
				if not spawner_ready.has(id):
					still_all_ready = false
					print("[World][Server] Waiting for spawner_ready from ", id)
					break
			if not still_all_ready:
				# Wait a bit more for late spawner registration
				await get_tree().create_timer(2.0).timeout
			# Final check and spawn
			if not _spawning_started:
				_spawning_started = true
				_spawn_multiplayer_players()
	else:
		# Late joiner: spawn only that peer if not spawned yet
		if not spawned_peers.has(peer_id):
			await get_tree().create_timer(0.2).timeout
			_spawn_networked_player(peer_id)

func _spawn_networked_player(peer_id: int):
	print("Creating networked player for peer: ", peer_id)
	# Skip if already exists (prevents duplicates on late handshake)
	if is_instance_valid(multiplayer_spawner):
		var existing := multiplayer_spawner.get_node_or_null("Player_" + str(peer_id))
		if existing:
			print("[World] Player_" + str(peer_id) + " already exists under MultiplayerSpawner; skipping")
			spawned_peers[peer_id] = true
			return
	# Compute a visible base spawn position so players appear on-screen
	var base_spawn: Vector2 = Vector2(400, 300)
	var host_player = get_node_or_null("MultiplayerSpawner/Player_1")
	if host_player and host_player is Node2D:
		base_spawn = (host_player as Node2D).global_position
	elif get_node_or_null("SpawnPoint") and get_node_or_null("SpawnPoint") is Node2D:
		base_spawn = (get_node("SpawnPoint") as Node2D).global_position
	else:
		var vp := get_viewport()
		if vp and vp.has_method("get_camera_2d") and vp.get_camera_2d():
			var cam := vp.get_camera_2d()
			if cam.has_method("get_screen_center_position"):
				base_spawn = cam.get_screen_center_position()
			elif cam is Node2D:
				base_spawn = (cam as Node2D).global_position
	var offset := Vector2((peer_id - 1) * 30, 0)
	var candidate := base_spawn + offset
	# Find the nearest clear spot so the player does not get stuck on spawn
	var final_pos := _find_clear_spawn(candidate)
	print("[World] Base spawn=", base_spawn, " final_pos=", final_pos)

	# Build custom spawn data and replicate via MultiplayerSpawner
	var scene_path := networked_player_scene.resource_path if networked_player_scene else "res://scenes/networked_player.tscn"
	if not is_instance_valid(multiplayer_spawner):
		push_error("[World] MultiplayerSpawner missing; cannot spawn networked player")
		return
	var data := {
		"scene": scene_path,
		"peer_id": peer_id,
		"authority": peer_id,
		"name": "Player_" + str(peer_id),
		"position": final_pos
	}
	multiplayer_spawner.spawn(data)
	print("Player spawn requested via MultiplayerSpawner (custom) for peer: ", peer_id)
	spawned_peers[peer_id] = true

# Find a clear spawn location near a candidate point by probing a few offsets
func _find_clear_spawn(start_pos: Vector2) -> Vector2:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = 6.0 # slightly larger than main collision radius (4) for safety
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = 1 | 2 # world and players
	# Probe in a small spiral: 0, ±32, ±64 in 8 directions
	var steps := [
		Vector2(0, 0),
		Vector2(32, 0), Vector2(-32, 0), Vector2(0, 32), Vector2(0, -32),
		Vector2(32, 32), Vector2(-32, 32), Vector2(32, -32), Vector2(-32, -32),
		Vector2(64, 0), Vector2(-64, 0), Vector2(0, 64), Vector2(0, -64)
	]
	for off in steps:
		params.transform = Transform2D(0.0, start_pos + off)
		var result := space_state.intersect_shape(params, 1)
		if result.is_empty():
			return start_pos + off
	return start_pos

# Fallback for single player testing
func _spawn_single_player_fallback():
	print("Spawning single networked player for testing")
	var player_scene_path = "res://scenes/networked_player.tscn"
	var player_scene_resource = load(player_scene_path)
	var player_instance = player_scene_resource.instantiate()
	player_instance.name = "Player_1"
	player_instance.global_position = Vector2(200, 200)
	add_child(player_instance)

# Server-side safety: ensure host appears even if ACKs race
func _ensure_host_spawn() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	# Wait a bit for scene to finish loading
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(multiplayer_spawner):
		return
	var host := multiplayer_spawner.get_node_or_null("Player_1")
	if host:
		return
	print("[World][Server] Fallback: Host player missing after delay; spawning now")
	_spawn_networked_player(1)

# Recreate multiplayer connection using preserved state
func _recreate_multiplayer_connection() -> bool:
	var autoload = get_node("/root/MultiplayerAutoload")
	var state = autoload.get_multiplayer_state()
	
	print("Recreating multiplayer connection...")
	print("State: ", state)
	
	if state.is_server:
		# Recreate server
		var peer = ENetMultiplayerPeer.new()
		var error = peer.create_server(state.port, 4)  # Max 4 clients
		if error != OK:
			print("Failed to recreate server: ", error)
			return false
		multiplayer.multiplayer_peer = peer
		print("Server recreated successfully")
		return true
	else:
		# Recreate client connection
		if state.host_ip != "":
			var peer = ENetMultiplayerPeer.new()
			var error = peer.create_client(state.host_ip, state.port)
			if error != OK:
				print("Failed to recreate client: ", error)
				return false
			multiplayer.multiplayer_peer = peer
			print("Client connection recreated successfully")
			return true
	
	return false

func _on_enemy_defeated(enemy_position: Vector2):
	enemies_defeated += 1
	print("Enemy defeated! ", enemies_defeated, "/", total_enemies)
	
	if enemies_defeated >= total_enemies:
		print("All enemies defeated! Spawning key.")
		spawn_key(enemy_position)

func spawn_key(spawn_position: Vector2):
	var key_instance = key_scene.instantiate()
	key_instance.position = spawn_position
	add_child(key_instance)
	
	# This line is where the connection happens.
	key_instance.collected.connect(on_key_collected)

func on_key_collected():
	print("Key has been collected by the player!")
	global.player_has_key = true
	# You can play a success sound here, like a triumphant fanfare.

func _on_door_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):  # Updated to match networked players group
		print("Player has touched the door area. Transitioning to door_side scene.")
		global.go_to_door_side()
