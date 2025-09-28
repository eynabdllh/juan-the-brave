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
    
    setup_camera_limits()

func setup_camera_limits():
    var camera = player.get_node_or_null("house_camera") 
    
    if camera:       
        camera.limit_left = 0
        camera.limit_top = 0
        camera.limit_right = 400  
        camera.limit_bottom = 304 
        camera.limit_smoothed = true 
        
        camera.make_current()
