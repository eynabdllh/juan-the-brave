extends Node2D

@export var key_scene: PackedScene

var total_enemies = 0
var enemies_defeated = 0

func _ready():
	var enemies = get_tree().get_nodes_in_group("enemies")
	total_enemies = enemies.size()
	
	if total_enemies == 0:
		print("No enemies in this level.")
		# Even if no enemies, respawn a previously dropped key if needed
		if global.key_dropped and not global.player_has_key:
			spawn_key(global.key_position)
		return
		
	for enemy in enemies:
		enemy.died.connect(_on_enemy_defeated)
		
	print("Level started with ", total_enemies, " enemies.")
	
	if global.game_first_loadin:
		$player.position = global.player_start_pos
		global.game_first_loadin = false
	else:
		$player.position = global.player_exit_doorside_pos

	# --- NEW: Respawn key if it was dropped previously and not collected ---
	if global.key_dropped and not global.player_has_key:
		print("Respawning dropped key at ", global.key_position)
		spawn_key(global.key_position)

func _on_enemy_defeated(enemy_position: Vector2):
	enemies_defeated += 1
	print("Enemy defeated! ", enemies_defeated, "/", total_enemies)
	
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
	# You can play a success sound here, like a triumphant fanfare.

func _on_door_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Player has touched the door area. Transitioning to door_side scene.")
		global.go_to_door_side()
