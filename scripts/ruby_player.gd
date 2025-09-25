extends "res://scripts/player.gd"

# Ruby Player - extends base player functionality with unique characteristics
# Inherits all base functionality from player.gd and adds Ruby-specific features

# Ruby-specific properties
@export var ruby_speed_multiplier: float = 1.2  # Ruby is slightly faster
@export var ruby_attack_damage: int = 25        # Ruby does more damage
@export var ruby_health_bonus: int = 20         # Ruby has more health

# Ruby-specific abilities
var has_dash_ability: bool = true
var dash_cooldown: float = 2.0
var dash_distance: float = 100.0
var is_dashing: bool = false
var dash_timer: float = 0.0

func _ready():
	# Call parent _ready first to set up base functionality
	super._ready()
	
	# Apply Ruby-specific modifications
	speed = speed * ruby_speed_multiplier
	health = health + ruby_health_bonus
	
	# Ruby starts with different animation
	$AnimatedSprite2D.play("front_idle")
	
	# Set a clear character name label for the Ruby client variant
	var name_label := get_node_or_null("player_name_label")
	if name_label and name_label is Label:
		(name_label as Label).text = "Player 2"
		(name_label as Label).visible = true
	
	print("Ruby player initialized - Speed: ", speed, " Health: ", health)

func _physics_process(delta):
	# Handle dash cooldown
	if dash_timer > 0:
		dash_timer -= delta
	
	# Call parent physics process
	super._physics_process(delta)

func handle_input():
	# Handle Ruby's special dash ability (using shift key as dash for now)
	if Input.is_action_just_pressed("ui_accept") and has_dash_ability and dash_timer <= 0 and not is_dashing:
		perform_dash()
	
	# Call parent input handling
	super.handle_input()

func perform_dash():
	"""Ruby's special dash ability"""
	if is_knocked_back or attack_ip:
		return
	
	is_dashing = true
	dash_timer = dash_cooldown
	
	# Determine dash direction based on current movement or facing direction
	var dash_direction = Vector2.ZERO
	
	if velocity.length() > 0:
		dash_direction = velocity.normalized()
	else:
		# Dash in facing direction if not moving
		match current_dir:
			"front":
				dash_direction = Vector2.DOWN
			"back":
				dash_direction = Vector2.UP
			"side":
				dash_direction = Vector2.RIGHT if not $AnimatedSprite2D.flip_h else Vector2.LEFT
			_:
				dash_direction = Vector2.DOWN
	
	# Apply dash velocity
	velocity = dash_direction * dash_distance * 10  # High velocity for quick dash
	
	# Visual effect for dash
	$AnimatedSprite2D.modulate = Color(1, 1, 1, 0.7)  # Semi-transparent during dash
	
	# Create dash timer to end dash effect
	var dash_effect_timer = Timer.new()
	add_child(dash_effect_timer)
	dash_effect_timer.wait_time = 0.2
	dash_effect_timer.one_shot = true
	dash_effect_timer.timeout.connect(_on_dash_effect_end)
	dash_effect_timer.start()
	
	print("Ruby dashes!")

func _on_dash_effect_end():
	is_dashing = false
	$AnimatedSprite2D.modulate = Color.WHITE
	
	# Remove the temporary timer
	for child in get_children():
		if child is Timer and child.name.begins_with("@Timer"):
			child.queue_free()

func attack():
	"""Override attack to do more damage"""
	attack_ip = true
	
	if current_dir == "side":
		$AnimatedSprite2D.play("side_attack")
	elif current_dir == "front":
		$AnimatedSprite2D.play("front_attack")
	else: 
		$AnimatedSprite2D.play("back_attack")
	
	$deal_attack_timer.start()

func _on_deal_attack_timer_timeout():
	"""Override to apply Ruby's higher damage"""
	for body in $player_hitbox.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			body.take_damage(ruby_attack_damage, self)  # Use Ruby's damage value
	
	await $AnimatedSprite2D.animation_finished
	attack_ip = false

func take_damage(amount, attacker):
	"""Ruby has slightly different damage handling"""
	if is_knocked_back or is_dashing: 
		return  # Ruby is immune to damage while dashing
	
	# Call parent damage handling
	super.take_damage(amount, attacker)
	
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
		"special_ability": "Dash"
	}
