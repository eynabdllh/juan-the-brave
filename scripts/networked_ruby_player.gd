extends "res://scripts/networked_player.gd"

# Networked Ruby Player - extends networked player with Ruby-specific features
# Combines networking capabilities with Ruby's unique characteristics

# Ruby-specific properties (synchronized across network)
@export var ruby_speed_multiplier: float = 1.2
@export var ruby_attack_damage: int = 25
@export var ruby_health_bonus: int = 20
@export var sync_is_dashing: bool = false

# Ruby-specific abilities
var has_dash_ability: bool = true
var dash_cooldown: float = 2.0
var dash_distance: float = 100.0
var is_dashing: bool = false
var dash_timer: float = 0.0

func _ready():
	# Call parent _ready first
	super._ready()
	
	# Apply Ruby-specific modifications
	speed = speed * ruby_speed_multiplier
	health = health + ruby_health_bonus
	
	print("Networked Ruby player ready - ID: ", player_id, " Local: ", is_local_player)

func _physics_process(delta: float):
	# Handle dash cooldown
	if dash_timer > 0:
		dash_timer -= delta
	
	# Call parent physics process
	super._physics_process(delta)

func handle_input():
	# Handle Ruby's special dash ability (Space key for dash)
	if Input.is_action_just_pressed("ui_accept") and has_dash_ability and dash_timer <= 0 and not is_dashing:
		perform_dash()
	
	# Call parent input handling
	super.handle_input()

func perform_dash():
	"""Ruby's special dash ability - networked version"""
	if is_knocked_back or attack_ip or not is_local_player:
		return
	
	# Call RPC to synchronize dash across all clients
	rpc("_perform_dash_rpc", current_dir, global_position)

@rpc("any_peer", "call_local", "reliable")
func _perform_dash_rpc(dash_direction: String, start_position: Vector2):
	"""RPC function to synchronize dash across all clients"""
	is_dashing = true
	sync_is_dashing = true
	dash_timer = dash_cooldown
	
	# Determine dash direction
	var dash_vector = Vector2.ZERO
	
	if velocity.length() > 0:
		dash_vector = velocity.normalized()
	else:
		# Dash in facing direction if not moving
		match dash_direction:
			"front":
				dash_vector = Vector2.DOWN
			"back":
				dash_vector = Vector2.UP
			"side":
				dash_vector = Vector2.RIGHT if not $AnimatedSprite2D.flip_h else Vector2.LEFT
			_:
				dash_vector = Vector2.DOWN
	
	# Apply dash velocity
	velocity = dash_vector * dash_distance * 10
	
	# Visual effect for dash
	$AnimatedSprite2D.modulate = Color(1, 1, 1, 0.7)
	
	# Create dash timer to end dash effect
	var dash_effect_timer = Timer.new()
	add_child(dash_effect_timer)
	dash_effect_timer.wait_time = 0.2
	dash_effect_timer.one_shot = true
	dash_effect_timer.timeout.connect(_on_dash_effect_end)
	dash_effect_timer.start()
	
	print("Ruby dashes! (Player: ", player_id, ")")

func _on_dash_effect_end():
	is_dashing = false
	sync_is_dashing = false
	$AnimatedSprite2D.modulate = Color.WHITE
	
	# Remove the temporary timer
	for child in get_children():
		if child is Timer and child.name.begins_with("@Timer"):
			child.queue_free()

func _update_sync_properties():
	"""Override to include Ruby-specific sync properties"""
	super._update_sync_properties()
	sync_is_dashing = is_dashing

func _apply_sync_properties():
	"""Override to apply Ruby-specific sync properties"""
	super._apply_sync_properties()
	
	# Apply dash state for remote players
	if sync_is_dashing != is_dashing:
		is_dashing = sync_is_dashing
		if is_dashing:
			$AnimatedSprite2D.modulate = Color(1, 1, 1, 0.7)
		else:
			$AnimatedSprite2D.modulate = Color.WHITE

@rpc("any_peer", "call_local", "reliable")
func _perform_attack(attack_direction: String):
	"""Override attack to show Ruby-specific animations and damage"""
	if attack_direction == "side":
		$AnimatedSprite2D.play("side_attack")
	elif attack_direction == "front":
		$AnimatedSprite2D.play("front_attack")
	else: 
		$AnimatedSprite2D.play("back_attack")
	
	$deal_attack_timer.start()

func _on_deal_attack_timer_timeout():
	"""Override to apply Ruby's higher damage"""
	# Only local player processes damage dealing
	if is_local_player:
		for body in $player_hitbox.get_overlapping_bodies():
			if body != self and body.has_method("take_damage"):
				# Use RPC to apply damage across network
				if body.has_method("rpc"):
					body.rpc("take_damage", ruby_attack_damage, player_id)
				else:
					body.take_damage(ruby_attack_damage, self)
	
	await $AnimatedSprite2D.animation_finished
	attack_ip = false

@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int, attacker_id: int):
	"""Ruby has damage immunity while dashing"""
	if is_knocked_back or is_dashing: 
		return  # Ruby is immune to damage while dashing
	
	# Call parent damage handling
	super.take_damage(amount, attacker_id)
	
	# Ruby-specific damage effect (different color)
	$AnimatedSprite2D.modulate = Color(1, 0.5, 0.5)  # Reddish tint for Ruby

func get_character_name() -> String:
	"""Return character name for identification"""
	return "Ruby"

func get_character_stats() -> Dictionary:
	"""Return character stats for UI display"""
	return {
		"name": "Ruby",
		"speed": speed,
		"health": health,
		"attack_damage": ruby_attack_damage,
		"special_ability": "Dash (Space key)"
	}
