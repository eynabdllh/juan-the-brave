# In file: game/scripts/pause_manager.gd
extends CanvasLayer

# Get a reference to the child menu scene we added in the editor.
@onready var pause_menu: Control = $pause_menu

func _ready():
    # The manager must always process, even when the game is paused.
    process_mode = Node.PROCESS_MODE_ALWAYS
    
    # The menu is part of the scene, so we just make sure it's hidden on start.
    if is_instance_valid(pause_menu):
        pause_menu.hide()

func _input(event: InputEvent):
    # We use _input to catch the event before other game nodes can consume it.
    if Input.is_action_just_pressed("ui_cancel"):
        if is_instance_valid(pause_menu):
            pause_menu.toggle()
            # Mark the event as handled so nothing else processes the Esc key.
            get_viewport().set_input_as_handled()
