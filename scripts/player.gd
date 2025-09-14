extends CharacterBody2D

# (All your variables are correct)
@export var knockback_speed = 100.0
var is_knocked_back = false
var health = 100
var player_alive = true
var attack_ip = false
const speed = 100
var current_dir = "none"

func _ready():
	$AnimatedSprite2D.play("front_idle")
	$regen.start()

func _physics_process(delta):
	if not is_knocked_back:
		handle_input()
	
	# The attack() function is no longer called here.
	# It's now called from an animation signal for perfect timing.
	current_camera()
	update_health()
	move_and_slide()
	
	if health <= 0 and player_alive:
		player_alive = false
		print("player has been killed")
		self.queue_free()

func handle_input():
	if Input.is_action_just_pressed("attack") and not attack_ip:
		attack() # Call the attack function on input
		
	# Movement logic
	if not attack_ip: # Don't move while attacking
		if Input.is_action_pressed("ui_right"):
			current_dir = "right"; play_anim(1); velocity.x = speed; velocity.y = 0
		elif Input.is_action_pressed("ui_left"):
			current_dir = "left"; play_anim(1); velocity.x = -speed; velocity.y = 0	
		elif Input.is_action_pressed("ui_down"):
			current_dir = "down"; play_anim(1); velocity.y = speed; velocity.x = 0
		elif Input.is_action_pressed("ui_up"):
			current_dir = "up"; play_anim(1); velocity.y = -speed; velocity.x = 0
		else:
			play_anim(0); velocity.x = 0; velocity.y = 0
		multiDirCheck()

# (multiDirCheck and play_anim are the same, no changes needed)
func multiDirCheck():
	if Input.is_action_pressed("ui_right") and Input.is_action_pressed("ui_down"): velocity = velocity.normalized() * speed
	if Input.is_action_pressed("ui_left") and Input.is_action_pressed("ui_up"): velocity = velocity.normalized() * speed
	if Input.is_action_pressed("ui_right") and Input.is_action_pressed("ui_up"): velocity = velocity.normalized() * speed
	if Input.is_action_pressed("ui_left") and Input.is_action_pressed("ui_down"): velocity = velocity.normalized() * speed
func play_anim(movement):
	var dir = current_dir; var anim = $AnimatedSprite2D
	if dir == "right": anim.flip_h = false;
	if dir == "left": anim.flip_h = true
	if movement == 1:
		if dir == "right" or dir == "left": anim.play("side_walk")
		elif dir == "down": anim.play("front_walk")
		elif dir == "up": anim.play("back_walk")
	elif not attack_ip:
		if dir == "right" or dir == "left": anim.play("side_idle")
		else: anim.play("front_idle")

func player(): pass

# --- THE DEFINITIVE PLAYER ATTACK FIX ---
func attack():
	attack_ip = true
	# Play the animation
	if current_dir == "right": $AnimatedSprite2D.flip_h = false; $AnimatedSprite2D.play("side_attack")
	elif current_dir == "left": $AnimatedSprite2D.flip_h = true; $AnimatedSprite2D.play("side_attack")
	elif current_dir == "down": $AnimatedSprite2D.play("front_attack")
	elif current_dir == "up": $AnimatedSprite2D.play("back_attack")
	
	# After a short delay to sync with the animation, deal damage
	$deal_attack_timer.start()

func _on_deal_attack_timer_timeout():
	# Now that the attack "lands", find who we hit
	for body in $player_hitbox.get_overlapping_bodies():
		if body.has_method("take_damage"):
			# We found an enemy! Call its take_damage function.
			body.take_damage(20, self) # Deal 20 damage
	
	# Wait for the animation to finish before allowing another attack
	await $AnimatedSprite2D.animation_finished
	attack_ip = false

# (Rest of the script is correct)
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
		health += 5
		if health > 100: health = 100
