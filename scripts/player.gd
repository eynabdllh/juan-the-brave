extends CharacterBody2D

var interact_prompt: AnimatedSprite2D
var feedback_label: Label
var feedback_timer: Timer

@export var knockback_speed = 100.0
var is_knocked_back = false

var health = 100
var player_alive = true
var attack_ip = false

const speed = 100
var current_dir = "front"

func _ready():
	interact_prompt = $InteractPrompt
	feedback_label = $feedback_bubble/feedback_label # Correct path to the nested label
	feedback_timer = $feedback_timer
	
	$AnimatedSprite2D.play("front_idle")
	$regen.start()
	interact_prompt.hide()
	
	# We hide the PARENT bubble, not just the label.
	$feedback_bubble.hide() 
	
func show_monologue(message: String):
	feedback_label.text = message
	# We now show the PARENT bubble, which contains the label.
	$feedback_bubble.show() 
	feedback_timer.start(2.5)

func _on_feedback_timer_timeout():
	# We hide the PARENT bubble when the timer is done.
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
	interact_prompt.show()
	# Play the pop-up animation once.
	interact_prompt.play("pop_up")
	# When it's finished, it will automatically switch to the idle loop.
	await interact_prompt.animation_finished
	# This check prevents a bug if the player leaves the area while the animation is playing.
	if interact_prompt.visible:
		interact_prompt.play("idle")

func hide_interact_prompt():
	interact_prompt.hide()
	
func handle_input():
	if Input.is_action_just_pressed("attack") and not attack_ip:
		attack()

	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector.normalized() * speed
	play_anim()
	
func play_anim():
	var anim = $AnimatedSprite2D
	
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
	
	if current_dir == "side":
		$AnimatedSprite2D.play("side_attack")
	elif current_dir == "front":
		$AnimatedSprite2D.play("front_attack")
	else: 
		$AnimatedSprite2D.play("back_attack")
	
	$deal_attack_timer.start()

func _on_deal_attack_timer_timeout():
	for body in $player_hitbox.get_overlapping_bodies():
		if body != self and body.has_method("take_damage"):
			body.take_damage(20, self)
	
	await $AnimatedSprite2D.animation_finished
	attack_ip = false

func take_damage(amount, attacker):
	if is_knocked_back: return
	health -= amount
	print("Player took damage, health is now: ", health)

	is_knocked_back = true
	var knockback_direction = (global_position - attacker.global_position).normalized()
	velocity = knockback_direction * knockback_speed
	$KnockbackTimer.start(0.1)

	$HurtSound.play()
	$AnimatedSprite2D.modulate = Color.RED
	$HurtEffectTimer.start(0.2)

func _on_hurt_effect_timer_timeout(): $AnimatedSprite2D.modulate = Color.WHITE
func _on_knockback_timer_timeout(): is_knocked_back = false

func current_camera():
	if global.current_scene == "world": $world_camera.enabled = true; $doorside_camera.enabled = false
	elif global.current_scene == "door_side": $world_camera.enabled = false; $doorside_camera.enabled = true

func update_health():
	$healthbar.value = health; $healthbar.visible = health < 100
	
func _on_regen_timeout():
	if health > 0 and health < 100:
		health = min(health + 5, 100)
