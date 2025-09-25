extends Node2D

# Character Test Scene
# Demonstrates both Juan and Ruby characters

var juan_scene = preload("res://scenes/player.tscn")
var ruby_scene = preload("res://scenes/ruby_player.tscn")

func _ready():
	# Spawn Juan on the left
	var juan = juan_scene.instantiate()
	juan.position = Vector2(200, 300)
	juan.name = "Juan"
	add_child(juan)
	
	# Spawn Ruby on the right
	var ruby = ruby_scene.instantiate()
	ruby.position = Vector2(400, 300)
	ruby.name = "Ruby"
	add_child(ruby)
	
	# Add instructions
	var label = Label.new()
	label.text = "Character Test Scene\n\nJuan (Left): Standard player\nRuby (Right): Enhanced player with dash ability\n\nControls:\n- Arrow keys: Move\n- Space: Attack (Juan) / Dash (Ruby)\n- Enter: Attack (Ruby)"
	label.position = Vector2(50, 50)
	label.size = Vector2(500, 200)
	add_child(label)
	
	print("Character test scene loaded!")
	print("Juan stats: ", juan.get("speed", "N/A"), " speed, ", juan.get("health", "N/A"), " health")
	if ruby.has_method("get_character_stats"):
		print("Ruby stats: ", ruby.get_character_stats())
