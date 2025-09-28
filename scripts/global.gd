extends Node

const KEY_TEXTURE = preload("res://assets/objects/key.png") 
const SAVE_PATH := "user://savegame.json"

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

var player_start_pos = Vector2(-9, 29) 
var next_player_position: Vector2 = Vector2.ZERO 

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

# Return handling for door_side_1 -> map_2 following the world/door_side pattern
var has_player_return_map2: bool = false
var player_return_map2_pos: Vector2 = Vector2(4, 1230)

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
func go_to_world():
    current_scene = "world"
    get_tree().change_scene_to_file("res://scenes/world.tscn")

func go_to_map_2():
    current_scene = "map_2"
    get_tree().change_scene_to_file("res://scenes/map_2.tscn")

func go_to_map_3():
    current_scene = "map_3"
    get_tree().change_scene_to_file("res://scenes/map_3.tscn")

func go_to_map_4():
    current_scene = "map_4"
    get_tree().change_scene_to_file("res://scenes/map_4.tscn")
    
func go_to_door_side():
    current_scene = "door_side"
    get_tree().change_scene_to_file("res://scenes/door_side.tscn")
    
func go_to_door_side_1():
    current_scene = "door_side_1"
    get_tree().change_scene_to_file("res://scenes/door_side_1.tscn")

func go_to_door_side_2():
    current_scene = "door_side_2"
    get_tree().change_scene_to_file("res://scenes/door_side_2.tscn")
    
func go_to_main_menu():
    # Reset all game state variables to their defaults
    player_has_key = false
    key_dropped = false
    killed_enemies.clear()
    chest_opened.clear()
    enemy_positions.clear()
    game_first_loadin = true
    next_player_position = Vector2.ZERO
    
    # Reset any active buffs
    _buffs.clear()
    player_speed_mult = 1.0
    player_damage_bonus = 0
    player_invincible = false

    # Remove gameplay-only overlays from root (e.g., StatusHUD) so they don't persist into main menu
    var root := get_tree().root
    var hud := root.get_node_or_null("StatusHUD")
    if hud:
        hud.queue_free()

    current_scene = "main_menu"
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# Reset all persistent gameplay state to defaults (fresh game)
func reset_game_state() -> void:
    player_has_key = false
    key_dropped = false
    key_position = Vector2.ZERO
    killed_enemies.clear()
    chest_opened.clear()
    enemy_positions.clear()
    next_player_position = player_start_pos
    game_first_loadin = true
    _buffs.clear()
    player_speed_mult = 1.0
    player_damage_bonus = 0
    player_invincible = false

# === Save/Load ===
func has_save() -> bool:
    var abs := ProjectSettings.globalize_path(SAVE_PATH)
    var exists := FileAccess.file_exists(SAVE_PATH)
    # Fallback: dir scan in case of path oddities
    if not exists:
        var dir_files := []
        var d := DirAccess.open("user://")
        if d:
            d.list_dir_begin()
            var name := d.get_next()
            while name != "":
                if not d.current_is_dir():
                    dir_files.append(name)
                name = d.get_next()
            d.list_dir_end()
        exists = "savegame.json" in dir_files
        print("[Global] has_save() FileAccess=", FileAccess.file_exists(SAVE_PATH), 
            " scanned=", exists, " abs=", abs, " files=", dir_files)
    else:
        print("[Global] has_save() found at ", abs)
    return exists

func _get_current_scene_path() -> String:
    var cs := get_tree().current_scene
    if cs:
        return cs.scene_file_path
    return "res://scenes/world.tscn"

func _get_player_position() -> Vector2:
    var cs := get_tree().current_scene
    if cs:
        var p := cs.get_node_or_null("player")
        if p and p.has_method("get"):
            return p.global_position
    return Vector2.ZERO

# --- Helpers: JSON -> Vector2 coercion ---
func _to_vec2(v: Variant) -> Vector2:
    if v is Vector2:
        return v
    if v is Vector2i:
        var vi: Vector2i = v
        return Vector2(vi.x, vi.y)
    if v is Array and (v as Array).size() >= 2:
        var a: Array = v
        return Vector2(float(a[0]), float(a[1]))
    if v is Dictionary and (v as Dictionary).has("x") and (v as Dictionary).has("y"):
        var dd: Dictionary = v
        return Vector2(float(dd["x"]), float(dd["y"]))
    if v is String:
        var s: String = v
        # Accept formats like "(x, y)" or "Vector2(x, y)" or "x,y"
        s = s.strip_edges()
        s = s.replace("Vector2", "")
        s = s.replace("(", "").replace(")", "")
        var parts := s.split(",", false)
        if parts.size() >= 2:
            return Vector2(float(parts[0]), float(parts[1]))
    return Vector2.ZERO

