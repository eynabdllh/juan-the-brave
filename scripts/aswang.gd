extends "res://scripts/base_enemy.gd"

# Aswang uses side-only animations; we reuse them for all directions
@export var _a_speed: float = 60.0
@export var _a_damage: int = 12
@export var _a_rate: float = 1.0
@export var _a_health: int = 50
@export var _a_knockback: float = 140.0

func _ready() -> void:
	speed = _a_speed
	attack_damage = _a_damage
	attack_rate = _a_rate
	max_health = _a_health
	knockback_speed = _a_knockback
	super._ready()

# --- Animation name hooks (reuse side-only names) ---
func _anim_name_idle() -> String: return "idle"
func _anim_name_walk_side() -> String: return "right_walk"
func _anim_name_walk_front() -> String: return "right_walk"
func _anim_name_walk_back() -> String: return "right_walk"
func _anim_name_attack_side() -> String: return "right_attack"
func _anim_name_attack_front() -> String: return "right_attack"
func _anim_name_attack_back() -> String: return "right_attack"

# Ensure we face the player when attacking
func _attack_player() -> void:
	velocity = Vector2.ZERO
	is_attacking = true
	can_attack = false
	var anim := $AnimatedSprite2D
	# Flip if target is to the left so right_* sprites face correctly
	if player:
		anim.flip_h = (player.global_position.x < global_position.x)
	anim.play("right_attack")
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage, self)

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
		if frames and frames.has_animation("right_death"):
			anim.play("right_death")
			await anim.animation_finished
		elif frames and frames.has_animation("death"):
			anim.play("death")
			await anim.animation_finished
	queue_free()
