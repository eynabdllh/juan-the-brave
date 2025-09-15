extends Node2D

@export var key_scene: PackedScene

var total_enemies = 0
var enemies_defeated = 0

func _ready():
	var enemies = get_tree().get_nodes_in_group("enemies")
	total_enemies = enemies.size()
	
	if total_enemies == 0:
		print("No enemies in this level.")
		return
		
	for enemy in enemies:
		enemy.died.connect(_on_enemy_defeated)
		
	print("Level started with ", total_enemies, " enemies.")
	
	if global.game_first_loadin:
		$player.position = global.player_start_pos
		global.game_first_loadin = false
	else:
		$player.position = global.player_exit_doorside_pos

func _on_enemy_defeated(enemy_position: Vector2):
	enemies_defeated += 1
	print("Enemy defeated! ", enemies_defeated, "/", total_enemies)
	
	if enemies_defeated >= total_enemies:
		print("All enemies defeated! Spawning key.")
		spawn_key(enemy_position)

func spawn_key(position: Vector2):
	var key_instance = key_scene.instantiate()
	key_instance.position = position
	add_child(key_instance)
	
	# This line is where the connection happens.
	key_instance.collected.connect(on_key_collected)

func on_key_collected():
	print("Key has been collected by the player!")
	global.player_has_key = true
	# You can play a success sound here, like a triumphant fanfare.

func _on_door_side_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Player has touched the door area. Transitioning to door_side scene.")
		global.go_to_door_side()