func _dict_vec2_map(src: Variant) -> Dictionary:
    var out: Dictionary = {}
    if src is Dictionary:
        var sd: Dictionary = src
        for k in sd.keys():
            out[k] = _to_vec2(sd[k])
    return out

# Serialize helpers: Vector2 -> JSON-safe
func _vec2_to_json(v: Vector2) -> Dictionary:
    return {"x": v.x, "y": v.y}

func _vec2_map_to_json(src: Dictionary) -> Dictionary:
    var out: Dictionary = {}
    for k in src.keys():
        var vv = src[k]
        if vv is Vector2:
            out[k] = _vec2_to_json(vv)
        else:
            out[k] = vv
    return out

 

func save_game() -> bool:
    var p = get_tree().current_scene.get_node_or_null("player")
    if not is_instance_valid(p):
        push_warning("Save failed: Player node not found in current scene.")
        return false

    # Snapshot current alive enemy positions so they restore on load
    enemy_positions.clear()
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(enemy):
            # Only save if not already in killed list
            if not killed_enemies.has(enemy.name):
                enemy_positions[enemy.name] = enemy.global_position

    var data: Dictionary = {
        "scene_path": get_tree().current_scene.scene_file_path,
        "player_position": _vec2_to_json(p.global_position),
        "player_has_key": player_has_key,
        "key_dropped": key_dropped,
        "key_position": _vec2_to_json(key_position),
        "killed_enemies": killed_enemies,
        "chest_opened": chest_opened,
        "enemy_positions": _vec2_map_to_json(enemy_positions)
    }
    print("[Save] player_pos=", p.global_position, 
        " key_dropped=", key_dropped, " key_pos=", key_position,
        " killed_enemies=", killed_enemies.size(),
        " enemies_tracked=", enemy_positions.size())
    
    var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        push_warning("Failed to open save file for writing: %s" % [SAVE_PATH])
        return false
        
    f.store_string(JSON.stringify(data, "  ")) # Using "  " makes the save file human-readable for debugging
    f.flush()
    f.close() # ensure data is written
    var abs := ProjectSettings.globalize_path(SAVE_PATH)
    print("Save file written and closed successfully at ", abs)
    return true

func load_game() -> bool:
    if not has_save():
        return false
    var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return false
    var txt: String = f.get_as_text()
    var parsed: Variant = JSON.parse_string(txt)
    if not (parsed is Dictionary):
        push_warning("Save file corrupted")
        return false
    var d: Dictionary = parsed as Dictionary
    # Restore globals
    player_has_key = (d.get("player_has_key", false) as bool)
    key_dropped = (d.get("key_dropped", false) as bool)
    key_position = _to_vec2(d.get("key_position", Vector2.ZERO))
    killed_enemies = (d.get("killed_enemies", []) as Array)
    chest_opened = (d.get("chest_opened", {}) as Dictionary)
    enemy_positions = _dict_vec2_map(d.get("enemy_positions", {}))
    print("[Load] key_dropped=", key_dropped, " key_pos=", key_position, 
        " killed_enemies=", killed_enemies.size(), " enemies_tracked=", enemy_positions.size())
    # Position and scene
    next_player_position = _to_vec2(d.get("player_position", Vector2.ZERO))
    game_first_loadin = false
    var scene_path: String = (d.get("scene_path", "res://scenes/world.tscn") as String)
    current_scene = scene_path.get_file().get_basename()
    get_tree().change_scene_to_file(scene_path)
    # After scene swaps, sync HUD state on next frame
    await get_tree().process_frame
    emit_signal("key_changed", player_has_key)
    return true

func collect_key():
    player_has_key = true
    emit_signal("key_changed", true)
    print("Key collected!")

func set_enemies_progress(defeated: int, total: int) -> void:
    emit_signal("enemies_progress_changed", defeated, total)

func set_player_health(value: int) -> void:
    emit_signal("player_health_changed", value)
