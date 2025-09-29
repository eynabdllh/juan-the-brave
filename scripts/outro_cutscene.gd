extends Control

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var skip_button: Button = $SkipButton

# Store the original audio bus state
var was_music_muted: bool = false

# Store references to hidden UI elements
var hidden_status_hud: Node = null
var hidden_inventory: Node = null

func _ready() -> void:
	print("Outro cutscene ready")
	
	# Hide status HUD and inventory during cutscene
	_hide_gameplay_ui()
	
	# Ensure the viewport is properly set up
	get_viewport().transparent_bg = true
	
	# Configure video player
	video_player.size = get_viewport_rect().size
	
	# Pause and mute background music
	if AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) == false:
		was_music_muted = false
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	else:
		was_music_muted = true
	
	# Connect signals
	if skip_button and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)
	if video_player and not video_player.finished.is_connected(_on_video_finished):
		video_player.finished.connect(_on_video_finished)
	
	# Start playing the video
	print("Starting video playback...")
	video_player.play()
	print("Video player state - Playing:", video_player.is_playing(), " Stream:", video_player.stream != null)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and event.is_pressed() and not event.is_echo():
		print("ESC key pressed")
		get_viewport().set_input_as_handled()
		_on_skip_pressed()

func _on_skip_pressed() -> void:
	print("Skip button pressed")
	if video_player.is_playing():
		video_player.stop()
	_end_cutscene()

func _on_video_finished() -> void:
	print("Video finished playing")
	_end_cutscene()

func _end_cutscene() -> void:
	print("Ending cutscene...")
	
	# Disconnect signals to prevent multiple calls
	if skip_button and skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.disconnect(_on_skip_pressed)
	if video_player and video_player.finished.is_connected(_on_video_finished):
		video_player.finished.disconnect(_on_video_finished)
	
	# Restore music state if it wasn't muted before
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0 and not was_music_muted:
		print("Restoring music state...")
		AudioServer.set_bus_mute(music_bus_idx, false)
	
	print("Transitioning to the end screen...")
	
	# Ensure all cleanup is done before changing scenes
	call_deferred("_go_to_the_end")

func _go_to_the_end() -> void:
	# Ask next scene to show The End overlay
	var g := get_node_or_null("/root/global")
	if g:
		g.show_end_overlay = true
	
	# Change to map_4; map_4.gd will handle showing the overlay in _ready()
	if ResourceLoader.exists("res://scenes/map_4.tscn"):
		print("[outro] changing scene to map_4; overlay requested via global flag")
		get_tree().change_scene_to_file("res://scenes/map_4.tscn")
	else:
		print("Warning: map_4.tscn not found. Returning to main menu.")
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _hide_gameplay_ui() -> void:
	print("Hiding gameplay UI elements...")
	
	# Hide status HUD
	var root := get_tree().root
	hidden_status_hud = root.get_node_or_null("StatusHUD")
	if hidden_status_hud and hidden_status_hud is CanvasItem:
		hidden_status_hud.visible = false
		print("Status HUD hidden")
	
	# Hide inventory if it exists
	hidden_inventory = root.get_node_or_null("Inventory")
	if hidden_inventory and hidden_inventory is CanvasItem:
		hidden_inventory.visible = false
		print("Inventory hidden")
	
	# Also check for any other UI elements that might be visible
	var current_scene := get_tree().current_scene
	if current_scene:
		# Hide any UI nodes in the current scene that might be gameplay-related
		for child in current_scene.get_children():
			if child.name.to_lower().contains("hud") or child.name.to_lower().contains("ui"):
				if child is CanvasItem:
					child.visible = false
					print("Hidden UI element: ", child.name)
