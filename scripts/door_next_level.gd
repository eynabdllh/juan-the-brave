extends Area2D

@onready var visual_rect: ColorRect = $ColorRect

func _ready():
	# Check the global state when the door is created.
	if global.player_has_key:
		unlock()
	else:
		lock()

func _on_body_entered(body: Node2D) -> void:
	# Only transition if it's the player AND the door is unlocked.
	if body.is_in_group("player") and global.player_has_key:
		print("Entering next level!")
		# Here you would transition to the next level, e.g., the Cemetery
		# get_tree().change_scene_to_file("res://scenes/cemetery.tscn")
		pass # Placeholder for now

func lock():
	visual_rect.color = Color.RED
	print("Door is LOCKED.")

func unlock():
	visual_rect.color = Color.GREEN
	print("Door is UNLOCKED.")
