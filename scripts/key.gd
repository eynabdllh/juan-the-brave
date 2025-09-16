extends Area2D

# This signal tells the world that we have been collected.
signal collected

func _on_body_entered(body: Node2D):
	# This check will now work because the Collision Masks are correct.
	if body.is_in_group("player"):
		emit_signal("collected")
		# You can play a key pickup sound here
		queue_free() # The key disappears.
