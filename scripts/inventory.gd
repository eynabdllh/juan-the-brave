extends Node

# Inventory singleton: manages 3 item types: potion, bread, amulet
# Expose signals so UI can react
signal item_added(item: String, new_count: int)
signal item_used(item: String, new_count: int)
signal selection_changed(index: int)

# Order for UI slots
const ORDER := ["potion", "bread", "amulet"]

# Item icons (used by UI/popup callers if they want)
const ICONS := {
    "potion": preload("res://assets/objects/potion.png"),
    "bread": preload("res://assets/objects/monay.png"),
    "amulet": preload("res://assets/objects/amulet.png"),
}

var counts := {
    "potion": 0,
    "bread": 0,
    "amulet": 0,
}

# Config
var potion_duration := 15.0 # seconds
var amulet_duration := 10.0 # seconds

var selected_index := 0
var _last_use_ms := 0

func _ready():
    randomize()
    # Announce initial selection for UI
    emit_signal("selection_changed", selected_index)
    # We will use _input with Input singleton; no need for _unhandled_input.

func _input(event: InputEvent) -> void:
    # Process hotkeys once per press using the Input singleton
    if Input.is_action_just_pressed("use_slot_1"):
        print("Inventory: use_slot_1 pressed")
        set_selected_index(0)
        _debounced_use_selected()
    elif Input.is_action_just_pressed("use_slot_2"):
        print("Inventory: use_slot_2 pressed")
        set_selected_index(1)
        _debounced_use_selected()
    elif Input.is_action_just_pressed("use_slot_3"):
        print("Inventory: use_slot_3 pressed")
        set_selected_index(2)
        _debounced_use_selected()

func _debounced_use_selected() -> void:
    var now := Time.get_ticks_msec()
    if now - _last_use_ms < 150:
        return
    _last_use_ms = now
    use_selected()

func set_selected_index(i: int) -> void:
    selected_index = clamp(i, 0, ORDER.size() - 1)
    emit_signal("selection_changed", selected_index)

func add_item(item: String, amount: int = 1) -> void:
    if not counts.has(item):
        return
    counts[item] += amount
    emit_signal("item_added", item, counts[item])

func can_use(item: String) -> bool:
    return counts.get(item, 0) > 0

func use_item(item: String) -> void:
    if not can_use(item):
        print("Inventory: cannot use ", item, " (count=", counts.get(item, 0), ")")
        return
    match item:
        "potion":
            _apply_potion()
        "bread":
            _apply_bread()
        "amulet":
            print("Inventory: applying amulet")
            _apply_amulet()
    # decrement after successful application
    counts[item] -= 1
    emit_signal("item_used", item, counts[item])

func use_selected() -> void:
    var item : String= ORDER[selected_index]
    use_item(item)

# --- Effect implementations ---
func _apply_bread():
    # Heal to full
    var player := _get_player()
    if player and player.has_method("heal") and player.has_method("update_health"):
        var missing := 100 - int(player.health)
        if missing > 0:
            player.heal(missing)
            if has_node("/root/global"):
                get_node("/root/global").heal_applied.emit(missing)

func _apply_amulet():
    global.player_invincible = true
    var p := _get_player()
    if p and p.has_method("start_invincible_fx"):
        p.start_invincible_fx(amulet_duration)
    if has_node("/root/global"):
        get_node("/root/global").start_buff("amulet", amulet_duration, "Invincible")
    # Wait until the global buff actually ends (supports extension)
    while has_node("/root/global") and get_node("/root/global").is_buff_active("amulet"):
        await get_tree().process_frame
    global.player_invincible = false
    if p and p.has_method("stop_invincible_fx"):
        p.stop_invincible_fx()
    # end handled by global tick

func _apply_potion():
    # Random: damage up OR speed up OR invincible
    var effect := randi() % 3
    match effect:
        0:
            global.player_damage_bonus = 20
            if has_node("/root/global"):
                get_node("/root/global").start_buff("potion_damage", potion_duration, "Damage Up")
            # Wait while this specific buff is active (supports extension)
            while has_node("/root/global") and get_node("/root/global").is_buff_active("potion_damage"):
                await get_tree().process_frame
            global.player_damage_bonus = 0
        1:
            global.player_speed_mult = 1.6
            if has_node("/root/global"):
                get_node("/root/global").start_buff("potion_speed", potion_duration, "Speed Up")
            var p := _get_player()
            if p and p.has_method("start_speed_trail"):
                print("Inventory: starting speed trail for ", potion_duration, "s")
                p.start_speed_trail(potion_duration)
            # Wait while buff is active (supports extension)
            while has_node("/root/global") and get_node("/root/global").is_buff_active("potion_speed"):
                await get_tree().process_frame
            global.player_speed_mult = 1.0
            if p and p.has_method("stop_speed_trail"):
                p.stop_speed_trail()
        2:
            global.player_invincible = true
            if has_node("/root/global"):
                get_node("/root/global").start_buff("potion_invincible", potion_duration, "Invincible")
            while has_node("/root/global") and get_node("/root/global").is_buff_active("potion_invincible"):
                await get_tree().process_frame
            global.player_invincible = false

func _get_player() -> Node:
    var list := get_tree().get_nodes_in_group("player")
    return list[0] if list.size() > 0 else null

func get_counts() -> Dictionary:
    return counts.duplicate()
