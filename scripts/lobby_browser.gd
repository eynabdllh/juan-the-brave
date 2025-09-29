extends Control

@onready var lobby_list = $VBoxContainer/LobbyList
var lobbies = {}

func _ready():
	network.lobbies_list_changed.connect(_on_lobbies_list_changed)
	network.find_lobbies()

func _on_lobbies_list_changed(new_lobbies):
	lobbies.merge(new_lobbies)
	for child in lobby_list.get_children():
		child.queue_free()

	for ip in lobbies.keys():
		var lobby_info = lobbies[ip]
		var button = Button.new()
		button.text = "Lobby by %s (%d/%d)" % [lobby_info.host_name, lobby_info.player_count, lobby_info.max_players]
		button.pressed.connect(func(): _on_join_lobby_pressed(ip))
		lobby_list.add_child(button)

func _on_join_lobby_pressed(ip):
	network.join_server(ip)
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_refresh_button_pressed():
	network.find_lobbies()

func _on_back_button_pressed():
	network.udp_socket.close()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_join_by_ip_button_pressed():
	var ip = $VBoxContainer/IpField.text.strip_edges()
	if ip == "":
		return
	network.join_server(ip)
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
