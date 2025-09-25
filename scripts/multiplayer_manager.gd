extends Node2D

# Multiplayer Manager for LAN P2P Architecture using ENetMultiplayerPeer
# Handles server/client initialization, connection lifecycle, and peer management
# Scene graph requirements (see README):
# - Node2D (this) as application entry point
# - MultiplayerSpawner (child) for spawning networked players
# - MultiplayerSynchronizer (child) for root-level replicated props if needed
# - CanvasLayer 'UI' with HostButton, JoinButton, IPInput, StatusLabel

# Network configuration
const DEFAULT_PORT = 7000
const MAX_CLIENTS = 4

# UI References - assigned on _ready with resilient lookup
@onready var host_button: Button
@onready var join_button: Button
@onready var ip_input: LineEdit
@onready var status_label: Label
@onready var start_game_button: Button
@onready var multiplayer_spawner: MultiplayerSpawner
@onready var players_list: ItemList
@onready var players_title: Label
@onready var main_container: Control

# Optional root synchronizer (not strictly required but recommended by spec)
var root_synchronizer: MultiplayerSynchronizer = null

# Network state
var peer: ENetMultiplayerPeer
var is_server: bool = false
var connected_peers: Array[int] = []
var _spawn_indices: Dictionary = {} # peer_id -> small spawn index
var _transitioning_to_world: bool = false
var game_started: bool = false
var lobby_peers: Array[int] = []

# Player scene to spawn for networked players
@export var player_scene: PackedScene
var player_scene_path: String = ""

func _ready():
	# Resolve required nodes with resilient search (works with nested UI containers)
	multiplayer_spawner = get_node_or_null("MultiplayerSpawner")
	var ui_layer: Node = null
	if has_node("UI"):
		ui_layer = get_node("UI")

	# Resolve optional root synchronizer
	if has_node("MultiplayerSynchronizer"):
		root_synchronizer = $MultiplayerSynchronizer

	host_button = _find_ui_control(ui_layer, "HostButton")
	join_button = _find_ui_control(ui_layer, "JoinButton")
	ip_input = _find_ui_control(ui_layer, "IPInput")
	status_label = _find_ui_control(ui_layer, "StatusLabel")
	start_game_button = _find_ui_control(ui_layer, "StartGameButton")
	players_list = _find_ui_control(ui_layer, "PlayersList")
	players_title = _find_ui_control(ui_layer, "PlayersTitle")
	main_container = _find_ui_control(ui_layer, "MainContainer")

	# Safety checks for required nodes
	if not multiplayer_spawner:
		print("Warning: MultiplayerSpawner node is missing. For spec compliance, add it as a direct child of the root scene.")
	if not host_button:
		# Fallback: search entire subtree by name
		host_button = find_child("HostButton", true, false)
	if not join_button:
		join_button = find_child("JoinButton", true, false)
	if not ip_input:
		ip_input = find_child("IPInput", true, false)
	if not status_label:
		status_label = find_child("StatusLabel", true, false)
	if not start_game_button:
		start_game_button = find_child("StartGameButton", true, false)
	if not host_button or not join_button or not ip_input or not status_label:
		print("Warning: Some UI nodes (HostButton, JoinButton, IPInput, StatusLabel) are missing. Please match the Scene Graph Specification.")

	# Connect UI signals (guarded and de-duplicated)
	if host_button and not is_instance_valid(host_button):
		host_button = null
	if join_button and not is_instance_valid(join_button):
		join_button = null
	if host_button and not host_button.is_connected("pressed", Callable(self, "_on_host_button_pressed")):
		host_button.pressed.connect(_on_host_button_pressed)
	if join_button and not join_button.is_connected("pressed", Callable(self, "_on_join_button_pressed")):
		join_button.pressed.connect(_on_join_button_pressed)
	if start_game_button and not start_game_button.is_connected("pressed", Callable(self, "_on_start_game_button_pressed")):
		start_game_button.pressed.connect(_on_start_game_button_pressed)

	# Connect multiplayer signals for connection lifecycle management (de-duplicated)
	if not multiplayer.is_connected("peer_connected", Callable(self, "_on_peer_connected")):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.is_connected("peer_disconnected", Callable(self, "_on_peer_disconnected")):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# Clients: fire when connection to server succeeds
	if not multiplayer.is_connected("connected_to_server", Callable(self, "_on_connected_to_server")):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.is_connected("connection_failed", Callable(self, "_on_connection_failed")):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.is_connected("server_disconnected", Callable(self, "_on_server_disconnected")):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	# Set default IP to localhost for testing
	if ip_input:
		ip_input.text = "127.0.0.1"
		ip_input.placeholder_text = "Enter Host IP Address (e.g., 192.168.1.100)"

	# Ensure a persistent NetHub exists at /root to carry cross-scene RPCs
	if not get_node_or_null("/root/NetHub"):
		var hub_script := load("res://scripts/net_hub.gd")
		if hub_script:
			var hub = hub_script.new()
			# Use deferred add to avoid 'Parent node is busy setting up children' during _ready
			get_tree().root.call_deferred("add_child", hub)
			print("[MultiplayerManager] NetHub instantiated under /root")

	# Configure MultiplayerSpawner
	if multiplayer_spawner:
		# Set spawn path to the spawner itself
		multiplayer_spawner.spawn_path = NodePath(".")
		
		# Resolve default player scene if export not set
		if not player_scene:
			if ResourceLoader.exists("res://scenes/networked_player.tscn"):
				player_scene = load("res://scenes/networked_player.tscn")
				print("[Multiplayer] Using networked_player.tscn as Player Scene")
			elif ResourceLoader.exists("res://scenes/player.tscn"):
				player_scene = load("res://scenes/player.tscn")
				push_warning("[Multiplayer] Falling back to player.tscn as Player Scene. For networking, duplicate it to networked_player.tscn and attach scripts/networked_player.gd with a MultiplayerSynchronizer child.")
		
		if player_scene:
			var scene_path := String(player_scene.resource_path)
			if scene_path == "":
				if ResourceLoader.exists("res://scenes/networked_player.tscn"):
					scene_path = "res://scenes/networked_player.tscn"
				elif ResourceLoader.exists("res://scenes/player.tscn"):
					scene_path = "res://scenes/player.tscn"
			# Prefer the networked player scene if available
			if ResourceLoader.exists("res://scenes/networked_player.tscn") and scene_path != "res://scenes/networked_player.tscn":
				print("[Multiplayer] Overriding player_scene to networked_player.tscn for proper replication")
				player_scene = load("res://scenes/networked_player.tscn")
				scene_path = "res://scenes/networked_player.tscn"
			player_scene_path = scene_path
			
			# Clear existing spawnable scenes and add our player scenes
			print("[Multiplayer] Configuring spawnable scenes")
			# Clear any existing spawnable scenes
			multiplayer_spawner.clear_spawnable_scenes()
			# Primary: networked_player.tscn or selected scene
			multiplayer_spawner.add_spawnable_scene(scene_path)
			print("  - Added spawnable: ", scene_path)
			# Also register base player.tscn in case instance.get_scene_file_path() resolves to it
			if ResourceLoader.exists("res://scenes/player.tscn"):
				multiplayer_spawner.add_spawnable_scene("res://scenes/player.tscn")
				print("  - Added spawnable: res://scenes/player.tscn")
		
		# Connect spawned signal only if not already connected
		if multiplayer_spawner.has_signal("spawned") and not multiplayer_spawner.is_connected("spawned", Callable(self, "_on_spawner_spawned")):
			multiplayer_spawner.spawned.connect(_on_spawner_spawned)
		
		print("[Multiplayer] MultiplayerSpawner configured - spawn_path: ", multiplayer_spawner.spawn_path)

	# Optional: warn if root-level synchronizer is missing (per spec)
	if not root_synchronizer:
		print("Info: Root MultiplayerSynchronizer not found. It's recommended by the spec but not strictly required.")

	# Hide main menu buttons (autoload) while in multiplayer lobby
	_set_main_menu_buttons_visible(false)

	_update_status("Ready to connect")
	_refresh_players_list()

