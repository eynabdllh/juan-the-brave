extends CharacterBody2D

# Networked player script for multiplayer functionality
# This script handles both local and remote player instances

# UI and interaction components
var interact_prompt: AnimatedSprite2D
var feedback_label: Label
var feedback_timer: Timer

# Player state variables
@export var knockback_speed = 100.0
var is_knocked_back = false

var health = 100
var player_alive = true
var attack_ip = false

const speed = 100
var current_dir = "front"
@export var base_attack_damage: int = 20

# Temporary visual FX state for invincibility (amulet)
var _invincible_fx_active := false
var _invincible_fx_tween: Tween

# Multiplayer variables
var player_id: int = 0
var is_local_player: bool = false

# Synchronized properties for network replication
@export var sync_position: Vector2
@export var sync_velocity: Vector2
@export var sync_animation: String = "front_idle"
@export var sync_flip_h: bool = false


func _enter_tree():
	# Identify as early as possible so replication can assign IDs cleanly
	player_id = get_multiplayer_authority()
	# Configure synchronizer ASAP so spawn-time replication has a valid config
	_setup_multiplayer_sync()

func _ready():
	# Initialize UI components
	interact_prompt = $InteractPrompt
	feedback_label = $feedback_bubble/feedback_label
	feedback_timer = $feedback_timer
	
	# Set up initial state
	$AnimatedSprite2D.play("front_idle")
	$regen.start()
	interact_prompt.hide()
	$feedback_bubble.hide()
	# Add to players group to identify teammates (used to prevent friendly fire)
	add_to_group("players")
	
	# Check if multiplayer is available before accessing it
	if not multiplayer.has_multiplayer_peer():
		print("Warning: No multiplayer peer assigned. Setting up as single player.")
		player_id = 1
		is_local_player = true
		_set_player_name_label()
		return
	
	# Read final authority assigned by server and determine if this is the local player
	player_id = get_multiplayer_authority()
	is_local_player = (player_id == multiplayer.get_unique_id())
	
	# Debug output
	print("Networked player ready - ID: ", player_id, " Local: ", is_local_player)
	print("Multiplayer unique ID: ", multiplayer.get_unique_id())
	print("Player authority: ", get_multiplayer_authority())
	
	# Configure MultiplayerSynchronizer after node is in tree to ensure properties exist
	call_deferred("_setup_multiplayer_sync")
	
	# Set player name label based on peer ID
	_set_player_name_label()
	
	# Additional check for local player determination
	if not is_local_player and player_id == multiplayer.get_unique_id():
		is_local_player = true
		print("Corrected: This is actually the local player!")

	# Make sure the local camera is immediately current when ready
	_update_local_camera()
	
	# Debug: Add input test
	print("Player ", player_id, " input authority check:")
	print("  - Can handle input: ", is_local_player)
	print("  - Authority ID: ", get_multiplayer_authority())
	print("  - Local peer ID: ", multiplayer.get_unique_id())
	feedback_timer = $feedback_timer
	
	# Set up initial state
	$AnimatedSprite2D.play("front_idle")
	$regen.start()
	interact_prompt.hide()
	$feedback_bubble.hide()
	# Add to players group to identify teammates (used to prevent friendly fire)
	add_to_group("players")
	
	# Check if multiplayer is available before accessing it
	if not multiplayer.has_multiplayer_peer():
		print("Warning: No multiplayer peer assigned. Setting up as single player.")
		player_id = 1
		is_local_player = true
		_set_player_name_label()
		return
	
	# Read final authority assigned by server and determine if this is the local player
	player_id = get_multiplayer_authority()
	is_local_player = (player_id == multiplayer.get_unique_id())
	
	# Debug output
	print("Networked player ready - ID: ", player_id, " Local: ", is_local_player)
	print("Multiplayer unique ID: ", multiplayer.get_unique_id())
	print("Player authority: ", get_multiplayer_authority())
	
	# Configure multiplayer synchronizer (do not change authority here)
	# Call async setup without awaiting to avoid blocking _ready
	_setup_multiplayer_sync()
	
	# Set player name label based on peer ID
	_set_player_name_label()
	
	# Additional check for local player determination
	if not is_local_player and player_id == multiplayer.get_unique_id():
		is_local_player = true
		print("Corrected: This is actually the local player!")
	
	# Debug: Add input test
	print("Player ", player_id, " input authority check:")
	print("  - Can handle input: ", is_local_player)
	print("  - Authority ID: ", get_multiplayer_authority())
	print("  - Local peer ID: ", multiplayer.get_unique_id())

func show_monologue(message: String):
	feedback_label.text = message
	# We now show the PARENT bubble, which contains the label.
	$feedback_bubble.show() 
	feedback_timer.start(2.5)

