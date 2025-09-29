extends Control

@onready var restart_button: Button = $VBoxContainer/RestartButton
@onready var exit_button: Button = $VBoxContainer/ExitButton
@onready var blood_overlay: TextureRect = $BloodOverlay
@onready var dim: ColorRect = $Dim

func _ready() -> void:
	# UI should work even if the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Ensure overlay covers viewport
	var rect = get_viewport_rect()
	dim.size = rect.size
	blood_overlay.size = rect.size
	
	# Connect buttons
	restart_button.pressed.connect(_on_restart_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Start with overlays invisible and fade them in
	dim.modulate.a = 0.0
	blood_overlay.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(dim, "modulate:a", 0.6, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(blood_overlay, "modulate:a", 0.85, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Pause game while on Game Over
	get_tree().paused = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	# Remove the wrapping CanvasLayer as well so future deaths can recreate it
	var layer := get_parent()
	if layer and layer is CanvasLayer and layer.name == "GameOverLayer":
		layer.queue_free()
	else:
		queue_free()
	# Reset game state and go to first level (world)
	var g := get_tree().root.get_node_or_null("global")
	if g and g.has_method("reset_game_state"):
		g.reset_game_state()
	if ResourceLoader.exists("res://scenes/world.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://scenes/world.tscn")
	else:
		get_tree().call_deferred("reload_current_scene")

func _on_exit_pressed() -> void:
	get_tree().paused = false
	# Remove the wrapping CanvasLayer as well so future deaths can recreate it
	var layer := get_parent()
	if layer and layer is CanvasLayer and layer.name == "GameOverLayer":
		layer.queue_free()
	else:
		queue_free()
	if ResourceLoader.exists("res://scenes/main_menu.tscn"):
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")
	else:
		get_tree().quit()
