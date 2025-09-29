extends Node

var PlayerScene = preload("res://scenes/player.tscn")
var Player2Scene = preload("res://scenes/player_2.tscn")

var players = {}

func _ready():
	# This node should be added to the world scene
	pass

@rpc("any_peer", "call_local")
func add_player(id):
	var player
	if id == 1:
		player = PlayerScene.instantiate()
		player.name = str(id)
		player.position = Vector2(100, 100) # Host position
		# Set WASD input actions for Player 1
		if player.has_method("set"):
			_ensure_input_actions()
			player.action_left = "p1_left"
			player.action_right = "p1_right"
			player.action_up = "p1_up"
			player.action_down = "p1_down"
	else:
		player = Player2Scene.instantiate()
		player.name = str(id)
		player.position = Vector2(200, 100) # Client position
		# Set different input actions for Player 2 (use WASD for P1, arrows for P2)
		if player.has_method("set"):
			# Ensure input actions exist
			_ensure_input_actions()
			player.action_left = "p2_left"
			player.action_right = "p2_right"
			player.action_up = "p2_up"
			player.action_down = "p2_down"

	# Authority will be set by player's _enter_tree() based on name
	# No need to set it here since _enter_tree() runs first

	# Enable local camera only for the player owned by this peer
	var is_local: bool = (id == multiplayer.get_unique_id())
	if player.has_method("set"):
		player.use_local_camera = is_local
	# Only the owning peer should process input
	if player.has_method("set_process_input"):
		player.set_process_input(is_local)
	
	# Debug: verify authority assignment (after _enter_tree sets it)
	call_deferred("_debug_authority", id, is_local, player)
	
	# Ensure input is disabled for non-local players
	player.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	if not is_local:
		player.set_physics_process(false)
		player.set_process(false)
	else:
		player.set_physics_process(true)
		player.set_process(true)

	# Register per-player systems
	var gs := get_node_or_null("/root/game_state")
	if gs:
		gs.register_player(id, 100, 100)
	var inv := get_node_or_null("/root/inventory")
	if inv:
		inv.register_player(id)

	# Add a synchronizer to replicate basic transforms/velocity
	var sync := MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	sync.root_path = "."
	var rc := SceneReplicationConfig.new()
	rc.add_property("position")
	rc.add_property("velocity")
	rc.add_property("global_position")
	sync.replication_config = rc
	player.add_child(sync)
	# Set synchronizer authority after player is added to tree
	call_deferred("_set_sync_authority", sync, id)
	# Add a simple name label above the head
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = ("Player 1" if id == 1 else "Player " + str(id))
	name_label.position = Vector2(-12, -16)
	name_label.z_index = 100
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	player.add_child(name_label)

	# Spawn a HUD for the local player
	if is_local:
		var hud_exists := get_tree().root.get_node_or_null("StatusHUD_Player_" + str(id)) != null
		if not hud_exists:
			if ResourceLoader.exists("res://scenes/status_hud.tscn"):
				var hud_scene: PackedScene = load("res://scenes/status_hud.tscn")
				if hud_scene:
					var hud = hud_scene.instantiate()
					hud.name = "StatusHUD_Player_" + str(id)
					# Set target player_id if the HUD script supports it
					if hud.has_method("set") or hud.has_variable("player_id"):
						hud.player_id = id
					get_tree().root.add_child(hud)
	players[id] = player
	add_child(player)

func _debug_authority(id: int, is_local: bool, player: Node):
	print("[PM] add_player id=", id, " local_uid=", multiplayer.get_unique_id(), 
		  " is_local=", is_local, " authority=", player.get_multiplayer_authority())

func _set_sync_authority(sync: MultiplayerSynchronizer, id: int):
	sync.set_multiplayer_authority(id)
	print("[PM] Set synchronizer authority for player ", id, " to ", sync.get_multiplayer_authority())

func _ensure_input_actions():
	# Create input actions for both players if they don't exist
	var actions = [
		# Player 1: WASD
		{"name": "p1_left", "key": KEY_A},
		{"name": "p1_right", "key": KEY_D},
		{"name": "p1_up", "key": KEY_W},
		{"name": "p1_down", "key": KEY_S},
		# Player 2: Arrow keys
		{"name": "p2_left", "key": KEY_LEFT},
		{"name": "p2_right", "key": KEY_RIGHT},
		{"name": "p2_up", "key": KEY_UP},
		{"name": "p2_down", "key": KEY_DOWN}
	]
	
	for action in actions:
		if not InputMap.has_action(action.name):
			InputMap.add_action(action.name)
			var event = InputEventKey.new()
			event.physical_keycode = action.key
			InputMap.action_add_event(action.name, event)
			print("[PM] Created input action: ", action.name, " -> ", action.key)

@rpc("any_peer", "call_local")
func remove_player(id):
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

@rpc("any_peer")
func request_full_sync(requester_id: int) -> void:
	# Only the server should serve sync requests
	if not multiplayer.is_server():
		return
	for pid in players.keys():
		# Tell just the requester to add each existing player
		rpc_id(requester_id, "add_player", pid)