# Initialize server/host functionality
func _on_host_button_pressed():
	_start_server()

# Initialize client connection
func _on_join_button_pressed():
	var host_ip = ip_input.text.strip_edges()
	if host_ip.is_empty():
		_update_status("Error: Please enter host IP address")
		return
	_connect_to_server(host_ip)

# Start the game (only available for host)
func _on_start_game_button_pressed():
	start_game()

# Server initialization - binds to port and starts listening
func _start_server():
	peer = ENetMultiplayerPeer.new()
	
	print("Starting server on port: ", DEFAULT_PORT)
	print("Max clients: ", MAX_CLIENTS)
	
	# Create server that binds to all interfaces (0.0.0.0) and listens on DEFAULT_PORT only
	# This prevents clients from hanging by connecting to the wrong port
	var error = peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	
	if error != OK:
		var error_msg = _get_error_message(error)
		_update_status("Failed to start server: " + error_msg)
		print("Server creation error code: ", error, " - ", error_msg)
		return
	
	# Set the multiplayer peer for this node tree
	multiplayer.multiplayer_peer = peer
	is_server = true
	# Store connection info in autoload
	if has_node("/root/MultiplayerAutoload"):
		get_node("/root/MultiplayerAutoload").set_connection_info(true, "", DEFAULT_PORT)
	
	# Update UI for host mode
	_set_host_ui()
	
	# Get local IP for display
	var _local_ip = _get_local_ip()
	var all_ips = _get_all_local_ips()
	
	print("Server started successfully!")
	print("Available IP addresses:")
	for ip in all_ips:
		print("  - ", ip)
	
	# Show the main IP for clients to connect to
	var main_ip = _get_best_local_ip()
	print("CLIENTS SHOULD CONNECT TO: ", main_ip)
	
	_update_status("Server: " + main_ip + ":" + str(DEFAULT_PORT) + " (Share this IP with other players)")
	
	# Lobby mode: do NOT spawn players yet; wait for Start Game
	game_started = false
	_refresh_players_list()
	_broadcast_lobby_peers()

