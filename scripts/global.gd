extends Node

const KEY_TEXTURE = preload("res://assets/objects/key.png") 

# Signals so any HUD (for all players) can react
signal key_changed(has_key: bool)
signal enemies_progress_changed(defeated: int, total: int)
signal player_health_changed(health: int)
signal buff_started(name: String, duration: float, info: String)
signal buff_ended(name: String)
signal heal_applied(amount: int)
signal buff_tick(name: String, remaining_seconds: int)

var player_current_attack = false	
var current_scene = "world"

var player_exit_doorside_pos = Vector2(209, 15)
var player_start_pos = Vector2(-9, 29) 

var game_first_loadin = true
var player_has_key = false

# Local multiplayer flag – when true, world spawns a second local player (arrow keys)
var local_coop: bool = false

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

# --- Authoritative buff timer state for real-time countdowns ---
var _buffs := {} # name -> { end_ms:int, info:String }
var _buff_timer: Timer

# --- Return positions per destination scene ---
var return_positions: Dictionary = {}

func _ready():
    # Lightweight ticker to update HUD countdowns. 4 Hz is fine for 1s display.
    _buff_timer = Timer.new()
    _buff_timer.one_shot = false
    _buff_timer.wait_time = 0.25
    add_child(_buff_timer)
    _buff_timer.timeout.connect(_on_buff_timer_timeout)
    _buff_timer.start()

func start_buff(name: String, duration: float, info: String) -> void:
    var now := Time.get_ticks_msec()
    var add_ms := int(duration * 1000.0)
    if _buffs.has(name):
        var end_ms: int = int(_buffs[name]["end_ms"])
        # Extend from current remaining end time (or now if already expired edge case)
        end_ms = max(end_ms, now) + add_ms
        _buffs[name]["end_ms"] = end_ms
        _buffs[name]["info"] = info
        # Fire a tick immediately so HUD updates the new remaining
        var remaining_sec := int(ceil(max(0, end_ms - now) / 1000.0))
        emit_signal("buff_tick", name, remaining_sec)
    else:
        var end_ms_new := now + add_ms
        _buffs[name] = {"end_ms": end_ms_new, "info": info}
        emit_signal("buff_started", name, duration, info)

func _on_buff_timer_timeout() -> void:
    if _buffs.is_empty():
        return
    var now: int = Time.get_ticks_msec()
    var to_remove: Array = []
    for name in _buffs.keys():
        var end_ms: int = int(_buffs[name]["end_ms"])
        var remaining_ms: int = int(max(0, end_ms - now))
        var remaining_sec: int = int(ceil(remaining_ms / 1000.0))
        emit_signal("buff_tick", name, remaining_sec)
        if remaining_ms <= 0:
            to_remove.append(name)
    for n in to_remove:
        _buffs.erase(n)
        emit_signal("buff_ended", n)

func is_buff_active(name: String) -> bool:
    if not _buffs.has(name):
        return false
    var now := Time.get_ticks_msec()
    var end_ms: int = int(_buffs[name]["end_ms"])
    return end_ms > now

func set_key_dropped(pos: Vector2) -> void:
    key_dropped = true
    key_position = pos

func clear_key_drop() -> void:
    key_dropped = false
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

# --- NEW: Transition helpers ---
func go_to_map_2():
    current_scene = "map_2"
    get_tree().change_scene_to_file("res://scenes/map_2.tscn")

func go_to_map_3():
    current_scene = "map_3"
    get_tree().change_scene_to_file("res://scenes/map_3.tscn")

func go_to_map_4():
    current_scene = "map_4"
    get_tree().change_scene_to_file("res://scenes/map_4.tscn")

func go_to_door_side_1():
    current_scene = "door_side_1"
    get_tree().change_scene_to_file("res://scenes/door_side_1.tscn")

func go_to_door_side_2():
    current_scene = "door_side_2"
    get_tree().change_scene_to_file("res://scenes/door_side_2.tscn")

func collect_key():
    player_has_key = true
    emit_signal("key_changed", true)
    print("Key collected!")

func set_enemies_progress(defeated: int, total: int) -> void:
    emit_signal("enemies_progress_changed", defeated, total)

func set_player_health(value: int) -> void:
    emit_signal("player_health_changed", value)
# --- Return position API ---
func set_return_position_for(scene_name: String, pos: Vector2) -> void:
    return_positions[scene_name] = pos

func get_return_position_for(scene_name: String) -> Variant:
    return return_positions.get(scene_name, null)

func clear_return_position_for(scene_name: String) -> void:
    if return_positions.has(scene_name):
        return_positions.erase(scene_name)
