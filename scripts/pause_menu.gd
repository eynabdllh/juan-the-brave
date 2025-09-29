extends Control

@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var restart_button: Button = $Panel/VBox/RestartButton
@onready var save_button: Button = $Panel/VBox/SaveButton
@onready var options_button: Button = $Panel/VBox/OptionsButton
@onready var howto_button: Button = $Panel/VBox/HowToButton
@onready var quit_button: Button = $Panel/VBox/QuitButton
@onready var save_status: Label = $Panel/VBox/SaveStatus
@onready var options_panel: Panel = $OptionsPanel
@onready var options_back: Button = $OptionsPanel/Back
@onready var howto_panel: Panel = $HowToPanel
@onready var howto_back: Button = $HowToPanel/Back
@onready var audio_slider: HSlider = $OptionsPanel/VBox/AudioControl
@onready var fullscreen_check: CheckButton = $OptionsPanel/VBox/FullscreenControl

func _ready():
	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	options_button.pressed.connect(_on_options_pressed)
	howto_button.pressed.connect(_on_howto_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	options_back.pressed.connect(_on_options_back_pressed)
	howto_back.pressed.connect(_on_howto_back_pressed)

	# Option controls
	if is_instance_valid(audio_slider):
		audio_slider.value_changed.connect(_on_audio_value_changed)
		# Initialize from current bus volume (Music)
		var bus := AudioServer.get_bus_index("Music")
		if bus >= 0:
			var db := AudioServer.get_bus_volume_db(bus)
			audio_slider.value = clamp(db_to_linear(db), 0.0, 1.0)
	if is_instance_valid(fullscreen_check):
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
		fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	# Hide on start
	visible = false

func show_menu():
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()
	if is_instance_valid(save_status):
		save_status.text = ""
		save_status.modulate = Color(1,1,1,1)

func hide_menu():
	visible = false
	get_tree().paused = false
	# Ensure subpanels are hidden when closing menu
	if is_instance_valid(options_panel): options_panel.hide()
	if is_instance_valid(howto_panel): howto_panel.hide()

func toggle():
	if visible:
		hide_menu()
	else:
		show_menu()

func _on_resume_pressed():
	hide_menu()

func _on_restart_pressed():
	# Unpause first, then reload scene
	var tree := get_tree()
	if tree:
		# Close the pause menu immediately
		hide_menu()
		# Ensure next load uses the configured start position
		if Engine.has_singleton("global"):
			# If global is an autoload, use it directly via the autoload name
			global.game_first_loadin = true
			global.next_player_position = Vector2.ZERO
		tree.paused = false
		var err := tree.reload_current_scene()
		if err != OK:
			push_warning("Failed to reload current scene: %s" % [err])
	else:
		push_warning("SceneTree is null; cannot restart.")

func _on_options_pressed():
	if is_instance_valid(options_panel):
		options_panel.show()
		options_back.grab_focus()
		# Optionally hide main list behind
		$Panel.hide()

func _on_howto_pressed():
	if is_instance_valid(howto_panel):
		howto_panel.show()
		howto_back.grab_focus()
		$Panel.hide()

func _on_quit_pressed():
	# Ensure we unpause before quitting
	var tree := get_tree()
	if tree:
		# Close the pause menu immediately
		hide_menu()
		tree.paused = false
		if Engine.has_singleton("global"):
			global.go_to_main_menu()
		else:
			tree.change_scene_to_file("res://scenes/main_menu.tscn")

func _on_save_button_pressed() -> void:
	var ok := false
	if typeof(global) != TYPE_NIL:
		ok = global.save_game()
	var wrote := ok
	if ok and typeof(global) != TYPE_NIL and global.has_method("has_save"):
		# Double-check file presence
		wrote = global.has_save()
	if is_instance_valid(save_status):
		if wrote:
			save_status.modulate = Color(0.2, 0.8, 0.3)
			save_status.text = "Saved!"
		else:
			save_status.modulate = Color(0.9, 0.3, 0.2)
			save_status.text = "Save failed"
		save_status.visible = true
		# Fade out after 1.2s
		var tw := create_tween()
		save_status.modulate.a = 1.0
		tw.tween_interval(2.0)
		tw.tween_property(save_status, "modulate:a", 0.0, 0.8)
		tw.tween_callback(Callable(self, "_clear_save_status"))
	if ok:
		print("Game saved.")
	else:
		push_warning("Failed to save game.")


func _clear_save_status() -> void:
	if is_instance_valid(save_status):
		save_status.text = ""
		save_status.modulate.a = 1.0

func _on_audio_value_changed(v: float) -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(clamp(v, 0.0, 1.0)))

func _on_fullscreen_toggled(on: bool) -> void:
	if on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_options_back_pressed():
	options_panel.hide()
	$Panel.show()
	resume_button.grab_focus()

func _on_howto_back_pressed():
	howto_panel.hide()
	$Panel.show()
	resume_button.grab_focus()

func _on_fullscreen_control_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed() -> void:
	pass # Replace with function body.
