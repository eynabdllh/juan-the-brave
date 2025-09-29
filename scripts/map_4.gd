extends Node2D

@onready var player = $player
@onready var tilemap = $TileMap
@onready var status_hud = get_tree().root.get_node_or_null("StatusHUD")

func _ready():
	# Position the player based on where they came from
	if global.next_player_position != Vector2.ZERO:
		player.position = global.next_player_position
		global.next_player_position = Vector2.ZERO
	else:
		player.position = Vector2(227, 298)
	
	# Set up camera limits based on TileMap
	setup_camera_limits()

	# If outro requested The End overlay, show it now
	var g := get_node_or_null("/root/global")
	if g and g.show_end_overlay:
		print("[map_4] show_end_overlay=true; preparing overlay…")
		g.show_end_overlay = false
		# Defer one frame to allow scene to finish entering tree
		call_deferred("_show_the_end_overlay")

	# Start map-specific music
	_play_map_music()

func _show_the_end_overlay() -> void:
	if not ResourceLoader.exists("res://scenes/the_end.tscn"):
		print("[map_4] the_end.tscn not found")
		return
	var end_scene: PackedScene = load("res://scenes/the_end.tscn")
	if not end_scene:
		print("[map_4] failed to load the_end.tscn")
		return
	# Avoid duplicates if re-entering
	var existing := get_tree().root.get_node_or_null("EndOverlayLayer")
	if existing:
		print("[map_4] End overlay already present; skipping add")
	else:
		var end_ui := end_scene.instantiate()
		var layer := CanvasLayer.new()
		layer.name = "EndOverlayLayer"
		layer.layer = 100
		# Defer adding to ensure the scene tree stabilized
		get_tree().root.call_deferred("add_child", layer)
		layer.call_deferred("add_child", end_ui)
		print("[map_4] End overlay added on CanvasLayer layer=", layer.layer)
	# Pause game while overlay is up (the_end.gd also pauses defensively)
	get_tree().paused = true
func _play_map_music() -> void:
	# Ensure the Music bus is unmuted and play a map-specific track
	var music_bus_idx := AudioServer.get_bus_index("Music")
	if music_bus_idx >= 0:
		AudioServer.set_bus_mute(music_bus_idx, false)
		print("[map_4] Music bus index=", music_bus_idx, " muted=", AudioServer.is_bus_mute(music_bus_idx))

	# Stop any other players currently using the Music bus so only map music plays
	_stop_other_music_players()

	var player: AudioStreamPlayer = get_node_or_null("MapMusic")
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = "MapMusic"
		player.bus = "Music"
		# Keep playing even if the game is paused by overlays
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
	player.volume_db = -3.0  # slight attenuation

	if player.stream == null:
		# Replace with your actual map 4 music path
		var stream: AudioStream = load("res://assets/music/ending.mp3")
		if stream:
			player.stream = stream
			# Try to enable looping if supported
			if "loop" in stream:
				stream.loop = true
			print("[map_4] Loaded music stream:", stream)
		else:
			push_warning("[map_4] Music stream not found at res://assets/music/ending.mp3. Set the correct path.")
			return

	if not player.playing:
		player.play()
		print("[map_4] Map music started. playing=", player.playing)

func _stop_other_music_players() -> void:
	var root := get_tree().root
	if root == null:
		return
	var to_stop := 0
	var map_player := get_node_or_null("MapMusic")
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is AudioStreamPlayer:
			var p := n as AudioStreamPlayer
			if p != map_player and p.playing and p.bus == "Music":
				p.stop()
				to_stop += 1
		for c in n.get_children():
			stack.push_back(c)
	if to_stop > 0:
		print("[map_4] Stopped ", to_stop, " other Music bus players")


func setup_camera_limits():
	var camera = player.get_node_or_null("house_camera") 
	
	if camera:       
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = 400
		camera.limit_bottom = 304 
		camera.limit_smoothed = true
		
		camera.make_current()
