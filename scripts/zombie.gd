extends "res://scripts/base_enemy.gd"

# Slow, tanky zombie: 3–4 player hits to kill (player base dmg = 20)
@export var _z_speed: float = 35.0
@export var _z_damage: int = 10
@export var _z_rate: float = 1.3
@export var _z_health: int = 70
@export var _z_knockback: float = 120.0

func _ready() -> void:
	# Apply zombie-specific stats to base fields before base _ready runs visuals
	speed = _z_speed
	attack_damage = _z_damage
	attack_rate = _z_rate
	max_health = _z_health
	knockback_speed = _z_knockback
	super._ready()

# Override chase to use distinct left/right animations (no flip)
func _chase_player() -> void:
	var direction := (player.position - position).normalized()
	velocity = direction * speed
	var anim := $AnimatedSprite2D
	if abs(direction.x) > abs(direction.y):
		last_walk_animation = "right_walk" if direction.x > 0 else "left_walk"
		anim.flip_h = false
	else:
		last_walk_animation = "front_walk" if direction.y > 0 else "back_walk"
	anim.play(last_walk_animation)

# Map attack animations from last_walk_animation
func _attack_player() -> void:
	velocity = Vector2.ZERO
	is_attacking = true
	can_attack = false
	var anim := $AnimatedSprite2D
	var attack_name := "front_attack"
	if "right" in last_walk_animation:
		attack_name = "right_attack"
	elif "left" in last_walk_animation:
		attack_name = "left_attack"
	elif "back" in last_walk_animation:
		attack_name = "back_attack"
	anim.play(attack_name)
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage, self)

# Directional idles
func _play_idle() -> void:
	var anim := $AnimatedSprite2D
	if is_instance_valid(anim):
		var idle_name := "front_idle"
		if "right" in last_walk_animation:
			idle_name = "right_idle"
		elif "left" in last_walk_animation:
			idle_name = "left_idle"
		elif "back" in last_walk_animation:
			idle_name = "back_idle"
		anim.play(idle_name)
		anim.stop()

# Play a matching directional death if available
func die() -> void:
	if not is_alive:
		return
	is_alive = false
	velocity = Vector2.ZERO
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("/root/global") and global.has_method("add_killed_enemy"):
		global.add_killed_enemy(self.name)
	emit_signal("died", global_position)
	_update_health()
	await get_tree().process_frame
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	if is_instance_valid(anim):
		var frames := anim.sprite_frames
		var candidates: Array[StringName] = []
		if "right" in last_walk_animation:
			candidates.append(&"right_death")
		elif "left" in last_walk_animation:
			candidates.append(&"left_death")
		elif "back" in last_walk_animation:
			candidates.append(&"back_death")
			candidates.append(&"right_death")
			candidates.append(&"left_death")
		elif "front" in last_walk_animation:
			candidates.append(&"front_death")
			candidates.append(&"right_death")
			candidates.append(&"left_death")
		candidates.append(&"death")
		for name in candidates:
			if frames and frames.has_animation(name):
				anim.play(name)
				await anim.animation_finished
				break
	queue_free()
