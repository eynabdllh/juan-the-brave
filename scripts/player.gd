extends CharacterBody2D

var interact_prompt: AnimatedSprite2D
var feedback_label: Label
var feedback_timer: Timer
var anim_sprite: AnimatedSprite2D

@export var knockback_speed = 100.0
var is_knocked_back = false

var health = 100
var player_alive = true
var attack_ip = false

const speed = 100
var current_dir = "front"

func _ready():
	# Cache commonly used nodes (use get_node_or_null to avoid crashes if missing)
	anim_sprite = get_node_or_null("AnimatedSprite2D")
	interact_prompt = get_node_or_null("InteractPrompt")
	feedback_label = get_node_or_null("feedback_bubble/feedback_label") # Correct path to the nested label
	feedback_timer = get_node_or_null("feedback_timer")

	if anim_sprite:
		anim_sprite.play("front_idle")
	if has_node("regen"):
		$regen.start()
	if interact_prompt:
		interact_prompt.hide()
	
	# We hide the PARENT bubble, not just the label.
	if has_node("feedback_bubble"):
		$feedback_bubble.hide() 
	
func show_monologue(message: String):
	if feedback_label:
		feedback_label.text = message
	# We now show the PARENT bubble, which contains the label.
	if has_node("feedback_bubble"):
		$feedback_bubble.show() 
	if feedback_timer:
		feedback_timer.start(2.5)

func _on_feedback_timer_timeout():
	# We hide the PARENT bubble when the timer is done.
	if has_node("feedback_bubble"):
		$feedback_bubble.hide()
	
func _physics_process(delta):
	if is_knocked_back:
		move_and_slide() 
		return
		
	handle_input()
	current_camera()
	update_health()
	move_and_slide()
	
	if health <= 0 and player_alive:
		player_alive = false
		print("player has been killed")
		self.queue_free()

func show_interact_prompt():
	if interact_prompt:
		interact_prompt.show()
		# Play the pop-up animation once.
		interact_prompt.play("pop_up")
		# When it's finished, it will automatically switch to the idle loop.
		await interact_prompt.animation_finished
		# This check prevents a bug if the player leaves the area while the animation is playing.
		if interact_prompt.visible:
			interact_prompt.play("idle")

func hide_interact_prompt():
	if interact_prompt:
		interact_prompt.hide()
	
func handle_input():
	if Input.is_action_just_pressed("attack") and not attack_ip:
		attack()

	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector.normalized() * speed
	play_anim()
	
func play_anim():
	var anim = anim_sprite
	if anim == null:
		return
	
	if velocity.length() > 0.1:
		if abs(velocity.x) > abs(velocity.y):
			current_dir = "side"
			anim.flip_h = velocity.x < 0
		else:
			current_dir = "front" if velocity.y > 0 else "back"
	
	if attack_ip:
		return
	
	if velocity.length() > 0.1:
		if current_dir == "side": anim.play("side_walk")
		elif current_dir == "front": anim.play("front_walk")
		else: anim.play("back_walk")
	else:
		if current_dir == "side": anim.play("side_idle")
		elif current_dir == "front": anim.play("front_idle")
		else: anim.play("back_idle")

func player(): pass

func attack():
	attack_ip = true
	
	if anim_sprite:
		if current_dir == "side":
			anim_sprite.play("side_attack")
		elif current_dir == "front":
			anim_sprite.play("front_attack")
		else: 
			anim_sprite.play("back_attack")
	
	if has_node("deal_attack_timer"):
		$deal_attack_timer.start()

func _on_deal_attack_timer_timeout():
	if has_node("player_hitbox"):
		for body in $player_hitbox.get_overlapping_bodies():
			if body != self and body.has_method("take_damage"):
				body.take_damage(20, self)
	
	if anim_sprite:
		await anim_sprite.animation_finished
	attack_ip = false

func take_damage(amount, attacker):
	if is_knocked_back: return
	health -= amount
	print("Player took damage, health is now: ", health)

	is_knocked_back = true
	var knockback_direction = (global_position - attacker.global_position).normalized()
	velocity = knockback_direction * knockback_speed
	if has_node("KnockbackTimer"):
		$KnockbackTimer.start(0.1)

	if has_node("HurtSound"):
		$HurtSound.play()
	if anim_sprite:
		anim_sprite.modulate = Color.RED
	if has_node("HurtEffectTimer"):
		$HurtEffectTimer.start(0.2)

func _on_hurt_effect_timer_timeout():
	if anim_sprite:
		anim_sprite.modulate = Color.WHITE
func _on_knockback_timer_timeout(): is_knocked_back = false

func current_camera():
	if global.current_scene == "world":
		if has_node("world_camera"): $world_camera.enabled = true
		if has_node("doorside_camera"): $doorside_camera.enabled = false
	elif global.current_scene == "door_side":
		if has_node("world_camera"): $world_camera.enabled = false
		if has_node("doorside_camera"): $doorside_camera.enabled = true
	elif global.current_scene == "map_2":
		if has_node("world_camera"): $world_camera.enabled = false
		if has_node("cemetery_camera"): $cemetery_camera.enabled = true

func update_health():
	if has_node("healthbar"):
		$healthbar.value = health
		$healthbar.visible = health < 100
	
func _on_regen_timeout():
	if health > 0 and health < 100:
		health = min(health + 5, 100)

func _on_attack_cooldown_timeout():
	# Optional: could be used to re-enable attacking if you add a cooldown lock.
	pass

func _on_attack_hit_timer_timeout():
	# Optional: could be used to gate the actual hit window of the attack.
	pass
