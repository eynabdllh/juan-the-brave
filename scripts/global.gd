extends Node

const KEY_TEXTURE = preload("res://assets/objects/key.png") 

# Signals so any HUD (for all players) can react
signal key_changed(has_key: bool)
signal enemies_progress_changed(defeated: int, total: int)
signal player_health_changed(health: int)

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

# --- Player buff state (used by chest rewards and player.gd) ---
var player_speed_mult: float = 1.0
var player_damage_bonus: int = 0
var player_invincible: bool = false

func reset_buffs():
	player_speed_mult = 1.0
	player_damage_bonus = 0
	player_invincible = false

# --- Persistent world state ---
# Tracks which chests have been opened across scene loads
var chest_opened: Dictionary = {}
# Tracks enemy positions across scene loads (only for enemies still alive)
var enemy_positions: Dictionary = {}

func set_chest_opened(id: String) -> void:
	chest_opened[id] = true

func is_chest_opened(id: String) -> bool:
	return chest_opened.get(id, false)

func set_enemy_position(enemy_name: String, pos: Vector2) -> void:
	enemy_positions[enemy_name] = pos

func get_enemy_position(enemy_name: String) -> Variant:
	return enemy_positions.get(enemy_name, null)

func clear_enemy_position(enemy_name: String) -> void:
	if enemy_positions.has(enemy_name):
		enemy_positions.erase(enemy_name)

# --- NEW: Transition to map_2 ---
func go_to_map_2():
	current_scene = "map_2"
	get_tree().change_scene_to_file("res://scenes/map_2.tscn")
	
func collect_key():
	player_has_key = true
	emit_signal("key_changed", true)
	print("Key collected!")

func set_enemies_progress(defeated: int, total: int) -> void:
	emit_signal("enemies_progress_changed", defeated, total)

func set_player_health(value: int) -> void:
	emit_signal("player_health_changed", value)