# Client connection - connects to specified host IP
func _connect_to_server(host_ip: String):
	peer = ENetMultiplayerPeer.new()
	
	# Clean and validate the IP address
	var clean_ip = host_ip.strip_edges()
	
	# Remove port if accidentally included in IP
	if ":" in clean_ip:
		clean_ip = clean_ip.split(":")[0]
	
	# Validate IP format
	if not _is_valid_ip(clean_ip):
		_update_status("Error: Invalid IP address format. Use format: 192.168.1.100")
		print("Invalid IP provided: '", clean_ip, "'")
		return
	
	print("Attempting to connect to: ", clean_ip, ":", DEFAULT_PORT)
	
	# Create client connection to host
	var error = peer.create_client(clean_ip, DEFAULT_PORT)
	
	if error != OK:
		var error_msg = _get_error_message(error)
		_update_status("Failed to connect: " + error_msg)
		print("Connection error code: ", error, " - ", error_msg)
		return
	
	# Set the multiplayer peer for this node tree
	multiplayer.multiplayer_peer = peer
	is_server = false
	
	# Store connection info in autoload
	if has_node("/root/MultiplayerAutoload"):
		get_node("/root/MultiplayerAutoload").set_connection_info(false, clean_ip, DEFAULT_PORT)
	
	# Disable UI controls during connection
	_set_ui_enabled(false)
	
	_update_status("Connecting to " + clean_ip + ":" + str(DEFAULT_PORT) + "...")

## Multiplayer signal handlers

# Signal handler: Called when a peer successfully connects
func _on_peer_connected(peer_id: int):
	print("Peer connected: ", peer_id)
	connected_peers.append(peer_id)
	
	if is_server:
		_update_status("Client " + str(peer_id) + " connected. Total peers: " + str(connected_peers.size() + 1))
		
		# Lobby update
		lobby_peers = connected_peers.duplicate()
		_refresh_players_list()
		_broadcast_lobby_peers()
		
		if game_started:
			# Late-joiner: only notify to transition; spawning will occur in world.gd
			print("Late join detected for peer ", peer_id, " — sending game started via NetHub (no lobby spawn)")
			var hub := get_node_or_null("/root/NetHub")
			if hub:
				hub.rpc_id(peer_id, "relay_game_started")
			else:
				rpc_id(peer_id, "_on_game_started")
			return
	else:
		# Check if multiplayer is still valid before accessing it
		if multiplayer.has_multiplayer_peer():
			_update_status("Connected to server as peer " + str(multiplayer.get_unique_id()))
		else:
			_update_status("Connected to server")
		# Update UI for client mode
		_set_client_ui()
		# Client will request spawn only after game starts
		# Debug: List players on client side after a short delay
		await get_tree().create_timer(1.0).timeout
		if game_started:
			_debug_list_players()

# Called on the client when it has successfully connected to the server
func _on_connected_to_server():
	print("Connected to server successfully. Local peer: ", multiplayer.get_unique_id())
	_set_client_ui()
	_update_status("Connected to server")
	# Ask the server what the current game state is (lobby or already started)
	if multiplayer.has_multiplayer_peer():
		# Prefer NetHub to avoid path issues during scene changes
		var hub := get_node_or_null("/root/NetHub")
		if hub:
			hub.rpc_id(1, "request_game_status")
		else:
			# Fallback to local handler
			rpc_id(1, "_request_game_status")

# Client -> Server: ask for current game status and players
@rpc("any_peer", "call_remote", "reliable")
func _request_game_status():
	var sender := multiplayer.get_remote_sender_id()
	if is_server:
		print("Client ", sender, " requested game status. Started:", game_started)
		# Send minimal data; clients will synchronize in world
		rpc_id(sender, "_apply_game_status", game_started, [])

# Server -> Client: apply game status locally
@rpc("any_peer", "call_local", "reliable")
func _apply_game_status(started: bool, players: Array):
	print("Applying game status. started=", started, ", players=", players.size())
	if started:
		# Ensure we hide lobby and transition
		_hide_lobby_ui()
		game_started = true
		# Transition this client to world
		await get_tree().process_frame
		_transition_to_world()
		# Do not perform any further lobby sync after transitioning
		return
	else:
		# Still in lobby; update list and wait for host to start
		lobby_peers = connected_peers.duplicate()
		_refresh_players_list()

