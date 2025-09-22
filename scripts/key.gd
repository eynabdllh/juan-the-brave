# key.gd (Definitive, Working Version)
extends Area2D

# --- THE CRITICAL FIX IS HERE ---
# We must declare the signal at the top of the script so other scripts know it exists.
signal collected

@export var interact_radius: float = 55.0
@onready var interact_prompt: Label = $InteractPrompt
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var player_in_range: CharacterBody2D = null
var drop_anim_done := false

func _ready():
	# Apply configurable interaction radius
	if is_instance_valid(collision_shape) and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = interact_radius
	interact_prompt.hide()
	# Play a bounce-in drop animation, then enable pickup and prompts
	await _play_drop_animation()
	# Auto-show prompt if the player is already overlapping when the key finishes dropping
	await get_tree().process_frame # ensure physics overlap lists are valid after enabling collisions
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			player_in_range = body
			player_in_range.show_interact_prompt()
			interact_prompt.show()
			break

func _unhandled_input(event):
	if player_in_range and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		collect_key()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = body
		# The key tells the player to show its generic "!" prompt
		if drop_anim_done:
			player_in_range.show_interact_prompt()
			# The key also shows its own specific text prompt
			interact_prompt.show()

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		if player_in_range:
			player_in_range.hide_interact_prompt()
		player_in_range = null
		interact_prompt.hide()

func collect_key():
	# Now that the signal is declared, this line will work correctly.
	emit_signal("collected")
	
	# Tell the global script we've got the key
	global.collect_key()
	
	# The key disappears
	queue_free()

# Plays a short bounce-in animation and enables collision after it finishes
func _play_drop_animation() -> void:
	drop_anim_done = false
	var original_scale := scale
	# Prevent interaction during the drop
	if is_instance_valid(collision_shape):
		collision_shape.disabled = true
	# Start tiny and grow with a bounce
	scale = Vector2.ZERO
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", original_scale * 1.1, 0.35)
	tw.tween_property(self, "scale", original_scale, 0.15)
	await tw.finished
	if is_instance_valid(collision_shape):
		collision_shape.disabled = false
	drop_anim_done = true