func _on_feedback_timer_timeout():
	# We hide the PARENT bubble when the timer is done.
	$feedback_bubble.hide()

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

func player(): pass

# Configure MultiplayerSynchronizer for property replication
func _setup_multiplayer_sync():
	var sync_node = get_node_or_null("MultiplayerSynchronizer")
	if not sync_node:
		print("Warning: MultiplayerSynchronizer not found on ", name)
		return
	
	# Ensure the synchronizer targets the parent (this player node)
	sync_node.root_path = NodePath("..")

	# Build replication config for exported properties so the synchronizer is fully configured
	var rc := SceneReplicationConfig.new()
	# Properties are on the parent node (root_path = ".."), so use ".:prop" paths
	var p_pos := NodePath(".:sync_position")
	var p_vel := NodePath(".:sync_velocity")
	var p_anim := NodePath(".:sync_animation")
	var p_flip := NodePath(".:sync_flip_h")

	rc.add_property(p_pos)
	rc.add_property(p_vel)
	rc.add_property(p_anim)
	rc.add_property(p_flip)

	# Replicate initial state on spawn
	rc.property_set_spawn(p_pos, true)
	rc.property_set_spawn(p_vel, true)
	rc.property_set_spawn(p_anim, true)
	rc.property_set_spawn(p_flip, true)

	# Continuous replication for movement; on-change for visuals
	rc.property_set_replication_mode(p_pos, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	rc.property_set_replication_mode(p_vel, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	rc.property_set_replication_mode(p_anim, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	rc.property_set_replication_mode(p_flip, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)

	# Apply to synchronizer
	sync_node.replication_config = rc
	# High-frequency replication for responsiveness
	sync_node.replication_interval = 0.0

	print("MultiplayerSynchronizer configured for ", name)

# Set the player name label above the character
func _set_player_name_label():
	var name_label = get_node_or_null("player_name_label")
	if name_label:
		# Use the actual authority ID for the label (works for any peer count)
		var authority_id: int = get_multiplayer_authority()
		name_label.text = "Player " + str(authority_id)
		print("Set player name label to: ", name_label.text, " (Authority ID: ", authority_id, ")")

func _physics_process(_delta: float):
	if is_knocked_back:
		move_and_slide() 
		return
	
	# Check if multiplayer is properly initialized
	if not multiplayer.has_multiplayer_peer():
		return
	
	# Critical fix: Always check authority in real-time
	var current_authority = get_multiplayer_authority()
	var local_peer_id = multiplayer.get_unique_id()
	
	# Update local player status based on current authority
	var should_be_local = (current_authority == local_peer_id)
	if is_local_player != should_be_local:
		is_local_player = should_be_local
		print("Updated local player status for player ", player_id, " (authority: ", current_authority, ", local peer: ", local_peer_id, ") -> Local: ", is_local_player)
		# Ensure camera is switched the moment localness changes
		_update_local_camera()
	
	# Update player ID if it changed and refresh label
	if player_id != current_authority:
		player_id = current_authority
		_set_player_name_label()
	
	# Process input for local player only
	if is_local_player:
		handle_input()
		_update_sync_properties()
	else:
		# For remote players, apply synchronized state first, then move
		_apply_sync_properties()
	
	current_camera()
	update_health()
	move_and_slide()
	
	if health <= 0 and player_alive:
		player_alive = false
		print("player has been killed")
		if is_local_player:
			# Only local player can remove themselves - use call_deferred to avoid physics issues
			call_deferred("queue_free")

# Update synchronized properties (called by local player)
func _update_sync_properties():
	sync_position = global_position
	sync_velocity = velocity
	sync_animation = _get_current_animation()
	sync_flip_h = $AnimatedSprite2D.flip_h

# Apply synchronized properties from remote players
func _apply_sync_properties():
	# Use direct assignment for exact speed matching - no interpolation
	global_position = sync_position
	velocity = sync_velocity
	
	# Apply animation state
	if $AnimatedSprite2D.animation != sync_animation:
		$AnimatedSprite2D.play(sync_animation)
	$AnimatedSprite2D.flip_h = sync_flip_h

# Get current animation name for synchronization
func _get_current_animation() -> String:
	return $AnimatedSprite2D.animation

# Input handling (only for local player)
func handle_input():
	if not is_local_player:
		return
	
	# Handle attack input
	if Input.is_action_just_pressed("attack") and not attack_ip:
		attack()

	# Handle movement input
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector.normalized() * speed
	play_anim()
	
	# Debug input detection (less verbose)
	if input_vector.length() > 0 and randf() < 0.1:  # Only log 10% of the time
		print("Player ", player_id, " moving: ", input_vector)

# Animation logic (same as original player)
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

# Attack functionality (networked via RPC)
func attack():
	if not is_local_player:
		return
		
	attack_ip = true
	
	# Call attack on all peers
	rpc("_perform_attack", current_dir)

# RPC function to synchronize attack across all clients
@rpc("any_peer", "call_local", "reliable")
func _perform_attack(attack_direction: String):
	if attack_direction == "side":
		$AnimatedSprite2D.play("side_attack")
	elif attack_direction == "front":
		$AnimatedSprite2D.play("front_attack")
	else: 
		$AnimatedSprite2D.play("back_attack")
	
	$deal_attack_timer.start()

# Attack timer callback
func _on_deal_attack_timer_timeout():
	# Only local player processes damage dealing
	if is_local_player:
		for body in $player_hitbox.get_overlapping_bodies():
			# Prevent friendly fire: never damage teammates (players group) or self
			if body == self:
				continue
			# Scenes use 'player' as the group; also ignore 'players' just in case
			if body.is_in_group("player") or body.is_in_group("players"):
				continue
			if body.has_method("take_damage"):
				var damage_bonus = 0
				if not Engine.is_editor_hint() and global.has_method("has") and global.has("player_damage_bonus"):
					damage_bonus = global.player_damage_bonus
				var dmg = base_attack_damage + damage_bonus
				body.take_damage(dmg, self)
	
	await $AnimatedSprite2D.animation_finished
	attack_ip = false

func take_damage(amount, attacker):
	# Respect invincibility buff
	if not Engine.is_editor_hint() and global.has_method("has") and global.has("player_invincible") and global.player_invincible:
		return
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

# UI and feedback functions are already defined above

# Camera management (only for local player)
func current_camera():
	# For remote players, keep all their cameras disabled on this peer
	if not is_local_player:
		if has_node("world_camera"):
			$world_camera.enabled = false
		if has_node("doorside_camera"):
			$doorside_camera.enabled = false
		if has_node("cemetery_camera"):
			$cemetery_camera.enabled = false
		return

	# Local player POV: always use world_camera by default unless another scene explicitly overrides
	if has_node("world_camera"):
		$world_camera.enabled = true
		if $world_camera.has_method("make_current"):
			$world_camera.make_current()
	# Safety: disable other optional cameras
	if has_node("doorside_camera"):
		$doorside_camera.enabled = false
	if has_node("cemetery_camera"):
		$cemetery_camera.enabled = false

func _update_local_camera():
	# Helper to set up camera immediately when we know local/scene
	if not is_local_player:
		return
	if global.current_scene == "world" and has_node("world_camera"):
		$world_camera.enabled = true
		$world_camera.make_current()
	elif global.current_scene == "door_side" and has_node("doorside_camera"):
		$doorside_camera.enabled = true
		$doorside_camera.make_current()
	elif has_node("cemetery_camera"):
		$cemetery_camera.enabled = true
		$cemetery_camera.make_current()

# Health management
func update_health():
	$healthbar.value = health
	$healthbar.visible = health < 100

func _on_regen_timeout():
	if health > 0 and health < 100:
		health = min(health + 5, 100)

func heal(amount: int) -> void:
	if health <= 0:
		return
	health = min(health + amount, 100)
	update_health()

# Timer callbacks
func _on_hurt_effect_timer_timeout(): 
	$AnimatedSprite2D.modulate = Color.WHITE

func _on_knockback_timer_timeout(): 
	is_knocked_back = false

# --- Visual FX for amulet/invincibility ---
func start_invincible_fx(_duration: float = 10.0) -> void:
	if _invincible_fx_active:
		return
	_invincible_fx_active = true
	# Pulse the sprite color between white and gold and slightly scale up/down
	var spr := $AnimatedSprite2D
	if is_instance_valid(_invincible_fx_tween):
		_invincible_fx_tween.kill()
	_invincible_fx_tween = create_tween()
	_invincible_fx_tween.set_loops() # will be killed by stop_invincible_fx after duration
	# Color pulse
	_invincible_fx_tween.tween_property(spr, "modulate", Color(1.0, 0.95, 0.3), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_invincible_fx_tween.tween_property(spr, "modulate", Color.WHITE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Scale pulse
	_invincible_fx_tween.parallel().tween_property(spr, "scale", Vector2(1.06, 1.06), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_invincible_fx_tween.tween_property(spr, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_invincible_fx() -> void:
	if not _invincible_fx_active:
		return
	_invincible_fx_active = false
	if is_instance_valid(_invincible_fx_tween):
		_invincible_fx_tween.kill()
	$AnimatedSprite2D.modulate = Color.WHITE
	$AnimatedSprite2D.scale = Vector2.ONE

# Player identification method is already defined above