# Signal handler: Called when a peer disconnects
func _on_peer_disconnected(peer_id: int):
	print("Peer disconnected: ", peer_id)
	connected_peers.erase(peer_id)
	
	# Remove the player node for this peer
	var player_node: Node = null
	if is_instance_valid(multiplayer_spawner):
		player_node = multiplayer_spawner.get_node_or_null("Player_" + str(peer_id))
		if player_node == null:
			player_node = get_node_or_null("MultiplayerSpawner/Player_" + str(peer_id))
	else:
		player_node = get_node_or_null("Player_" + str(peer_id))
	if player_node:
		player_node.call_deferred("queue_free")
	
	if is_server:
		_update_status("Client " + str(peer_id) + " disconnected. Total peers: " + str(connected_peers.size() + 1))
		# Update lobby list on disconnect
		lobby_peers = connected_peers.duplicate()
		_refresh_players_list()
		_broadcast_lobby_peers()
	else:
		_update_status("Peer " + str(peer_id) + " disconnected")

# Signal handler: Called when connection to server fails
func _on_connection_failed():
	print("Connection failed")
	_update_status("Connection failed! Check IP address and network.")
	# Don't reset network immediately - might be temporary during scene transition

# Signal handler: Called when server disconnects (client-side)
func _on_server_disconnected():
	print("Server disconnected")
	# Check if we're in the middle of a scene transition
	if game_started:
		print("Server disconnected during game - this might be normal during scene transition")
		# Wait a moment to see if connection is restored
		await get_tree().create_timer(2.0).timeout
		if not multiplayer.has_multiplayer_peer():
			_update_status("Server disconnected!")
			_reset_network()
	else:
		_update_status("Server disconnected!")
		_reset_network()

# Spawn a networked player for the given peer ID
func _spawn_player(peer_id: int):
	if not player_scene:
		print("Error: No player scene assigned!")
		return

	# Only the server should spawn players
	if not is_server:
		return

	# Check if player already exists
	var existing_player = null
	if is_instance_valid(multiplayer_spawner):
		existing_player = multiplayer_spawner.get_node_or_null("Player_" + str(peer_id))
	else:
		existing_player = get_node_or_null("Player_" + str(peer_id))
	
	if existing_player:
		print("Player for peer ", peer_id, " already exists")
		return

	print("Spawning player for peer: ", peer_id)
	
	# Use proper MultiplayerSpawner instantiation (Godot 4 method)
	if is_instance_valid(multiplayer_spawner):
		print("Using MultiplayerSpawner for peer: ", peer_id)
		
		# Position players at small, stable offsets so they are near each other
		var spawn_position = _compute_spawn_position(peer_id)
		
		# Create player instance manually and add to MultiplayerSpawner
		# The MultiplayerSpawner will automatically handle replication
		var player_instance = player_scene.instantiate()
		print("[Spawn] player_scene path: ", player_scene.resource_path)
		if player_instance.has_method("get_scene_file_path"):
			print("[Spawn] instance scene_file_path: ", player_instance.get_scene_file_path())
		player_instance.name = "Player_" + str(peer_id)
		player_instance.global_position = spawn_position
		
		# CRITICAL: Set authority BEFORE adding to tree
		player_instance.set_multiplayer_authority(peer_id)
		# Also set the MultiplayerSynchronizer's authority before entering the tree
		var sync: MultiplayerSynchronizer = player_instance.get_node_or_null("MultiplayerSynchronizer")
		if sync:
			sync.set_multiplayer_authority(peer_id)
			print("[Spawn] Set sync authority to ", peer_id)
		
		# Add to MultiplayerSpawner - this triggers automatic replication
		multiplayer_spawner.spawn(player_instance)
		
		# Ensure visibility and proper setup
		player_instance.visible = true
		
		print("Successfully spawned player for peer: ", peer_id, " at position: ", spawn_position)
		print("Player added to MultiplayerSpawner, authority: ", player_instance.get_multiplayer_authority())
		print("MultiplayerSpawner children count: ", multiplayer_spawner.get_child_count())
		
		# No lobby RPCs for spawn. Replication is handled by MultiplayerSpawner.
		
		# Wait a frame for proper synchronization (let MultiplayerSpawner replicate it)
		await get_tree().process_frame
	else:
		print("MultiplayerSpawner not available, using manual spawn")
		_spawn_player_manual(peer_id)

# Fallback manual spawning method
func _spawn_player_manual(peer_id: int):
	var player_instance: Node = null
	
	# Create player instance manually
	player_instance = player_scene.instantiate()
	player_instance.name = "Player_" + str(peer_id)
	
	# Set authority before adding to tree
	player_instance.set_multiplayer_authority(peer_id)
	
	# Add to this node directly
	add_child(player_instance, true)

	# Position players at small, stable offsets so they are near each other
	player_instance.global_position = _compute_spawn_position(peer_id)
	player_instance.visible = true

	print("Manually spawned player for peer: ", peer_id, " at position: ", player_instance.global_position)
	
	# No RPC needed; MultiplayerSpawner replicates to all peers

