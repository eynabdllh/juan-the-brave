extends Node2D

@export var key_scene: PackedScene

var total_enemies = 0
var enemies_defeated = 0

func _ready():
	_ensure_status_hud()
	_ensure_local_coop_actions()
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	total_enemies = enemies.size()
	
	if total_enemies == 0:
		print("No enemies in this level.")
		# Even if no enemies, respawn a previously dropped key if needed
		if global.key_dropped and not global.player_has_key:
			spawn_key(global.key_position)
		return
		
	for enemy in enemies:
		# Restore persisted position if we have one
		var saved_pos = global.get_enemy_position(enemy.name)
		if saved_pos != null:
			enemy.global_position = saved_pos
		# Always connect the death signal and bind this enemy's name so we know who died.
		# Note: Bound args are appended AFTER emitted args in Godot 4, so handler signature is (enemy_position, enemy_name)
		enemy.died.connect(_on_enemy_defeated.bind(enemy.name))
		
	print("Level started with ", total_enemies, " enemies.")
	global.set_enemies_progress(enemies_defeated, total_enemies)
	
	if global.game_first_loadin:
		$player.position = global.player_start_pos
		global.game_first_loadin = false
	else:
		$player.position = global.player_exit_doorside_pos

	# --- Local Multiplayer: ensure two players if requested ---
	if has_node("/root/global") and get_node("/root/global").local_coop:
		_setup_local_coop()

	# --- NEW: Respawn key if it was dropped previously and not collected ---
	if global.key_dropped and not global.player_has_key:
		print("Respawning dropped key at ", global.key_position)
		spawn_key(global.key_position)
func _on_enemy_defeated(enemy_position: Vector2, enemy_name: String):
	enemies_defeated += 1
	print("Enemy defeated! ", enemies_defeated, "/", total_enemies)
	# Remove this enemy from persisted positions since it's dead now
	global.clear_enemy_position(enemy_name)
	global.set_enemies_progress(enemies_defeated, total_enemies)
	if enemies_defeated >= total_enemies:
		print("All enemies defeated! Spawning key.")
		# store the drop so it persists if the player leaves the scene
		global.set_key_dropped(enemy_position)
		spawn_key(enemy_position)


func spawn_key(position: Vector2):
	var key_instance = key_scene.instantiate()
	# Use global_position so the key appears exactly at the world-space location
	key_instance.global_position = position
	add_child(key_instance)
	
	# This line is where the connection happens.
	key_instance.collected.connect(on_key_collected)

func on_key_collected():
	print("Key has been collected by the player!")
	global.player_has_key = true
	global.clear_key_drop() # clear persisted drop since the key was picked up
	# Notify HUDs (for all players)
	if global.has_method("collect_key"): global.collect_key()
	# You can play a success sound here, like a triumphant fanfare.

func _on_door_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Player has touched the door area. Transitioning to door_side scene.")
		save_enemy_positions()
		global.go_to_door_side()

func save_enemy_positions():
	# Snapshot all current alive enemy positions
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			global.set_enemy_position(enemy.name, enemy.global_position)

func _ensure_status_hud() -> void:
	if get_tree().root.get_node_or_null("StatusHUD") == null:
		var hud_scene: PackedScene = load("res://scenes/status_hud.tscn")
		if hud_scene != null:
			var hud: Node = hud_scene.instantiate()
			hud.name = "StatusHUD"
			get_tree().root.add_child(hud)

# --- Local Multiplayer helpers ---
func _ensure_local_coop_actions() -> void:
	# Create distinct actions only once
	var add := func(action: String, keycode: int):
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)

	# P1: WASD
	add.call("p1_left", KEY_A)
	add.call("p1_right", KEY_D)
	add.call("p1_up", KEY_W)
	add.call("p1_down", KEY_S)

	# P2: Arrow keys
	add.call("p2_left", KEY_LEFT)
	add.call("p2_right", KEY_RIGHT)
	add.call("p2_up", KEY_UP)
	add.call("p2_down", KEY_DOWN)

func _setup_local_coop() -> void:
	# Configure existing player as P1 (WASD + with camera)
	if $player.has_method("set"):
		$player.action_left = "p1_left"
		$player.action_right = "p1_right"
		$player.action_up = "p1_up"
		$player.action_down = "p1_down"
		$player.use_local_camera = true

	# Spawn Player 2 (Arrow keys, no camera)
	var ps: PackedScene = load("res://scenes/player.tscn")
	if ps:
		var p2: Node = ps.instantiate()
		if p2:
			p2.name = "player2"
			if p2.has_method("set"):
				p2.action_left = "p2_left"
				p2.action_right = "p2_right"
				p2.action_up = "p2_up"
				p2.action_down = "p2_down"
				p2.use_local_camera = false
			p2.global_position = $player.global_position + Vector2(24, 0)
			add_child(p2)
