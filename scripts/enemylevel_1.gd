extends CharacterBody2D

@export var speed = 40
@export var attack_damage = 10
@export var attack_rate = 1.5
@export var knockback_speed = 250.0 # --- NEW ---

var player = null
var health = 100
var can_be_damaged = true
var can_attack = true
var is_attacking = false
var is_knocked_back = false # --- NEW ---

func _physics_process(delta):
	# If attacking or knocked back, pause all other logic
	if is_attacking or is_knocked_back:
		move_and_slide() # Still need to apply knockback velocity
		return

	var target_in_hitbox = find_player_in_hitbox()

	# --- THE DEFINITIVE TARGETING FIX ---
	# If we see a player in our attack box, they are now our main target.
	if target_in_hitbox:
		player = target_in_hitbox

	# Logic: Attack if possible, otherwise chase if a target is known, otherwise idle.
	if target_in_hitbox and can_attack:
		attack_player()
	elif player != null:
		chase_player()
	else:
		idle()
	
	update_health()
	move_and_slide()

func find_player_in_hitbox() -> CharacterBody2D:
	for body in $enemy_hitbox.get_overlapping_bodies():
		if body.is_in_group("player"):
			return body
	return null

func attack_player():
	velocity = Vector2.ZERO; is_attacking = true; can_attack = false
	var direction = (player.global_position - global_position).normalized()
	if abs(direction.x) > abs(direction.y):
		$AnimatedSprite2D.play("right_attack" if direction.x > 0 else "left_attack")
	else:
		$AnimatedSprite2D.play("front_attack" if direction.y > 0 else "back_attack")
	player.take_damage(attack_damage, self)

# --- RENAMED & REPLACED deal_with_damage() ---
func take_damage(amount, attacker):
	if not can_be_damaged: return
	
	can_be_damaged = false
	health -= amount
	print("Enemy health: ", health)
	
	# --- NEW HURT EFFECTS ---
	is_knocked_back = true
	var knockback_direction = (global_position - attacker.global_position).normalized()
	velocity = knockback_direction * knockback_speed
	$KnockbackTimer.start(0.15)
	
	$HurtSound.play()
	$AnimatedSprite2D.modulate = Color.RED
	$HurtEffectTimer.start(0.2)
	
	$take_damage_cooldown.start()
	
	if health <= 0:
		is_attacking = false # Prevent getting stuck in attack state on death
		# You can add a death animation call here if you have one
		# $AnimatedSprite2D.play("death")
		queue_free()

func chase_player():
	var direction = (player.position - position).normalized()
	velocity = direction * speed
	if abs(direction.x) > abs(direction.y):
		$AnimatedSprite2D.play("right_walk" if direction.x > 0 else "left_walk")
	else:
		$AnimatedSprite2D.play("front_walk" if direction.y > 0 else "back_walk")

func idle():
	velocity = Vector2.ZERO
	if $AnimatedSprite2D.is_playing() and not "attack" in $AnimatedSprite2D.animation:
		$AnimatedSprite2D.stop()

func _on_animated_sprite_2d_animation_finished():
	if "attack" in $AnimatedSprite2D.animation:
		is_attacking = false
		$EnemyAttackTimer.start(attack_rate)

func _on_detection_area_body_entered(body: Node2D):
	if body.is_in_group("player"): player = body
func _on_detection_area_body_exited(body: Node2D):
	if body == player: player = null

# --- NEW TIMEOUT FUNCTIONS ---
func _on_hurt_effect_timer_timeout():
	$AnimatedSprite2D.modulate = Color.WHITE

func _on_knockback_timer_timeout():
	is_knocked_back = false
	velocity = Vector2.ZERO # Stop moving after knockback

func _on_take_damage_cooldown_timeout(): can_be_damaged = true
func _on_enemy_attack_timer_timeout(): can_attack = true
func update_health(): $healthbar.value = health; $healthbar.visible = health < 100
func enemylevel_1(): pass
