extends Control

@onready var video_player: VideoStreamPlayer = $VideoPlayer
@onready var skip_button: Button = $SkipButton

# Store the original audio bus state
var was_music_muted: bool = false

func _ready() -> void:
	# Set the video file
	var video_stream = preload("res://assets/videos/intro_cutscene.ogv")
	if video_stream:
		video_player.stream = video_stream
	
	# Configure video scaling
	video_player.size = get_viewport_rect().size
	video_player.expand_mode = 1  # Keep aspect ratio
	
	# Ensure music is muted (in case it wasn't muted from main menu)
	var music_bus_idx = AudioServer.get_bus_index("Music")
	was_music_muted = AudioServer.is_bus_mute(music_bus_idx)
	if not was_music_muted:
		AudioServer.set_bus_mute(music_bus_idx, true)
	
	# Connect signals
	skip_button.pressed.connect(_on_skip_pressed)
	video_player.finished.connect(_on_video_finished)
	
	# Start playing the video
	video_player.play()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # ESC key
		_on_skip_pressed()

func _on_skip_pressed() -> void:
	video_player.stop()
	_end_cutscene()

func _on_video_finished() -> void:
	_end_cutscene()

func _end_cutscene() -> void:
	# Restore music state if it wasn't muted before
	if not was_music_muted:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
	
	# Transition to the game
	get_tree().change_scene_to_file("res://scenes/world.tscn")
