# door_next_level.gd (Final Interactive Version)
extends StaticBody2D

@onready var door_sprite: AnimatedSprite2D = $DoorSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_locked = true
var player_is_nearby = false # NEW: Tracks if the player is in range

func _ready():
	# The door always starts locked. We no longer check for the key here.
	lock()

func _process(delta):
	# Every frame, check if the player is nearby AND presses the interact key.
	if player_is_nearby and Input.is_action_just_pressed("interact"):
		# If they have the key, unlock the door.
		if global.player_has_key and is_locked:
			unlock()
		# If the door is already unlocked, transition to the next scene.
		elif not is_locked:
			go_to_next_level()

# This signal is from the child InteractionArea.
func _on_interaction_area_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_is_nearby = true
		# You can add a prompt here, like a "!" above the player's head.

# This signal is also from the child InteractionArea.
func _on_interaction_area_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_is_nearby = false
		# Hide the prompt here if you added one.

func go_to_next_level():
	print("Entering next level!")
	# get_tree().change_scene_to_file("res://scenes/cemetery.tscn")
	pass

func lock():
	is_locked = true
	door_sprite.play("locked")
	collision_shape.disabled = false
	print("Door is LOCKED.")

func unlock():
	is_locked = false
	door_sprite.play("opening")
	await door_sprite.animation_finished
	door_sprite.play("unlocked")
	
	collision_shape.disabled = true
	print("Door is UNLOCKED.")
