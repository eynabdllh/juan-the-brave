extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings: Panel = $Settings
@onready var multiplayer_panel: Panel = $Multiplayer
@onready var fullscreen_control: CheckButton = $Settings/VBoxContainer/FullscreenControl
var load_button: Button = null

func _process(_delta):
    pass

func _ready():
    visibility_changed.connect(_on_visibility_changed)
    main_buttons.visible = true
    settings.visible = false
    multiplayer_panel.visible = false
    # Cache optional Load Game button if present in scene
    load_button = get_node_or_null("MainButtons/load")
    _refresh_load_state() 
    # Ensure gameplay HUD is not present on main menu
    var hud := get_tree().root.get_node_or_null("StatusHUD")
    if hud:
        hud.queue_free()
    # Initialize fullscreen toggle to reflect current mode
    if is_instance_valid(fullscreen_control):
        fullscreen_control.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
    _refresh_load_state()


func _on_start_pressed() -> void:
    if typeof(global) != TYPE_NIL and global.has_method("reset_game_state"):
        global.reset_game_state()
    get_tree().paused = false
    
    # Stop any playing music from main menu
    var music_bus_idx = AudioServer.get_bus_index("Music")
    AudioServer.set_bus_mute(music_bus_idx, true)
    
    # Load and show the intro cutscene
    get_tree().change_scene_to_file("res://scenes/intro_cutscene.tscn")


func _on_settings_pressed() -> void:
    print("Settings pressed")
    main_buttons.visible = false
    settings.visible = true


func _on_exit_pressed() -> void:
    get_tree().quit()


func _on_back_options_pressed() -> void:
    _ready() 

func _on_visibility_changed():
    if visible:
        print("Main menu is visible. Refreshing load button state.")
        _refresh_load_state()

func _refresh_load_state():
    if is_instance_valid(load_button):
        var has_save_file := false
        if typeof(global) != TYPE_NIL:
            has_save_file = global.has_save()
        # This print will tell you exactly what the function sees
        print("[MainMenu] Checking for save file. Found: ", has_save_file)
        load_button.disabled = not has_save_file

func _on_load_pressed():
    # This function will attempt load directly via autoload (coroutine)
    if typeof(global) != TYPE_NIL:
        var ok: bool = await global.load_game()
        if not ok:
            push_warning("Load game failed or no save file found.")
    else:
        push_warning("Global autoload not found.")


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
