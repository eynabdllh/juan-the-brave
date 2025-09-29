extends CharacterBody2D

# Signals
signal died(enemy_position: Vector2)

# Tunables
@export var speed: float = 40.0
@export var attack_damage: int = 10
@export var attack_rate: float = 1.5
@export var max_health: int = 100
@export var knockback_speed: float = 150.0
@export var forget_player_seconds: float = 2.5

# State
var player: CharacterBody2D = null
var health: int
var can_be_damaged: bool = true
var can_attack: bool = true
var is_attacking: bool = false
var is_knocked_back: bool = false
var is_alive: bool = true
var last_walk_animation: String = "front_walk"

func _ready() -> void:
	health = max_health
	if has_node("/root/global") and get_node("/root/global").has_method("killed_enemies"):
		# Optional: support persistent deaths if you keep names stable
		if global.killed_enemies.has(self.name):
			queue_free()
			return
	if has_node("healthbar"):
		$healthbar.max_value = max_health
		$healthbar.value = health
	_play_idle()

func _physics_process(_delta: float) -> void:
	if not is_alive or is_attacking or is_knocked_back:
		move_and_slide()
		return
	var target_in_hitbox := _find_player_in_hitbox()
	if target_in_hitbox:
		player = target_in_hitbox
	if player != null and target_in_hitbox and can_attack:
		_attack_player()
	elif player != null:
		_chase_player()
	else:
		_idle()
	_update_health()
	move_and_slide()

# --- Hooks (override in subclasses if needed) ---
func _anim_name_walk_side() -> String: return "side_walk"
func _anim_name_walk_front() -> String: return "front_walk"
func _anim_name_walk_back() -> String: return "back_walk"
func _anim_name_attack_side() -> String: return "side_attack"
func _anim_name_attack_front() -> String: return "front_attack"
func _anim_name_attack_back() -> String: return "back_attack"
func _anim_name_idle() -> String: return "idle"

# --- Core behaviors ---
func _find_player_in_hitbox() -> CharacterBody2D:
	if not has_node("enemy_hitbox"): return null
	for body in $enemy_hitbox.get_overlapping_bodies():
		if body.is_in_group("player"):
			return body
	return null

func _attack_player() -> void:
	velocity = Vector2.ZERO
	is_attacking = true
	can_attack = false
	var anim := $AnimatedSprite2D
	if "side" in last_walk_animation:
		anim.play(_anim_name_attack_side())
	elif "back" in last_walk_animation:
		anim.play(_anim_name_attack_back())
	else:
		anim.play(_anim_name_attack_front())
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage, self)

func _chase_player() -> void:
	var direction := (player.position - position).normalized()
	velocity = direction * speed
	var anim := $AnimatedSprite2D
	if abs(direction.x) > abs(direction.y):
		last_walk_animation = _anim_name_walk_side()
		anim.flip_h = direction.x < 0
	else:
		last_walk_animation = _anim_name_walk_front() if direction.y > 0 else _anim_name_walk_back()
	anim.play(last_walk_animation)

func _idle() -> void:
	velocity = Vector2.ZERO
	_play_idle()

func _play_idle() -> void:
	var anim := $AnimatedSprite2D
	if is_instance_valid(anim):
		if anim.animation != _anim_name_idle():
			anim.play(_anim_name_idle())
		anim.stop()

func take_damage(amount: int, attacker: Node2D) -> void:
	if not can_be_damaged or not is_alive:
		return
	can_be_damaged = false
	health -= amount
	is_knocked_back = true
	var knockback_direction: Vector2 = (global_position - attacker.global_position).normalized()
	velocity = knockback_direction * knockback_speed
	# Visual hurt flash
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color.RED
	if has_node("KnockbackTimer"):
		$KnockbackTimer.start(0.15)
	if has_node("HurtSound"):
		$HurtSound.play()
	if has_node("HurtEffectTimer"):
		$HurtEffectTimer.start(0.2)
	if has_node("take_damage_cooldown"):
		$take_damage_cooldown.start()
	if health <= 0:
		die()

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
	var anim := $AnimatedSprite2D
	if is_instance_valid(anim):
		if anim.has_animation("death"):
			anim.play("death")
			await anim.animation_finished
	queue_free()

# --- Timers/Signals ---
func _on_knockback_timer_timeout() -> void:
	is_knocked_back = false
	velocity = Vector2.ZERO

func _on_take_damage_cooldown_timeout() -> void:
	can_be_damaged = true

func _on_enemy_attack_timer_timeout() -> void:
	can_attack = true

func _on_animated_sprite_2d_animation_finished() -> void:
	# When an attack animation ends, allow movement again and start the attack cooldown
	if is_attacking:
		is_attacking = false
		if has_node("EnemyAttackTimer"):
			$EnemyAttackTimer.start(attack_rate)

func _on_hurt_effect_timer_timeout() -> void:
	# Reset temporary hurt tint (set when taking damage)
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color.WHITE

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		# Optionally forget after a delay if timer exists
		if has_node("ForgetPlayerTimer"):
			$ForgetPlayerTimer.start(forget_player_seconds)
		else:
			player = null

func _on_forget_player_timer_timeout() -> void:
	player = null

func _update_health() -> void:
	if has_node("healthbar"):
		$healthbar.value = health
		$healthbar.visible = health < max_health
