extends Node2D

@onready var player = $player

func _ready():
    # Set the current scene for the camera system
    global.current_scene = "door_side_1"
    
    # Position the player where the previous door dictated
    if global.next_player_position != Vector2.ZERO:
        $player.position = global.next_player_position
        global.next_player_position = Vector2.ZERO # Reset after use
    else:
        # Fallback for testing
        $player.position = Vector2(160, 315)

    setup_camera_limits()

func setup_camera_limits():
    var camera = player.get_node_or_null("doorside1_camera") 
    
    if camera:       
        camera.limit_left = 0
        camera.limit_top = 0
        camera.limit_right = 403  
        camera.limit_bottom = 318
        camera.limit_smoothed = true 
        
        camera.make_current()
        
func _on_door_exit_1_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        # Set the player's spawn point for map_2
        global.next_player_position = Vector2(23, 1237) # The entrance position in map_2
        global.go_to_map_2()