# Ensure the host player exists (called when new clients connect)
func _ensure_host_player_exists():
	if not is_server:
		return
	
	# Check if host player already exists
	var host_player = null
	if is_instance_valid(multiplayer_spawner):
		host_player = multiplayer_spawner.get_node_or_null("Player_1")
	else:
		host_player = get_node_or_null("Player_1")
	
	# If host player doesn't exist, spawn it
	if not host_player:
		print("Host player missing, spawning...")
		_spawn_player(1)

# Compute a stable spawn position for a given peer
func _compute_spawn_position(peer_id: int) -> Vector2:
	# Prefer host player's current position so everyone spawns together visibly
	var host = multiplayer_spawner.get_node_or_null("Player_1") if is_instance_valid(multiplayer_spawner) else get_node_or_null("Player_1")
	var base: Vector2 = host.global_position if host is Node2D else _get_spawn_base()
	var index: int = int(_spawn_indices.get(peer_id, -1))
	if index == -1:
		index = _spawn_indices.size()
		_spawn_indices[peer_id] = index
	# Spawn everyone in the exact same spot in the lobby (no offset)
	return base

# Get spawn base position from a marker or default
func _get_spawn_base() -> Vector2:
	var marker := get_node_or_null("SpawnPoint")
	if marker and marker is Node2D:
		return marker.global_position
	# Try to use the current 2D camera center if available
	var vp := get_viewport()
	if vp and vp.has_method("get_camera_2d"):
		var cam := vp.get_camera_2d()
		if cam:
			if cam.has_method("get_screen_center_position"):
				return cam.get_screen_center_position()
			return cam.global_position
	# Fallback to a reasonable center
	return Vector2(400, 300)

# RPC handler: Client requests player spawn
@rpc("any_peer", "call_remote", "reliable")
func _request_player_spawn():
	if game_started:
		return
	var sender_id = multiplayer.get_remote_sender_id()
	print("Client ", sender_id, " requested player spawn")
	
	if is_server:
		# Spawn player for the requesting client
		_spawn_player(sender_id)

# RPC handler: Sync player spawn across all clients
@rpc("any_peer", "call_local", "reliable")
func _sync_player_spawn(peer_id: int, spawn_position: Vector2, visible_flag: bool):
	if game_started:
		return
	print("Syncing player spawn: peer ", peer_id, " at ", spawn_position, " visible: ", visible_flag)

	# Check if we already have this player locally
	var player_node = null
	if is_instance_valid(multiplayer_spawner):
		player_node = multiplayer_spawner.get_node_or_null("Player_" + str(peer_id))
	else:
		player_node = get_node_or_null("Player_" + str(peer_id))
	
	if player_node:
		print("Player found locally: ", player_node.name, " visible: ", player_node.visible, " position: ", player_node.global_position)
		# Ensure the player is visible and positioned correctly
		player_node.visible = true
		player_node.global_position = spawn_position
	else:
		print("Player NOT found locally for peer: ", peer_id)
		# If we're not the server and don't have this player, spawn a local mirror as fallback
		if not is_server:
			print("[Fallback] Client will instantiate missing player locally")
			if not player_scene:
				# Try to load networked player scene
				if ResourceLoader.exists("res://scenes/networked_player.tscn"):
					player_scene = load("res://scenes/networked_player.tscn")
				else:
					player_scene = load("res://scenes/player.tscn")
			var inst = player_scene.instantiate()
			inst.name = "Player_" + str(peer_id)
			inst.global_position = spawn_position
			inst.set_multiplayer_authority(peer_id)
			var sync: MultiplayerSynchronizer = inst.get_node_or_null("MultiplayerSynchronizer")
			if sync:
				sync.set_multiplayer_authority(peer_id)
			if is_instance_valid(multiplayer_spawner):
				multiplayer_spawner.spawn(inst)
			else:
				add_child(inst, true)
			inst.visible = true
			print("[Fallback] Client spawned mirror for peer ", peer_id)
	
	# Debug: List all current players
	_debug_list_players()

# RPC handler: Notify all clients when a player is spawned (legacy)
@rpc("any_peer", "call_local", "reliable")
func _on_player_spawned(peer_id: int, spawn_position: Vector2):
	if game_started:
		return
	print("Legacy player spawned notification: peer ", peer_id, " at ", spawn_position)
	_sync_player_spawn(peer_id, spawn_position, true)

# Debug function to list all current players
func _debug_list_players():
	print("=== CURRENT PLAYERS DEBUG ===")
	print("Is server: ", is_server)
	print("Connected peers: ", connected_peers)
	
	var player_count = 0
	if is_instance_valid(multiplayer_spawner):
		print("Checking MultiplayerSpawner children:")
		for child in multiplayer_spawner.get_children():
			if child.name.begins_with("Player_"):
				print("  - ", child.name, " visible: ", child.visible, " position: ", child.global_position)
				player_count += 1
	else:
		print("Checking direct children:")
		for child in get_children():
			if child.name.begins_with("Player_"):
				print("  - ", child.name, " visible: ", child.visible, " position: ", child.global_position)
				player_count += 1
	
	print("Total players found: ", player_count)
	print("=== END DEBUG ===")

