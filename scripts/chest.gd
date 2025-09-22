extends Area2D

# Interactable Chest that grants one of several rewards when opened.
# Node expectations (under this Area2D):
# - AnimatedSprite2D named "ChestSprite" with animations: "closed", "open"
# - CollisionShape2D named "CollisionShape2D"
# - Label named "InteractPrompt" with text like "[E] OPEN"
# This script assumes the Player is in group "player" and has methods used below.

@export var heal_amount: int = 30
@export var potion_duration: float = 15.0 # seconds for temporary buffs
@export var chest_id: String = "" # Unique ID for persistence (defaults to node name if empty)

@onready var chest_sprite: AnimatedSprite2D = $ChestSprite
@onready var prompt: Label = $InteractPrompt
@onready var col: CollisionShape2D = $CollisionShape2D

var player_in_range: CharacterBody2D = null
var opened := false

func _ready():
	if chest_id == "":
		chest_id = name
	
	monitoring = true
	monitorable = true
	# Ensure masks/layers are set (mask 2 to detect player on layer 2). Adjust if your project uses different layers.
	set_collision_mask_value(2, true)
	
	if prompt:
		prompt.hide()
	# If this chest was already opened before, restore opened state and skip interaction
	if global.is_chest_opened(chest_id):
		opened = true
		if col: col.disabled = true
		if chest_sprite and chest_sprite.sprite_frames and chest_sprite.sprite_frames.has_animation("open"):
			chest_sprite.play("open")
			if prompt: prompt.hide()
		return
	else:
		if chest_sprite and chest_sprite.sprite_frames and chest_sprite.sprite_frames.has_animation("closed"):
			chest_sprite.play("closed")
	
	# If the player is already inside when the chest spawns, show prompt immediately
	await get_tree().process_frame
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			player_in_range = body
			if player_in_range.has_method("show_interact_prompt"):
				player_in_range.show_interact_prompt()
			if prompt:
				prompt.show()
			break

func _unhandled_input(event: InputEvent) -> void:	
	if opened:
		return
	if player_in_range and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_chest()

func _on_body_entered(body: Node2D) -> void:
	if opened:
		return
	if body.is_in_group("player"):
		# Debug: confirm overlap works
		print("Chest: player entered interaction area")
		player_in_range = body
		if player_in_range.has_method("show_interact_prompt"):
			player_in_range.show_interact_prompt()
		if prompt: prompt.show()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Chest: player exited interaction area")
		if player_in_range and player_in_range.has_method("hide_interact_prompt"):
			player_in_range.hide_interact_prompt()
		player_in_range = null
		if prompt: prompt.hide()

func _open_chest() -> void:
	opened = true
	if prompt: prompt.hide()
	if player_in_range and player_in_range.has_method("hide_interact_prompt"):
		player_in_range.hide_interact_prompt()
	# Play opening anim
	if chest_sprite and chest_sprite.sprite_frames and chest_sprite.sprite_frames.has_animation("open"):
		chest_sprite.play("open")
		await chest_sprite.animation_finished
		chest_sprite.play("open") # stay on last frame
	# Persist opened state
	global.set_chest_opened(chest_id)
	# Choose reward
	var reward_idx = randi() % 3
	match reward_idx:
		0:
			_apply_potion()
		1:
			_apply_bread()
		2:
			_apply_amulet()
	# Disable further interaction
	if col: col.disabled = true

func _apply_potion() -> void:
	# Random effect: damage up OR speed up OR invincibility
	var effect = randi() % 3
	match effect:
		0:
			# Damage up
			global.player_damage_bonus = 20 # +20 damage
			_show_player_msg("Albularyo's Potion: Damage Up!")
			_reset_after(potion_duration, func(): global.player_damage_bonus = 0)
		1:
			# Speed up
			global.player_speed_mult = 1.6
			_show_player_msg("Albularyo's Potion: Speed Up!")
			_reset_after(potion_duration, func(): global.player_speed_mult = 1.0)
		2:
			# Invincible
			global.player_invincible = true
			_show_player_msg("Albularyo's Potion: Invincible!")
			_reset_after(potion_duration, func(): global.player_invincible = false)

func _apply_bread() -> void:
	if player_in_range and player_in_range.has_method("heal"):
		player_in_range.heal(heal_amount)
		_show_player_msg("Tinapay: +%d HP" % heal_amount)

func _apply_amulet() -> void:
	global.player_invincible = true
	_show_player_msg("Anting-anting: Protected!")
	_reset_after(15.0, func(): global.player_invincible = false)

func _reset_after(seconds: float, cb: Callable) -> void:
	var t := get_tree().create_timer(seconds)
	await t.timeout
	cb.call()

func _show_player_msg(msg: String) -> void:
	if player_in_range and player_in_range.has_method("show_monologue"):
		player_in_range.show_monologue(msg)
