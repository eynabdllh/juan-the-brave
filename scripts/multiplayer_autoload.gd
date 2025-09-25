extends Node

# Multiplayer autoload to preserve connection data across scene changes
var is_server: bool = false
var connected_peers: PackedInt32Array = []
var local_peer_id: int = 0
var host_ip: String = ""
var port: int = 7000

func _ready():
	print("Multiplayer autoload ready")

# Store multiplayer state before scene change
func preserve_multiplayer_state():
	if multiplayer.has_multiplayer_peer():
		is_server = multiplayer.is_server()
		connected_peers = multiplayer.get_peers()
		local_peer_id = multiplayer.get_unique_id()
		print("Preserving multiplayer state - Server: ", is_server, " Local ID: ", local_peer_id, " Peers: ", connected_peers)
		return true
	return false

# Get preserved multiplayer state
func get_multiplayer_state():
	return {
		"is_server": is_server,
		"connected_peers": connected_peers,
		"local_peer_id": local_peer_id,
		"host_ip": host_ip,
		"port": port
	}

# Set multiplayer connection info
func set_connection_info(server: bool, ip: String = "", p: int = 7000):
	is_server = server
	host_ip = ip
	port = p

# Clean up multiplayer state
func cleanup_multiplayer():
	is_server = false
	connected_peers = PackedInt32Array()
	local_peer_id = 0
	host_ip = ""
	port = 7000