# Get data for all existing players
func _get_all_player_data() -> Array:
	var player_data = []
	
	# Add host player data
	var host_player = null
	if is_instance_valid(multiplayer_spawner):
		host_player = multiplayer_spawner.get_node_or_null("Player_1")
	else:
		host_player = get_node_or_null("Player_1")
	
	if host_player:
		player_data.append({
			"peer_id": 1,
			"position": host_player.global_position,
			"visible": host_player.visible
		})
	
	# Add client players data
	for peer_id in connected_peers:
		var player_node = null
		if is_instance_valid(multiplayer_spawner):
			player_node = multiplayer_spawner.get_node_or_null("Player_" + str(peer_id))
		else:
			player_node = get_node_or_null("Player_" + str(peer_id))
		
		if player_node:
			player_data.append({
				"peer_id": peer_id,
				"position": player_node.global_position,
				"visible": player_node.visible
			})
	
	return player_data

# RPC handler: Sync existing players to a new client
@rpc("any_peer", "call_remote", "reliable")
func _sync_existing_players(player_data: Array):
	if game_started:
		return
	print("Syncing existing players: ", player_data.size(), " players")
	# Ignore if we already started the game and likely transitioned away from the lobby
	if game_started:
		return
	
	for data in player_data:
		var peer_id = data.peer_id
		var player_pos: Vector2 = data.position
		var visible_flag: bool = data.visible
		
		print("Syncing player ", peer_id, " at ", player_pos, " visible: ", visible_flag)
		
		# Check if we already have this player
		var existing_player = null
		if is_instance_valid(multiplayer_spawner):
			existing_player = multiplayer_spawner.get_node_or_null("Player_" + str(peer_id))
		else:
			existing_player = get_node_or_null("Player_" + str(peer_id))
		
		if not existing_player:
			print("Player ", peer_id, " not found locally, this should be handled by MultiplayerSpawner")

# Start the actual game and spawn all connected players
func start_game():
	if not is_server:
		print("Only the server can start the game!")
		return
	
	if not multiplayer.has_multiplayer_peer():
		print("No multiplayer peer available!")
		return
	
	print("Starting game with ", connected_peers.size() + 1, " players")
	print("Connected peers: ", connected_peers)
	
	# Hide the lobby UI
	_hide_lobby_ui()
	
	game_started = true

	# Notify all clients that the game has started and transition via NetHub
	var hub := get_node_or_null("/root/NetHub")
	if hub:
		hub.rpc("relay_game_started")
	else:
		# Fallback to scene-local RPC
		rpc("_on_game_started")
	
	# Small delay to ensure RPC is sent before server transitions
	await get_tree().process_frame
	
	# Server also transitions to world scene
	_transition_to_world()
	
	_update_status("Game started!")

# Post-configure any node spawned by MultiplayerSpawner (runs on all peers)
func _on_spawner_spawned(node: Node):
	if node == null:
		return
		
	var peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	print("Spawner spawned node: ", node.name, " on peer: ", peer_id)
	
	# If this is a player instance, ensure proper setup on all peers
	if node.name.begins_with("Player_"):
		# Do NOT change authority here. Only the server sets authority before add_child.
		# Ensure visibility for safety and print debug info.
		node.visible = true
		# Ensure the local camera is active immediately for the local player's node
		if multiplayer.has_multiplayer_peer():
			var local_id := multiplayer.get_unique_id()
			if node.name == ("Player_" + str(local_id)):
				var wcam := node.get_node_or_null("world_camera")
				var dcam := node.get_node_or_null("doorside_camera")
				if wcam:
					wcam.enabled = true
					if wcam.has_method("make_current"):
						wcam.make_current()
				if dcam:
					dcam.enabled = false
		print("Player ", node.name, " spawned:")
		print("  - Authority: ", node.get_multiplayer_authority())
		print("  - Position: ", node.global_position)
		print("  - Visible: ", node.visible)
		var parent_name: String = "No parent"
		if node.get_parent():
			parent_name = str(node.get_parent().name)
		print("  - Parent: ", parent_name)

# Reset network state and re-enable UI
func _reset_network():
	if peer:
		peer.close()
		peer = null
	
	multiplayer.multiplayer_peer = null
	is_server = false
	connected_peers.clear()
	
	# Remove all networked players (under the spawner if present)
	if is_instance_valid(multiplayer_spawner):
		for child in multiplayer_spawner.get_children():
			if child.name.begins_with("Player_"):
				child.call_deferred("queue_free")
	else:
		for child in get_children():
			if child.name.begins_with("Player_"):
				child.call_deferred("queue_free")
	
	_set_ui_enabled(true)
	_reset_ui_to_lobby()

