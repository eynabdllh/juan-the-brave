extends CharacterBody2D

# --- THE CRITICAL FIX: The signal MUST declare what data it will send ---
signal died(enemy_position)

@export var speed = 55 # medium tier: a bit faster than mantis
@export var attack_damage = 12 # medium tier damage
@export var attack_rate = 1.2 # attacks slightly more often
@export var knockback_speed = 140.0

var player = null
var health = 70
var can_be_damaged = true
var can_attack = true
var is_attacking = false
var is_knocked_back = false
var is_alive = true
var last_walk_animation = "front_walk"

# This function is called by Godot when the node enters the scene tree.
func _ready():
	# --- NEW: Check if this enemy was already killed ---
	if global.killed_enemies.has(self.name):
		# If our name is in the global list of dead enemies, remove ourself instantly.
		queue_free()
		return # Stop further processing for this dead enemy

	$AnimatedSprite2D.play(last_walk_animation)
	$AnimatedSprite2D.stop()
	# Make the healthbar look full even if HP is less than 100
	if has_node("healthbar"):
		$healthbar.max_value = health
		$healthbar.value = health

func _physics_process(delta):
	# (The rest of the script is now correct, no changes needed in the main loop)
	if not is_alive or is_attacking or is_knocked_back:
		move_and_slide()
		return
	var target_in_hitbox = find_player_in_hitbox()
	if target_in_hitbox: player = target_in_hitbox
	if player != null and target_in_hitbox and can_attack:
		attack_player()
	elif player != null:
		chase_player()
	else:
		idle()
	update_health()
	move_and_slide()

# --- THE CRITICAL FIX: The die() function MUST send the position data ---
func die():
	if not is_alive: return
	is_alive = false
	velocity = Vector2.ZERO	
	$CollisionShape2D.set_deferred("disabled", true)
	
	# --- NEW: Add our unique name to the global list of killed enemies ---
	global.add_killed_enemy(self.name)
	
	# Emit the signal, sending our global position with it.
	emit_signal("died", global_position)
	
	# Ensure healthbar is visually empty before death animation
	update_health() # force value to update to 0
	await get_tree().process_frame
	
	$AnimatedSprite2D.play("death")
	await $AnimatedSprite2D.animation_finished
	queue_free()

# (All other functions are correct, no changes needed)
func find_player_in_hitbox() -> CharacterBody2D:
	for body in $enemy_hitbox.get_overlapping_bodies():
		if body.is_in_group("player"): return body
	return null
func attack_player():
	velocity = Vector2.ZERO
	is_attacking = true
	can_attack = false
	if "side" in last_walk_animation:
		$AnimatedSprite2D.play("side_attack")
		$AnimatedSprite2D.flip_h = player and player.position.x < position.x
	elif "back" in last_walk_animation:
		$AnimatedSprite2D.play("back_attack")
	else:
		$AnimatedSprite2D.play("front_attack")
	player.take_damage(attack_damage, self)
func take_damage(amount, attacker):
	if not can_be_damaged or not is_alive: return
	can_be_damaged = false; health -= amount; print("Enemy health: ", health)
	is_knocked_back = true
	var knockback_direction = (global_position - attacker.global_position).normalized()
	velocity = knockback_direction * knockback_speed
	$KnockbackTimer.start(0.15)
	var tween = create_tween(); $AnimatedSprite2D.modulate = Color.RED
	tween.tween_property($AnimatedSprite2D, "modulate", Color.WHITE, 0.4)
	if $HurtSound: $HurtSound.play()
	$take_damage_cooldown.start()
	if health <= 0: die()
func chase_player():
	var direction = (player.position - position).normalized()
	velocity = direction * speed
	if abs(direction.x) > abs(direction.y):
		last_walk_animation = "side_walk"
		$AnimatedSprite2D.flip_h = direction.x < 0
	else:
		last_walk_animation = "front_walk" if direction.y > 0 else "back_walk"
	$AnimatedSprite2D.play(last_walk_animation)
func idle():
	velocity = Vector2.ZERO
	# Ensure a visible idle frame is shown; prefer direction-specific idles if available
	var anim := $AnimatedSprite2D
	if anim:
		if "side" in last_walk_animation:
			anim.play("side_idle")
			anim.stop()
		elif "back" in last_walk_animation:
			anim.play("back_idle")
			anim.stop()
		else:
			anim.play("front_idle")
			anim.stop()
func _on_animated_sprite_2d_animation_finished():
	if "attack" in $AnimatedSprite2D.animation: is_attacking = false; $EnemyAttackTimer.start(attack_rate)
func _on_detection_area_body_entered(body: Node2D):
	if body.is_in_group("player"): player = body
func _on_detection_area_body_exited(body: Node2D):
	if body == player: player = null
func _on_knockback_timer_timeout():
	is_knocked_back = false; velocity = Vector2.ZERO
func _on_take_damage_cooldown_timeout(): can_be_damaged = true
func _on_enemy_attack_timer_timeout(): can_attack = true
func update_health(): $healthbar.value = health; $healthbar.visible = health < 100
func enemylevel_1(): pass
