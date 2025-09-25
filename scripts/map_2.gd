extends Node2D

@export var key_scene: PackedScene

var total_enemies := 0
var enemies_defeated := 0

func _ready() -> void:
	_ensure_status_hud()
	# Start this map without the key until the player actually picks it up
	if has_node("/root/global"):
		global.player_has_key = false
		global.key_changed.emit(false)
	_update_enemy_bindings()
	# Place player camera like world.gd expects
	if has_node("/root/global"):
		global.current_scene = "map_2"
		# position player if needed; keep current if already placed
		var p := get_node_or_null("player")
		if p:
			p.position = p.position

	# Respawn dropped key if any
	if global.key_dropped and not global.player_has_key:
		spawn_key(global.key_position)

func _update_enemy_bindings() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	total_enemies = enemies.size()
	if total_enemies == 0:
		global.set_enemies_progress(0, 0)
		return
	for enemy in enemies:
		# Restore persisted position if stored
		var saved_pos = global.get_enemy_position(enemy.name)
		if saved_pos != null:
			enemy.global_position = saved_pos
		# Connect once
		if not enemy.died.is_connected(_on_enemy_defeated):
			enemy.died.connect(_on_enemy_defeated.bind(enemy.name))
	global.set_enemies_progress(enemies_defeated, total_enemies)

func _on_enemy_defeated(enemy_position: Vector2, enemy_name: String) -> void:
	enemies_defeated += 1
	global.clear_enemy_position(enemy_name)
	global.set_enemies_progress(enemies_defeated, total_enemies)
	if enemies_defeated >= total_enemies:
		global.set_key_dropped(enemy_position)
		spawn_key(enemy_position)

func spawn_key(position: Vector2) -> void:
	if key_scene == null:
		var default_key := load("res://scenes/key.tscn")
		if default_key: key_scene = default_key
	if key_scene:
		var key_instance := key_scene.instantiate()
		key_instance.global_position = position
		add_child(key_instance)
		key_instance.collected.connect(on_key_collected)

func on_key_collected() -> void:
	global.player_has_key = true
	global.clear_key_drop()
	if global.has_method("collect_key"):
		global.collect_key()

func _ensure_status_hud() -> void:
	if get_tree().root.get_node_or_null("StatusHUD") == null:
		var hud_scene: PackedScene = load("res://scenes/status_hud.tscn")
		if hud_scene != null:
			var hud: Node = hud_scene.instantiate()
			hud.name = "StatusHUD"
			get_tree().root.add_child(hud)
