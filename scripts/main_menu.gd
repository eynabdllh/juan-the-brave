extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings: Panel = $Settings

func _process(_delta):
	# Unused delta parameter - keeping for potential future use
	pass

func _ready():
	main_buttons.visible = true
	settings.visible = false 


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


# Triggered by the "Multiplayer" button in the main menu
func _on_multiplayer_pressed() -> void:
	# NOTE: Ensure this scene exists as per MULTIPLAYER_SETUP.md
	print("[MainMenu] Multiplayer button pressed")
	var target := "res://scenes/multiplayer_lobby.tscn"
	if ResourceLoader.exists(target):
		var err := get_tree().change_scene_to_file(target)
		if err != OK:
			push_error("Failed to change scene to: " + target + ". Error: " + str(err))
			OS.alert("Failed to open multiplayer lobby. Error code: %s" % [str(err)], "Error")
	else:
		var msg := "Multiplayer lobby scene not found at:\n" + target + "\n\nPlease create it (see MULTIPLAYER_SETUP.md)."
		push_error(msg)
		OS.alert(msg, "Missing Scene")
