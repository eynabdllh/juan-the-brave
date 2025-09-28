extends Node2D

@export var key_scene: PackedScene

var total_enemies = 0
var enemies_defeated = 0
var _door_enter_cooldown: bool = true

func _ready():
	_ensure_status_hud()
	
	# 1. Set the current scene for the camera system
	if has_node("/root/global"):
		global.current_scene = "map_2"

	# 2. Position the player correctly based on the door they entered
	if global.next_player_position != Vector2.ZERO:
		$player.position = global.next_player_position
		global.next_player_position = Vector2.ZERO # Reset after use
	else:
		# Fallback for testing the scene directly
		$player.position = Vector2(291, 18)
		print("Warning: Player position not set by a door. Using default for map_2.")
		
	# 3. Handle enemy state persistence
	_update_enemy_states()

	# 4. Check if the key needs to be re-spawned
	if global.key_dropped and not global.player_has_key:
		spawn_key(global.key_position)
		
	# 5. Set up door cooldown to prevent instant re-entry
	get_tree().create_timer(0.5).timeout.connect(func(): _door_enter_cooldown = false)

func _update_enemy_states():
	# Get all enemies placed in the editor for this scene
	var all_enemies_in_scene = get_tree().get_nodes_in_group("enemies")
	total_enemies = all_enemies_in_scene.size()
	enemies_defeated = 0 # Reset before recounting

	if total_enemies == 0:
		global.set_enemies_progress(0, 0)
		return

	for enemy in all_enemies_in_scene:
		# THE CRITICAL FIX IS HERE: Check if the enemy is already dead
		if global.killed_enemies.has(enemy.name):
			enemy.queue_free() # Remove it from the scene immediately
			enemies_defeated += 1 # Add to the defeated count for the HUD
		else:
			# This enemy is alive, so set it up
			var saved_pos = global.get_enemy_position(enemy.name)
			if saved_pos != null:
				enemy.global_position = saved_pos
			
			# Connect the 'died' signal only if not already connected
			if not enemy.died.is_connected(_on_enemy_defeated):
				enemy.died.connect(_on_enemy_defeated.bind(enemy.name))
	
	print("Map 2 loaded. Total enemies: ", total_enemies, " / Defeated: ", enemies_defeated)
	global.set_enemies_progress(enemies_defeated, total_enemies)

func _on_enemy_defeated(enemy_position: Vector2, enemy_name: String):
	enemies_defeated += 1
	# Note: global.add_killed_enemy is now handled inside the enemy's own die() function
	global.clear_enemy_position(enemy_name)
	global.set_enemies_progress(enemies_defeated, total_enemies)

	# Check if all enemies are now defeated
	if enemies_defeated >= total_enemies:
		print("All enemies defeated! Spawning key.")
		global.set_key_dropped(enemy_position) # Persist the key's drop location
		spawn_key(enemy_position)

# --- The rest of your script is fine and doesn't need changes ---

func spawn_key(position: Vector2):
	if key_scene == null:
		var default_key := load("res://scenes/key.tscn")
		if default_key: key_scene = default_key
	if key_scene:
		var key_instance := key_scene.instantiate()
		key_instance.global_position = position
		add_child(key_instance)
		key_instance.collected.connect(on_key_collected)

func on_key_collected():
	print("Key has been collected by the player!")
	global.player_has_key = true
	global.clear_key_drop()
	if global.has_method("collect_key"):
		global.collect_key()

func _ensure_status_hud():
	if get_tree().root.get_node_or_null("StatusHUD") == null:
		var hud_scene: PackedScene = load("res://scenes/status_hud.tscn")
		if hud_scene != null:
			var hud: Node = hud_scene.instantiate()
			hud.name = "StatusHUD"
			get_tree().root.add_child(hud)

func _on_door_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if _door_enter_cooldown: return
		print("Player has touched the door area. Transitioning to door_side_1 scene.")
		save_enemy_positions()
		global.go_to_door_side_1()

func save_enemy_positions():
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			global.set_enemy_position(enemy.name, enemy.global_position)
