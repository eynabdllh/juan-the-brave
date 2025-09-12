extends CharacterBody2D

# Using @export allows you to change the speed in the Godot Editor Inspector
@export var speed = 40

var player_chase = false
var player = null
# This variable will remember the last direction the enemy was moving
var last_animation = "front_walk"

func _physics_process(delta):
	if player_chase and player != null:
		# --- CHASE LOGIC ---
		var direction = (player.position - position).normalized()
		velocity = direction * speed
		
		# Determine which walk animation to play based on direction
		if abs(direction.x) > abs(direction.y):
			last_animation = "right_walk" if direction.x > 0 else "left_walk"
		else:
			last_animation = "front_walk" if direction.y > 0 else "back_walk"
		
		$AnimatedSprite2D.play(last_animation)

	else:
		# --- IDLE LOGIC ---
		velocity = Vector2.ZERO # Stop moving
		$AnimatedSprite2D.stop() # Stop the animation, freezing it on the current frame

	# move_and_slide() handles the character's movement and collisions
	move_and_slide()

func _on_detection_area_body_entered(body: Node2D) -> void:
	# It's good practice to check if the detected body is the player.
	# For this to work, select your player node and add it to a group named "player".
	if body.is_in_group("player"):
		player = body
		player_chase = true

func _on_detection_area_body_exited(body: Node2D) -> void:
	# Check if the body that exited is the same one we were chasing
	if body == player:
		player = null
		player_chase = false
		
		# Optional but highly recommended:
		# When the player leaves, set a proper standing frame.
		# This avoids having the enemy stop awkwardly mid-stride.
		$AnimatedSprite2D.play(last_animation) # Select the last animation
		$AnimatedSprite2D.set_frame(0)         # Go to its first frame
		$AnimatedSprite2D.stop()               # and stop it.
