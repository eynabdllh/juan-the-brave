extends Node2D

@onready var player = $player
@onready var tilemap = $TileMap
@onready var status_hud = get_tree().root.get_node_or_null("StatusHUD")
@onready var cutscene_layer = $CutsceneLayer
@onready var cutscene_player = $CutsceneLayer/CutscenePlayer

func _ready():
	# Position the player based on where they came from
	if global.next_player_position != Vector2.ZERO:
		player.position = global.next_player_position
		global.next_player_position = Vector2.ZERO
	else:
		player.position = Vector2(227, 298)

	# --- Start the cutscene ---
	
	# 1. Hide the game world and player
	player.hide()
	tilemap.hide()
	
	# 2. Hide the HUD so it's not visible during the video
	if is_instance_valid(status_hud):
		status_hud.hide()
	
	# 3. Show the cutscene layer and play the video
	cutscene_layer.show()
	cutscene_player.play()


# This function is called when the video finishes playing (because you connected the signal)
func _on_cutscene_player_finished():
	print("Ending cutscene finished. Returning to main menu.")
	
	# Show the HUD again before going to the menu, so it's not hidden next time
	if is_instance_valid(status_hud):
		status_hud.show()
		
	# Reset the game state and go back to the main menu
	global.go_to_main_menu()
