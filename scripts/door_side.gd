extends Node2D

@onready var player = $player

func _ready():
    # Set the current scene for the camera system
    global.current_scene = "door_side"
    $player.position = Vector2(142, 294)

    setup_camera_limits()

func setup_camera_limits():
    var camera = player.get_node_or_null("doorside_camera") 
    
    if camera:       
        camera.limit_left = 0
        camera.limit_top = 0
        camera.limit_right = 284 
        camera.limit_bottom = 303
        camera.limit_smoothed = true 
        
        camera.make_current()
        
func _on_door_exit_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        # Set the player's spawn point for the *next* scene (map_3)
        # This should be a position near the door in map_3
        global.next_player_position = Vector2(209, 20)
        global.go_to_world()
