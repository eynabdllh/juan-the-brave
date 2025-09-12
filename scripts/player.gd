extends CharacterBody2D

var enemy_inattack_range = false
var enemy_attack_cooldown = true
var health = 100
var player_alive = true

const speed = 100
var current_dir = "none"

func _ready():
	$AnimatedSprite2D.play("front_idle")

func _physics_process(delta):
	player_movement(delta)
	multiDirCheck()
	enemy_attack()
	
	if health <= 0:
		player_alive = false #go back to menu or respond
		health = 0
		print("player has been killed")
		self.queue_free()

func player_movement(delta):
	if Input.is_action_pressed("ui_right"):
		current_dir = "right"
		play_anim(1)
		velocity.x = speed
		velocity.y = 0
	elif Input.is_action_pressed("ui_left"):
		current_dir = "left"
		play_anim(1)
		velocity.x = -speed
		velocity.y = 0	
	elif Input.is_action_pressed("ui_down"):
		current_dir = "down"
		play_anim(1)
		velocity.y = speed
		velocity.x = 0
	elif Input.is_action_pressed("ui_up"):
		current_dir = "up"
		play_anim(1)
		velocity.y = -speed
		velocity.x = 0
	else:
		play_anim(0)
		velocity.x = 0
		velocity.y = 0
		
func multiDirCheck():
	if Input.is_action_pressed("ui_right") and Input.is_action_pressed("ui_down"):
		velocity.x = speed / 1.5
		velocity.y = speed / 1.5
	if Input.is_action_pressed("ui_left") and Input.is_action_pressed("ui_up"):
		velocity.x = speed / -1.5
		velocity.y = speed / -1.5
	if Input.is_action_pressed("ui_right") and Input.is_action_pressed("ui_up"):
		velocity.x = speed / 1.5
		velocity.y = speed / -1.5
	if Input.is_action_pressed("ui_left") and Input.is_action_pressed("ui_down"):
		velocity.x = speed / -1.5
		velocity.y = speed / 1.5
	
	move_and_slide()
	
func play_anim(movement):
	var dir = current_dir
	var anim = $AnimatedSprite2D
	
	if dir == "right":
		anim.flip_h = false
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			anim.play("side_idle")

	if dir == "left":
		anim.flip_h = true
		if movement == 1:
			anim.play("side_walk")
		elif movement == 0:
			anim.play("side_idle")

	if dir == "down":
		anim.flip_h = true
		if movement == 1:
			anim.play("front_walk")
		elif movement == 0:
			anim.play("front_idle")

	if dir == "up":
		anim.flip_h = true
		if movement == 1:
			anim.play("back_walk")
		elif movement == 0:
			anim.play("back_idle")

func player():
	pass
	
func _on_player_hitbox_body_entered(body: Node2D) -> void:
	# This first print statement will tell us if the collision is detected AT ALL.
	print("Something entered my hitbox! It was: ", body.name)

	if body.is_in_group("enemies"):
		# This second print statement will tell us if the group check passed.
		print("The thing that entered was an enemy!")
		enemy_inattack_range = true

func _on_player_hitbox_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemies"): 
		enemy_inattack_range = false

func enemy_attack():
	if enemy_inattack_range and enemy_attack_cooldown == true:
		health -= 20
		enemy_attack_cooldown = false
		$attack_cooldown.start()
		print(health)


func _on_attack_cooldown_timeout() -> void:
	enemy_attack_cooldown = true
