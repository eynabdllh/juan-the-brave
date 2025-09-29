extends Control

@onready var player_list = $VBoxContainer/PlayerList
@onready var ready_button = $VBoxContainer/ReadyButton
@onready var start_button = $VBoxContainer/StartButton

func _ready():
	# Show Start only for host
	start_button.visible = multiplayer.is_server()

	# Connect to network signals
	network.player_list_changed.connect(Callable(self, "_on_player_list_changed"))
	network.game_started.connect(Callable(self, "_on_game_started"))

	# Initial UI update
	_on_player_list_changed(network.get_player_list())

func _on_player_list_changed(players):
	# Clear old list
	for child in player_list.get_children():
		child.queue_free()

	var all_ready = true
	for id in players.keys():
		var player_info = players[id]
		var label = Label.new()
		var is_ready = false
		if typeof(player_info) == TYPE_DICTIONARY:
			is_ready = player_info.get("ready", false)
		var status = "Ready" if is_ready else "Not Ready"
		player_list.add_child(label)
		label.text = "Player %d: %s" % [id, status]

		if not is_ready:
			all_ready = false
	# Enable Start only if host, at least 2 players, and all are ready
	if multiplayer.is_server():
		var player_count := 0
		for _k in players.keys():
			player_count += 1
		start_button.disabled = not (all_ready and player_count >= 2)

func _on_ready_button_pressed():
	ready_button.disabled = true
	network.toggle_ready_state()

func _on_start_button_pressed():
	network.start_game()

func _on_leave_button_pressed():
	network.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_game_started():
	get_tree().change_scene_to_file("res://scenes/world.tscn")