# Update status label with current connection state
func _update_status(message: String):
	if status_label:
		status_label.text = message
	print("Status: ", message)

# Enable/disable UI controls
func _set_ui_enabled(enabled: bool):
	if host_button:
		host_button.disabled = not enabled
	if join_button:
		join_button.disabled = not enabled
	if ip_input:
		ip_input.editable = enabled
	if start_game_button:
		start_game_button.disabled = not enabled

# Set UI for host mode (show start game button, hide connection buttons)
func _set_host_ui():
	if host_button:
		host_button.visible = false
	if join_button:
		join_button.visible = false
	if ip_input:
		ip_input.visible = false
	if start_game_button:
		start_game_button.visible = true
		start_game_button.disabled = false
	if players_title:
		players_title.visible = true
	if players_list:
		players_list.visible = true
	if main_container:
		main_container.visible = true

# Set UI for client mode (hide all lobby buttons)
func _set_client_ui():
	if host_button:
		host_button.visible = false
	if join_button:
		join_button.visible = false
	if ip_input:
		ip_input.visible = false
	if start_game_button:
		start_game_button.visible = false
	if players_title:
		players_title.visible = false
	if players_list:
		players_list.visible = false
	if status_label:
		status_label.visible = false
	if main_container:
		main_container.visible = false

# Reset UI back to lobby state
func _reset_ui_to_lobby():
	if host_button:
		host_button.visible = true
	if join_button:
		join_button.visible = true
	if ip_input:
		ip_input.visible = true
	if start_game_button:
		start_game_button.visible = false
	if status_label:
		status_label.visible = true
	if players_title:
		players_title.visible = true
	if players_list:
		players_list.visible = true

# Hide the entire lobby UI when game starts
func _hide_lobby_ui():
	if host_button:
		host_button.visible = false
	if join_button:
		join_button.visible = false
	if ip_input:
		ip_input.visible = false
	if start_game_button:
		start_game_button.visible = false
	if status_label:
		status_label.visible = false
	if players_title:
		players_title.visible = false
	if players_list:
		players_list.visible = false

# RPC handler for when game starts (called on all clients)
@rpc("any_peer", "call_local", "reliable")
func _on_game_started():
	if game_started:
		return
	var peer_id_str = str(multiplayer.get_unique_id()) if multiplayer.has_multiplayer_peer() else "unknown"
	print("Game started notification received on peer: ", peer_id_str)
	_hide_lobby_ui()
	game_started = true
	
	# Small delay to ensure proper synchronization
	await get_tree().process_frame
	
	# All peers transition to world scene
	print("Client transitioning to world scene...")
	_transition_to_world()

# Transition to the world scene with multiplayer support
func _transition_to_world():
	# Prevent multiple simultaneous transitions
	if _transitioning_to_world:
		print("Already transitioning to world scene, skipping...")
		return
	
	_transitioning_to_world = true
	print("Transitioning to world scene...")
	print("Current multiplayer peer: ", multiplayer.multiplayer_peer)
	print("Is server: ", is_server)
	print("Connected peers: ", connected_peers)
	
	# Verify multiplayer connection is still valid
	if not multiplayer.has_multiplayer_peer():
		print("Error: No multiplayer peer during transition!")
		_transitioning_to_world = false
		return
	
	# Preserve multiplayer state before scene change
	if has_node("/root/MultiplayerAutoload"):
		var success = get_node("/root/MultiplayerAutoload").preserve_multiplayer_state()
		print("Multiplayer state preserved: ", success)
	
	# Change to world scene while preserving multiplayer connection
	var scene_path = "res://scenes/world.tscn"
	if ResourceLoader.exists(scene_path):
		print("Changing to world scene: ", scene_path)
		# Add a small delay to ensure RPC synchronization
		await get_tree().create_timer(0.1).timeout
		# Use call_deferred to avoid issues during RPC processing
		get_tree().call_deferred("change_scene_to_file", scene_path)
	else:
		print("Error: World scene not found at ", scene_path)
		_transitioning_to_world = false

# Get local IP address for server display
func _get_local_ip() -> String:
	# Try to get the actual local IP
	var addresses = IP.get_local_addresses()
	for address in addresses:
		# Return first non-loopback IPv4 address
		if address != "127.0.0.1" and not address.contains(":") and _is_valid_ip(address):
			return address
	return "127.0.0.1"

# Get all local IP addresses for debugging
func _get_all_local_ips() -> Array[String]:
	var addresses = IP.get_local_addresses()
	var ipv4_addresses: Array[String] = []
	for address in addresses:
		if not address.contains(":") and _is_basic_ipv4(address):  # IPv4 only
			ipv4_addresses.append(address)
	return ipv4_addresses

