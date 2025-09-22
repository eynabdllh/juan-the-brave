# key.gd (Definitive, Working Version)
extends Area2D

# --- THE CRITICAL FIX IS HERE ---
# We must declare the signal at the top of the script so other scripts know it exists.
signal collected

@onready var interact_prompt: Label = $InteractPrompt
var player_in_range: CharacterBody2D = null

func _ready():
	interact_prompt.hide()

func _unhandled_input(event):
	if player_in_range and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		collect_key()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = body
		# The key tells the player to show its generic "!" prompt
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
