extends StaticBody2D

@export var locked_message = "It's locked. I need to find a key."
@export var unlocked_message = "The door is now open, finally."

@onready var door_sprite: AnimatedSprite2D = $DoorSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_locked = true
var player_in_range: CharacterBody2D = null

func _ready():
	lock()

func _unhandled_input(event):
	if player_in_range and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if global.player_has_key and is_locked:
			unlock()
		elif is_locked:
			player_in_range.show_monologue(locked_message)
		elif not is_locked:
			go_to_next_level()

func _on_interaction_area_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = body
		player_in_range.show_interact_prompt()

func _on_interaction_area_body_exited(body: Node2D):
	if body.is_in_group("player"):
		if player_in_range:
			player_in_range.hide_interact_prompt()
		player_in_range = null

func go_to_next_level():
	print("Entering next level: map_2!")
	global.go_to_map_2()

func lock():
	is_locked = true
	door_sprite.play("locked")
	collision_shape.disabled = false

func unlock():
	is_locked = false
	if player_in_range:
		player_in_range.hide_interact_prompt()
		player_in_range.show_monologue(unlocked_message)
	door_sprite.play("opening")
	await door_sprite.animation_finished
	door_sprite.play("unlocked")
	collision_shape.disabled = true	
	go_to_next_level()
