extends Node

signal player_list_changed(players)
signal game_started
signal lobbies_list_changed(lobbies)


const DEFAULT_PORT = 24555
const MAX_CLIENTS = 1

var peer

var players = {}
var udp_socket = PacketPeerUDP.new()
const BROADCAST_PORT = 24556

func connection_succeeded():
	print("Connected to server.")

func connection_failed():
	print("Failed to connect.")

func _ready():
	multiplayer.peer_connected.connect(player_connected)
	multiplayer.peer_disconnected.connect(player_disconnected)
	multiplayer.connected_to_server.connect(connection_succeeded)
	multiplayer.connection_failed.connect(connection_failed)

func create_server():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if error != OK:
		print("Cannot create server.")
		return

	multiplayer.multiplayer_peer = peer

	# Add host to player list
	players[1] = { "name": "Host", "ready": false }
	player_list_changed.emit(players)

	# Start broadcasting lobby info
	set_process(true)
	
func join_server(ip_address):
	# Stop lobby discovery on this peer
	udp_socket.close()
	set_process(false)
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_address, DEFAULT_PORT)
	multiplayer.multiplayer_peer = peer
func player_connected(id):
	print("Player ", id, " connected.")
	if multiplayer.is_server():
		# Track new player for lobby view (optional)
		players[id] = { "name": "Player " + str(id), "ready": false }
		# Spawn on all peers and locally on server
		var pm = get_node_or_null("/root/world/PlayerManager")
		if pm:
			for peer_id in multiplayer.get_peers():
				pm.rpc_id(peer_id, "add_player", id)
			pm.add_player(id)
		# Update lobby UIs
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "_update_player_list", players)
		player_list_changed.emit(players)

func player_disconnected(id):
	print("Player ", id, " disconnected.")
	if multiplayer.is_server():
		players.erase(id)
		var pm = get_node_or_null("/root/world/PlayerManager")
		if pm:
			for peer_id in multiplayer.get_peers():
				pm.rpc_id(peer_id, "remove_player", id)
			pm.remove_player(id)
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "_update_player_list", players)
		player_list_changed.emit(players)


func disconnect_from_server():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	players.clear()
	udp_socket.close()

func get_player_list():
	return players

func toggle_ready_state():
	var id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		# Host toggles locally to update immediately
		_toggle_ready_state(id)
	else:
		rpc_id(1, "_toggle_ready_state", id)

@rpc("call_local")
func _update_player_list(new_list):
	players = new_list
	player_list_changed.emit(players)

@rpc("any_peer")
func _toggle_ready_state(id):
	if multiplayer.is_server():
		if players.has(id):
			players[id].ready = not players[id].ready
			# Notify all clients and the host
			for peer_id in multiplayer.get_peers():
				rpc_id(peer_id, "_update_player_list", players)
			player_list_changed.emit(players)

func start_game():
	rpc("start_game_rpc")

@rpc("call_local")
func start_game_rpc():
	game_started.emit()

func find_lobbies():
	lobbies_list_changed.emit({})
	# Rebind cleanly in case it's already open
	udp_socket.close()
	udp_socket = PacketPeerUDP.new()
	if udp_socket.bind(BROADCAST_PORT) != OK:
		print("Error binding UDP socket for lobby discovery")
		return
	else:
		print("[Lobby] Listening on UDP port ", BROADCAST_PORT)
	set_process(true)

func _process(delta):
	if multiplayer.is_server():
		var data = {
			"host_name": "Host",
			"player_count": players.size(),
			"max_players": MAX_CLIENTS + 1
		}
		udp_socket.set_broadcast_enabled(true)
		udp_socket.set_dest_address("255.255.255.255", BROADCAST_PORT)
		var payload = JSON.stringify(data).to_utf8_buffer()
		var send_err = udp_socket.put_packet(payload)
		if send_err == OK:
			# Print occasionally to avoid spamming
			if (Time.get_ticks_msec() % 1000) < 16:
				print("[Lobby] Broadcast sent: ", data)
		else:
			print("[Lobby] Broadcast send failed: ", send_err)
	else:
		if udp_socket.get_available_packet_count() > 0:
			var packet = udp_socket.get_packet()
			# Godot 4 uses get_packet_address()
			var ip = udp_socket.get_packet_address()
			var data = JSON.parse_string(packet.get_string_from_utf8())
			if data:
				# Emit incremental updates; UI will accumulate
				var single := {}
				single[ip] = data
				print("[Lobby] Discovered host at ", ip, ": ", data)
				lobbies_list_changed.emit(single)
