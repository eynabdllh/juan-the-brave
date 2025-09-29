extends Control

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var skip_button: Button = $SkipButton

# Store the original audio bus state
var was_music_muted: bool = false

func _ready() -> void:
	print("Intro cutscene ready")
	
	# Ensure the viewport is properly set up
	get_viewport().transparent_bg = true
	
	# Configure video player
	video_player.size = get_viewport_rect().size
	
	
	# Pause and mute background music
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0 and not AudioServer.is_bus_mute(music_bus_idx):
		was_music_muted = false
		AudioServer.set_bus_mute(music_bus_idx, true)
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
	if video_player and video_player.is_playing():
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
	
	print("Transitioning to world scene...")
	# Transition to the world scene
	get_tree().change_scene_to_file("res://scenes/world.tscn")
