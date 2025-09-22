extends Node

const KEY_TEXTURE = preload("res://assets/objects/key.png") 

var player_current_attack = false	
var current_scene = "world"

var player_exit_doorside_pos = Vector2(209, 15)
var player_start_pos = Vector2(-9, 29) 

var game_first_loadin = true
var player_has_key = false

# --- NEW: This will store the names of enemies we have killed ---
var killed_enemies = []

# --- NEW: A function to add a killed enemy to our list ---
func add_killed_enemy(enemy_name):
	if not killed_enemies.has(enemy_name):
		killed_enemies.append(enemy_name)
	print("Killed enemies are now: ", killed_enemies)

# --- NEW: Persistent key drop state ---
# If a key has dropped (but not collected yet), we store its position so that
# it can be respawned when re-entering the scene.
var key_dropped: bool = false
var key_position: Vector2 = Vector2.ZERO

func set_key_dropped(pos: Vector2) -> void:
	key_dropped = true
	key_position = pos

func clear_key_drop() -> void:
	key_dropped = false
	key_position = Vector2.ZERO

func go_to_door_side():
	current_scene = "door_side"
	get_tree().change_scene_to_file("res://scenes/door_side.tscn")

func go_to_world():
	current_scene = "world"
	get_tree().change_scene_to_file("res://scenes/world.tscn")

# --- NEW: Transition to map_2 ---
func go_to_map_2():
	current_scene = "map_2"
	get_tree().change_scene_to_file("res://scenes/map_2.tscn")
	
func collect_key():
	player_has_key = true
	# --- MODIFIED: Tell the UI to add the key texture to slot 1 ---
	InventoryUI.add_item(1, KEY_TEXTURE)
	print("Key collected! Updating UI in slot 1.")
