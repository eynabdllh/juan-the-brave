extends Node

# Multiplayer Test Script
# This script can be attached to any node to test multiplayer functionality
# Useful for debugging and validation

var test_results: Array[String] = []

func _ready():
	print("=== Multiplayer System Test ===")
	run_tests()

func run_tests():
	test_results.clear()
	
	# Test 1: Check if ENetMultiplayerPeer is available
	test_enet_availability()
	
	# Test 2: Test peer creation
	test_peer_creation()
	
	# Test 3: Check multiplayer signals
	test_multiplayer_signals()
	
	# Test 4: Validate scene structure (if in multiplayer scene)
	test_scene_structure()
	
	# Print results
	print_test_results()

func test_enet_availability():
	var peer = ENetMultiplayerPeer.new()
	if peer:
		test_results.append("✓ ENetMultiplayerPeer available")
		peer.queue_free()
	else:
		test_results.append("✗ ENetMultiplayerPeer not available")

func test_peer_creation():
	var peer = ENetMultiplayerPeer.new()
	
	# Test server creation
	var server_result = peer.create_server(7001, 2)  # Use different port for testing
	if server_result == OK:
		test_results.append("✓ Server creation successful")
		peer.close()
	else:
		test_results.append("✗ Server creation failed: " + str(server_result))
	
	# Test client creation
	var client_result = peer.create_client("127.0.0.1", 7001)
	if client_result == OK:
		test_results.append("✓ Client creation successful")
	else:
		test_results.append("✗ Client creation failed: " + str(client_result))
	
	peer.queue_free()

func test_multiplayer_signals():
	var signals_to_check = [
		"peer_connected",
		"peer_disconnected", 
		"connection_failed",
		"server_disconnected"
	]
	
	var missing_signals = []
	for signal_name in signals_to_check:
		if not multiplayer.has_signal(signal_name):
			missing_signals.append(signal_name)
	
	if missing_signals.is_empty():
		test_results.append("✓ All required multiplayer signals available")
	else:
		test_results.append("✗ Missing signals: " + str(missing_signals))

func test_scene_structure():
	var root = get_tree().current_scene
	
	# Check if we're in a multiplayer scene
	if root.has_method("_start_server"):
		test_results.append("✓ Multiplayer manager detected")
		
		# Check for required UI elements
		var ui_elements = ["UI/StatusLabel", "UI/HostButton", "UI/JoinButton", "UI/IPInput"]
		var missing_ui = []
		
		for element_path in ui_elements:
			if not root.has_node(element_path):
				missing_ui.append(element_path)
		
		if missing_ui.is_empty():
			test_results.append("✓ All UI elements found")
		else:
			test_results.append("✗ Missing UI elements: " + str(missing_ui))
		
		# Check for MultiplayerSpawner
		if root.has_node("MultiplayerSpawner"):
			test_results.append("✓ MultiplayerSpawner found")
		else:
			test_results.append("✗ MultiplayerSpawner missing")
			
	else:
		test_results.append("ℹ Not in multiplayer scene - skipping structure test")

func print_test_results():
	print("\n=== Test Results ===")
	for result in test_results:
		print(result)
	
	var passed = 0
	var failed = 0
	var info = 0
	
	for result in test_results:
		if result.begins_with("✓"):
			passed += 1
		elif result.begins_with("✗"):
			failed += 1
		else:
			info += 1
	
	print("\nSummary: %d passed, %d failed, %d info" % [passed, failed, info])
	
	if failed == 0:
		print("🎉 All tests passed! Multiplayer system ready.")
	else:
		print("⚠️  Some tests failed. Check setup instructions.")

# Manual test functions that can be called from console or other scripts
func test_local_connection():
	print("Testing local connection...")
	
	# This would be called from a multiplayer scene
	var root = get_tree().current_scene
	if root.has_method("_start_server"):
		print("Starting server...")
		root._start_server()
		
		# Wait a moment then try to connect
		await get_tree().create_timer(1.0).timeout
		print("Attempting client connection...")
		root._connect_to_server("127.0.0.1")
	else:
		print("Not in multiplayer scene - cannot test connection")

func get_network_info():
	print("=== Network Information ===")
	print("Local IP addresses:")
	var addresses = IP.get_local_addresses()
	for i in range(addresses.size()):
		print("  %d: %s" % [i, addresses[i]])
	
	print("Multiplayer peer: ", multiplayer.multiplayer_peer)
	if multiplayer.multiplayer_peer:
		print("Unique ID: ", multiplayer.get_unique_id())
		print("Connected peers: ", multiplayer.get_peers())
	else:
		print("No multiplayer peer set")
