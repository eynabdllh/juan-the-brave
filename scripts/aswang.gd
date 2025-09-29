extends "res://scripts/base_enemy.gd"

# Aswang stats
@export var _b_speed: float = 40.0
@export var _b_damage: int = 8
@export var _b_rate: float = 1.5
@export var _b_health: int = 100
@export var _b_knockback: float = 160.0

func _ready() -> void:
	speed = _b_speed
	attack_damage = _b_damage
	attack_rate = _b_rate
	max_health = _b_health
	knockback_speed = _b_knockback
	super._ready()

# Animation name hooks
func _anim_name_idle() -> String: return "idle"
func _anim_name_walk_side() -> String: return "side_walk"
func _anim_name_walk_front() -> String: return "front_walk"
func _anim_name_walk_back() -> String: return "back_walk"
func _anim_name_attack_side() -> String: return "side_attack"
func _anim_name_attack_front() -> String: return "front_attack"
func _anim_name_attack_back() -> String: return "back_attack"

# Attack behavior
func _attack_player() -> void:
	velocity = Vector2.ZERO
	is_attacking = true
	can_attack = false
	
	var anim := $AnimatedSprite2D
	var attack_anim = _anim_name_attack_side()
	
	# Determine attack direction
	if player:
		var x_dist = abs(player.global_position.x - global_position.x)
		var y_dist = abs(player.global_position.y - global_position.y)
		
		if x_dist > y_dist:
			# Side attack
			attack_anim = _anim_name_attack_side()
			anim.flip_h = (player.global_position.x < global_position.x)
		else:
			# Vertical attack
			attack_anim = _anim_name_attack_front() if player.global_position.y > global_position.y else _anim_name_attack_back()
	
	anim.play(attack_anim)
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage, self)
		
	# Wait for attack animation to finish
	await get_tree().create_timer(0.5).timeout
	is_attacking = false
	
	# Start attack cooldown
	if has_node("EnemyAttackTimer"):
		$EnemyAttackTimer.start(attack_rate)

# Override take_damage to make boss more resilient
func take_damage(amount: int, attacker: Node2D) -> void:
	if not can_be_damaged or not is_alive:
		return
	
	# Boss takes slightly reduced damage
	var reduced_amount = int(amount * 0.8)
	super.take_damage(reduced_amount, attacker)
	
	# Visual feedback
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.modulate = Color(1, 0.5, 0.5)  
		if has_node("HurtEffectTimer"):
			$HurtEffectTimer.start(0.15)

# Death handling with boss-specific effects
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
	
	# Play death animation if available
	var anim: AnimatedSprite2D = $AnimatedSprite2D
	if is_instance_valid(anim):
		var death_anim = "front_death"
		if anim.sprite_frames and anim.sprite_frames.has_animation(death_anim):
			anim.play(death_anim)
			await anim.animation_finished
		elif anim.sprite_frames and anim.sprite_frames.has_animation("death"):
			anim.play("death")
			await anim.animation_finished
	
	queue_free()
