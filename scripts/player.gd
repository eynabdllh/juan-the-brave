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
@export var base_attack_damage: int = 20

# Temporary visual FX state for invincibility (amulet)
var _invincible_fx_active := false
var _invincible_fx_tween: Tween
var _speed_trail: GPUParticles2D
var _speed_trail_active := false

func _ready():
    interact_prompt = $InteractPrompt
    feedback_label = $feedback_bubble/feedback_label
    feedback_timer = $feedback_timer
    
    $AnimatedSprite2D.play("front_idle")
    $regen.start()
    interact_prompt.hide()
    
    $feedback_bubble.hide() 
    # Hide in-world healthbar (we use the top-left HUD instead)
    if has_node("healthbar"):
        $healthbar.hide()
    # Initialize HUD health
    if has_node("/root/global"):
        var g = get_node("/root/global")
        if g.has_method("set_player_health"):
            g.set_player_health(health)
    # Prepare speed trail (created lazily on first use)
    
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
    # Apply global speed multiplier buff if any
    velocity = input_vector.normalized() * speed * (global.player_speed_mult if Engine.is_editor_hint() == false else 1.0)
    _update_speed_trail_direction()
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
            var dmg = base_attack_damage + (global.player_damage_bonus if Engine.is_editor_hint() == false else 0)
            body.take_damage(dmg, self)
    
    await $AnimatedSprite2D.animation_finished
    attack_ip = false

func take_damage(amount, attacker):
    # Respect invincibility buff
    if not Engine.is_editor_hint() and global.player_invincible:
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

func heal(amount: int) -> void:
    if health <= 0:
        return
    health = min(health + amount, 100)
    update_health()

func _on_hurt_effect_timer_timeout(): $AnimatedSprite2D.modulate = Color.WHITE
func _on_knockback_timer_timeout(): is_knocked_back = false

func current_camera():
    if global.current_scene == "world": $world_camera.enabled = true; $doorside_camera.enabled = false
    elif global.current_scene == "door_side": $world_camera.enabled = false; $doorside_camera.enabled = true
    elif global.current_scene == "map_2": $world_camera.enabled = false; $cemetery_camera.enabled = true

func update_health():
    $healthbar.value = health; $healthbar.visible = false
    if has_node("/root/global"):
        var g = get_node("/root/global")
        if g.has_method("set_player_health"):
            g.set_player_health(health)
    
# --- Speed trail API (used by potion "Speed Up") ---
func start_speed_trail(duration: float = 15.0) -> void:
    if _speed_trail_active:
        return
    _ensure_speed_trail()
    if _speed_trail:
        _speed_trail.emitting = velocity.length() > 5.0 and abs(velocity.x) >= abs(velocity.y)
        _speed_trail_active = true
        var t := get_tree().create_timer(duration)
        await t.timeout
        stop_speed_trail()

func stop_speed_trail() -> void:
    if _speed_trail and _speed_trail_active:
        _speed_trail.emitting = false
    _speed_trail_active = false

func _ensure_speed_trail() -> void:
    if _speed_trail and is_instance_valid(_speed_trail):
        return
    # Reuse existing node from the scene if present so you can style it manually
    var existing := get_node_or_null("SpeedTrail")
    if existing and existing is GPUParticles2D:
        _speed_trail = existing
    else:
        _speed_trail = GPUParticles2D.new()
        _speed_trail.name = "SpeedTrail"
        add_child(_speed_trail)
    # Ensure reasonable defaults if not set in the scene
    _speed_trail.z_index = 5
    if _speed_trail.texture == null:
        _speed_trail.texture = load("res://assets/effects/speed_trail.png")
    # Keep it thin and light
    _speed_trail.lifetime = 0.4
    _speed_trail.amount = 1
    _speed_trail.local_coords = true
    _speed_trail.emitting = false
    if _speed_trail.process_material == null:
        _speed_trail.process_material = _make_trail_material()

func _update_speed_trail_direction() -> void:
    if not _speed_trail or not _speed_trail_active:
        return
    var moving := velocity.length() > 5.0
    # Only show the trail when moving sideways (left/right)
    var sideways: bool = abs(velocity.x) > abs(velocity.y)
    _speed_trail.emitting = moving and sideways
    if not moving or not sideways:
        return
    # Snap direction to axis to ensure a clear vertical trail on front/back and horizontal on sides
    var dir_vec := Vector2.ZERO
    var offset := Vector2.ZERO
    # Horizontal movement -> horizontal trail behind (we early-returned on vertical)
    var sx: float = -signf(velocity.x)
    dir_vec = Vector2(sx, 0.0)
    offset = Vector2(sx * 6.0, 0.0)
    _speed_trail.position = offset
    var ppm := _speed_trail.process_material as ParticleProcessMaterial
    if ppm:
        ppm.direction = Vector3(dir_vec.x, dir_vec.y, 0)

func _make_trail_material() -> ParticleProcessMaterial:
    var m := ParticleProcessMaterial.new()
    # Godot 4's ParticleProcessMaterial uses Vector3 for gravity even in 2D
    m.gravity = Vector3.ZERO
    m.initial_velocity_min = 26.0
    m.initial_velocity_max = 36.0
    # Will be updated every frame from movement; default is left
    m.direction = Vector3(-1, 0, 0)
    m.spread = 8.0
    m.scale_min = 0.25
    m.scale_max = 0.45
    var ramp := Gradient.new()
    ramp.colors = PackedColorArray([Color(1,1,1,0.9), Color(1,1,1,0.0)])
    var ramp_tex := GradientTexture1D.new()
    ramp_tex.gradient = ramp
    m.color_ramp = ramp_tex
    return m
    
func _on_regen_timeout():
    if health > 0 and health < 100:
        health = min(health + 5, 100)
    
# --- Visual FX for amulet/invincibility ---
func start_invincible_fx(duration: float = 10.0) -> void:
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
