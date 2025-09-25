extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings: Panel = $Settings
@onready var multiplayer_panel: Panel = $Multiplayer

func _process(_delta):
	pass

func _ready():
	main_buttons.visible = true
	settings.visible = false
	multiplayer_panel.visible = false


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_settings_pressed() -> void:
	print("Settings pressed")
	main_buttons.visible = false
	settings.visible = true


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_back_options_pressed() -> void:
	_ready() 


func _on_fullscreen_control_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# === Multiplayer panel handlers ===
func _on_multiplayer_pressed() -> void:
	main_buttons.visible = false
	settings.visible = false
	multiplayer_panel.visible = true

func _on_mp_back_pressed() -> void:
	multiplayer_panel.visible = false
	_ready()

func _on_mp_host_pressed() -> void:
	var mp := _get_or_create_mp()
	if mp:
		mp.call_deferred("start_host")
	else:
		get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_mp_join_pressed() -> void:
	# Default join to localhost; replace with IP prompt scene if needed
	var mp := _get_or_create_mp()
	if mp:
		mp.call_deferred("start_client", "127.0.0.1")
	else:
		get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_mp_local_pressed() -> void:
	# Start authoritative local multiplayer (create manager if not autoloaded)
	var mp := _get_or_create_mp()
	if mp:
		mp.call_deferred("start_local")
	else:
		get_tree().change_scene_to_file("res://scenes/world.tscn")
func _get_or_create_mp() -> Node:
	var root := get_tree().root
	var node := root.get_node_or_null("MultiplayerManager")
	if node:
		return node
	# If the autoload is not set, create an instance manually
	var script: Script = load("res://scripts/multiplayer_manager.gd")
	if script == null:
		return null
	var inst: Node = script.new()
	inst.name = "MultiplayerManager"
	root.add_child(inst)
	return inst
