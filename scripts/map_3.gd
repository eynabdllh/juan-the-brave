extends Node2D

@export var key_scene: PackedScene

var total_enemies = 0
var enemies_defeated = 0
var _door_enter_cooldown: bool = true

func _ready():
	_ensure_status_hud()
	
	# Set the current scene for the camera system
	if has_node("/root/global"):
		global.current_scene = "map_3"

	# Position the player correctly based on the door they entered
	if global.next_player_position != Vector2.ZERO:
		$player.position = global.next_player_position
		global.next_player_position = Vector2.ZERO # Reset after use
	else:
		# Fallback for testing the scene directly
		$player.position = Vector2(29, 378)
		print("Warning: Player position not set by a door. Using default for map_3.")
		
	# Handle enemy state persistence (remove dead ones, position live ones)
	_update_enemy_states()

	# Respawn a dropped key if it was not collected before leaving
	if global.key_dropped and not global.player_has_key:
		spawn_key(global.key_position)
		
	# Set up door cooldown to prevent instant re-entry
	get_tree().create_timer(0.5).timeout.connect(func(): _door_enter_cooldown = false)


func _update_enemy_states():
	var all_enemies_in_scene = get_tree().get_nodes_in_group("enemies")
	total_enemies = all_enemies_in_scene.size()
	enemies_defeated = 0

	if total_enemies == 0:
		global.set_enemies_progress(0, 0)
		return

	for enemy in all_enemies_in_scene:
		# If the enemy's name is in the global killed list, remove it
		if global.killed_enemies.has(enemy.name):
			enemy.queue_free()
			enemies_defeated += 1
		else:
			# Otherwise, restore its position and connect its signal
			var saved_pos = global.get_enemy_position(enemy.name)
			if saved_pos != null:
				enemy.global_position = saved_pos
			
			if not enemy.died.is_connected(_on_enemy_defeated):
				enemy.died.connect(_on_enemy_defeated.bind(enemy.name))
	
	print("Map 3 loaded. Total enemies: ", total_enemies, " / Defeated: ", enemies_defeated)
	global.set_enemies_progress(enemies_defeated, total_enemies)

func _on_enemy_defeated(enemy_position: Vector2, enemy_name: String):
	enemies_defeated += 1
	global.clear_enemy_position(enemy_name)
	global.set_enemies_progress(enemies_defeated, total_enemies)
	if enemies_defeated >= total_enemies:
		print("All enemies defeated! Spawning key.")
		global.set_key_dropped(enemy_position)
		spawn_key(enemy_position)

func spawn_key(position: Vector2):
	if key_scene == null:
		key_scene = load("res://scenes/key.tscn")
	
	if key_scene:
		var key_instance := key_scene.instantiate()
		key_instance.global_position = position
		add_child(key_instance)
		key_instance.collected.connect(on_key_collected)

func on_key_collected():
	global.player_has_key = true
	global.clear_key_drop()
	if global.has_method("collect_key"):
		global.collect_key()

func _on_door_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if _door_enter_cooldown: return
		print("Player touching map_3 door. Transitioning to door_side_2.")
		save_enemy_positions()
		# Set the player's spawn point for the *next* scene (door_side_2)
		global.next_player_position = Vector2(243, 316)
		global.go_to_door_side_2()

func save_enemy_positions():
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			global.set_enemy_position(enemy.name, enemy.global_position)

func _ensure_status_hud():
	if get_tree().root.get_node_or_null("StatusHUD") == null:
		var hud_scene: PackedScene = load("res://scenes/status_hud.tscn")
		if hud_scene != null:
			var hud: Node = hud_scene.instantiate()
			hud.name = "StatusHUD"
			get_tree().root.add_child(hud)
