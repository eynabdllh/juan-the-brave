extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings: Panel = $Settings
@onready var multiplayer_panel: Panel = $Multiplayer

func _process(delta):
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
	# Defer to multiplayer manager scene if present; else go straight to world
	if has_node("/root/MultiplayerManager"):
		get_node("/root/MultiplayerManager").call_deferred("start_host")
	else:
		get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_mp_join_pressed() -> void:
	# Default join to localhost; replace with IP prompt scene if needed
	if has_node("/root/MultiplayerManager"):
		get_node("/root/MultiplayerManager").call_deferred("start_client", "127.0.0.1")
	else:
		get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_mp_local_pressed() -> void:
	# Enable local co-op by going to world directly; world.gd can spawn P2
	get_tree().change_scene_to_file("res://scenes/world.tscn")
