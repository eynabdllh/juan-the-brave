extends Control

@onready var continue_button: Button = $Center/VBoxContainer/ContinueButton
@onready var restart_button: Button = $Center/VBoxContainer/RestartButton
@onready var exit_button: Button = $Center/VBoxContainer/ExitButton
@onready var dim: ColorRect = $Dim

func _ready() -> void:
    # UI should work even if the game is paused
    process_mode = Node.PROCESS_MODE_ALWAYS
    
    # Ensure overlay covers viewport
    dim.size = get_viewport_rect().size
    
    # Connect buttons
    continue_button.pressed.connect(_on_continue_pressed)
    restart_button.pressed.connect(_on_restart_pressed)
    exit_button.pressed.connect(_on_exit_pressed)
    
    # Pause while showing end screen
    get_tree().paused = true

func _on_continue_pressed() -> void:
    # We're already on the target scene (e.g., map_4).
    # Just unpause and close this overlay.
    get_tree().paused = false
    queue_free()

func _on_restart_pressed() -> void:
    get_tree().paused = false
    # Hide this overlay immediately
    queue_free()
    # Restart from world or first level; customize as needed
    if ResourceLoader.exists("res://scenes/world.tscn"):
        get_tree().call_deferred("change_scene_to_file", "res://scenes/world.tscn")
    else:
        get_tree().call_deferred("reload_current_scene")

func _on_exit_pressed() -> void:
    get_tree().paused = false
    # Hide this overlay immediately
    queue_free()
    get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")