# Get the best local IP for clients to connect to
func _get_best_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	var best_ip = "127.0.0.1"
	
	# Priority order: 192.168.x.x > 10.x.x.x > 172.16-31.x.x > others
	for address in addresses:
		if not address.contains(":") and _is_basic_ipv4(address) and address != "127.0.0.1":
			# Prefer 192.168.x.x (most common home networks)
			if address.begins_with("192.168."):
				return address
			# Then 10.x.x.x (corporate networks)
			elif address.begins_with("10.") and best_ip == "127.0.0.1":
				best_ip = address
			# Then 172.16-31.x.x (less common private networks)
			elif address.begins_with("172.") and best_ip == "127.0.0.1":
				var parts = address.split(".")
				if parts.size() >= 2:
					var second_octet = int(parts[1])
					if second_octet >= 16 and second_octet <= 31:
						best_ip = address
			# Any other valid IP as fallback
			elif best_ip == "127.0.0.1":
				best_ip = address
	
	return best_ip

# Basic IPv4 check (less verbose for internal use)
func _is_basic_ipv4(ip: String) -> bool:
	if ip.is_empty() or ip.contains(":"):
		return false
	var parts = ip.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
		var num = int(part)
		if num < 0 or num > 255:
			return false
	return true

# Validate IP address format
func _is_valid_ip(ip: String) -> bool:
	if ip.is_empty():
		print("IP validation failed: empty string")
		return false
	
	# Remove any whitespace
	ip = ip.strip_edges()
	
	# Check for common mistakes
	if ip.contains(":"):
		print("IP validation failed: contains colon (port should not be included)")
		return false
	
	var parts = ip.split(".")
	if parts.size() != 4:
		print("IP validation failed: expected 4 parts, got ", parts.size(), " parts: ", parts)
		return false
	
	for i in range(parts.size()):
		var part = parts[i].strip_edges()
		if part.is_empty():
			print("IP validation failed: empty part at position ", i)
			return false
		if not part.is_valid_int():
			print("IP validation failed: part '", part, "' at position ", i, " is not a valid integer")
			return false
		var num = int(part)
		if num < 0 or num > 255:
			print("IP validation failed: part ", num, " at position ", i, " is out of range (0-255)")
			return false
	
	print("IP validation passed: ", ip)
	return true

# Get human-readable error message
func _get_error_message(error_code: int) -> String:
	match error_code:
		ERR_ALREADY_IN_USE:
			return "Port already in use"
		ERR_CANT_CREATE:
			return "Cannot create server/client"
		ERR_INVALID_PARAMETER:
			return "Invalid parameter"
		ERR_UNAUTHORIZED:
			return "Unauthorized"
		ERR_CONNECTION_ERROR:
			return "Connection error"
		_:
			return "Unknown error (" + str(error_code) + ")"

# Handle cleanup when node is removed
func _exit_tree():
	# Restore main menu buttons when leaving lobby
	_set_main_menu_buttons_visible(true)
	_reset_network()

# Utility: robust UI node finder under the UI CanvasLayer
func _find_ui_control(ui_layer: Node, target_name: String) -> Node:
	if ui_layer == null:
		return null
	# First, try as a direct child (UI/Name)
	if ui_layer.has_node(target_name):
		return ui_layer.get_node(target_name)
	# Then, search recursively by name
	return ui_layer.find_child(target_name, true, false)

# Show/hide the main menu buttons from the MainMenu autoload while in the lobby
func _set_main_menu_buttons_visible(show_buttons: bool) -> void:
	var main_menu := get_node_or_null("/root/MainMenu")
	if main_menu == null:
		return
	var buttons := main_menu.get_node_or_null("MainButtons")
	if buttons:
		buttons.visible = show_buttons
	var settings := main_menu.get_node_or_null("Settings")
	if settings and show_buttons == false:
		settings.visible = false

# Lobby: Update the players list UI
func _refresh_players_list():
	if not players_list:
		return
	players_list.clear()
	if players_title:
		players_title.text = "Players in Lobby"
	# Show consistent player labels on both host and client
	var local_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 0
	var host_label = "Player 1"
	if local_id == 1:
		host_label += "  — You"
	players_list.add_item(host_label)
	# Add connected clients
	for pid in connected_peers:
		var label = "Player 2"  # Assuming single client for now
		if pid == local_id and local_id != 1:
			label += "  — You"
		players_list.add_item(label)

# Lobby: broadcast list to clients
func _broadcast_lobby_peers():
	if game_started:
		return
	if not is_server:
		return
	if game_started:
		return
	var peers_to_send: Array[int] = connected_peers.duplicate()
	rpc("_update_lobby_list", peers_to_send, 1)

@rpc("any_peer", "call_local", "reliable")
func _update_lobby_list(peers: Array[int], _host_id: int):
	if game_started:
		return
	connected_peers = peers.duplicate()
	_refresh_players_list()
