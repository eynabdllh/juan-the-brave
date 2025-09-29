# In file: game/scripts/boss.gd
# This script is a direct adaptation of the working skeleton.gd logic.

extends CharacterBody2D

signal died(enemy_position)

# --- Boss-Specific Stats (Tweak these in the Inspector) ---
@export var speed: float = 25.0         # Slow, as requested
@export var attack_damage: int = 10      # Hits hard
@export var attack_rate: float = 2.0       # Slower, more deliberate attacks
@export var max_health: int = 200        # Very durable
@export var knockback_speed: float = 40.0 # Resists knockback

# --- State Variables ---
var player: CharacterBody2D = null
var health: int
var can_be_damaged: bool = true
var can_attack: bool = true
var is_attacking: bool = false
var is_knocked_back: bool = false
var is_alive: bool = true
var last_walk_animation: String = "front_idle" # Start with a safe default

func _ready():
	# Check if this enemy was already killed in a previous session
	if global.killed_enemies.has(self.name):
		queue_free()
		return

	health = max_health
	if has_node("healthbar"):
		$healthbar.max_value = health
		$healthbar.value = health
	
	idle() # Set the initial state

func _physics_process(_delta):
	if not is_alive or is_attacking or is_knocked_back:
		move_and_slide()
		return
		
	var target_in_hitbox = find_player_in_hitbox()
	if target_in_hitbox:
		player = target_in_hitbox
		
	if player != null and target_in_hitbox and can_attack:
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

func chase_player():
	var direction = (player.position - position).normalized()
	velocity = direction * speed
	var anim := $AnimatedSprite2D
	
	# This logic is the same as the skeleton's
	if abs(direction.x) > abs(direction.y):
		last_walk_animation = "side_walk"
		anim.flip_h = (direction.x < 0) # Flip the sprite for left movement
	else:
		last_walk_animation = "front_walk" if direction.y > 0 else "back_walk"
		anim.flip_h = false # Front/back animations are not flipped
	
	anim.play(last_walk_animation)

func attack_player():
	velocity = Vector2.ZERO
	is_attacking = true
	can_attack = false
	var anim := $AnimatedSprite2D
	
	# Play the correct attack animation based on the last direction
	if "side" in last_walk_animation:
		anim.play("side_attack")
	elif "back" in last_walk_animation:
		anim.play("back_attack")
	else:
		anim.play("front_attack")
		
	# Deal damage after a short delay to sync with the animation
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(attack_damage, self)

func idle():
	velocity = Vector2.ZERO
	var anim := $AnimatedSprite2D
	
	# Play the correct idle animation based on the last direction
	var idle_name := "front_idle"
	if "side" in last_walk_animation:
		idle_name = "side_idle"
	elif "back" in last_walk_animation:
		idle_name = "back_idle"
		
	if anim.animation != idle_name:
		anim.play(idle_name)

func take_damage(amount, attacker):
	if not can_be_damaged or not is_alive:
		return
		
	can_be_damaged = false
	health -= amount
	is_knocked_back = true
	
	var knockback_direction = (global_position - attacker.global_position).normalized()
	velocity = knockback_direction * knockback_speed
	
	$KnockbackTimer.start(0.15)
	$AnimatedSprite2D.modulate = Color.RED
	$HurtEffectTimer.start(0.2)
	$HurtSound.play()
	$take_damage_cooldown.start()
	
	if health <= 0:
		die()

func die():
	if not is_alive:
		return
		
	is_alive = false
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	global.add_killed_enemy(self.name)
	emit_signal("died", global_position)
	update_health()
	
	await get_tree().process_frame
	
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	var death_anim_name := "front_death"
	if "side" in last_walk_animation:
		death_anim_name = "side_death"
	elif "back" in last_walk_animation:
		death_anim_name = "back_death"
	
	anim.play(death_anim_name)
	await anim.animation_finished
	queue_free()

# --- Signal Connections ---

func _on_animated_sprite_2d_animation_finished():
	if "attack" in $AnimatedSprite2D.animation:
		is_attacking = false
		$EnemyAttackTimer.start(attack_rate)

func _on_detection_area_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body: Node2D):
	if body == player:
		player = null

func _on_knockback_timer_timeout():
	is_knocked_back = false
	velocity = Vector2.ZERO

func _on_hurt_effect_timer_timeout():
	$AnimatedSprite2D.modulate = Color.WHITE

func _on_take_damage_cooldown_timeout():
	can_be_damaged = true

func _on_enemy_attack_timer_timeout():
	can_attack = true

func update_health():
	if has_node("healthbar"):
		$healthbar.value = health
		$healthbar.visible = health < max_health
