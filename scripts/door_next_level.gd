extends Node2D

@export var locked_message = "It's locked. I need to find a key."
@export var unlocked_message = "The door is now open, finally."
@export var require_key: bool = true
@export_enum("auto", "map_2", "map_3", "map_4", "door_side_1", "door_side_2") var target_scene: String = "auto"

@onready var door_sprite: AnimatedSprite2D = $DoorSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_locked = true
var player_in_range: CharacterBody2D = null

func _ready():
	_connect_interaction_area_signals()
	_connect_exit_area_signals()
	lock()

func _connect_interaction_area_signals():
	if Engine.is_editor_hint():
		return
	var connected := false
	# Prefer an explicitly named InteractionArea
	if has_node("InteractionArea"):
		var ia: Area2D = $InteractionArea
		if not ia.body_entered.is_connected(Callable(self, "_on_interaction_area_body_entered")):
			ia.body_entered.connect(Callable(self, "_on_interaction_area_body_entered"))
		if not ia.body_exited.is_connected(Callable(self, "_on_interaction_area_body_exited")):
			ia.body_exited.connect(Callable(self, "_on_interaction_area_body_exited"))
		connected = true
	# Recursive fallback: find any Area2D descendant whose name hints at interaction
	if not connected:
		var areas: Array = find_children("", "Area2D", true, false)
		for a in areas:
			var n := String(a.name).to_lower()
			if n.find("interact") != -1 or n.find("interaction") != -1:
				if not a.body_entered.is_connected(Callable(self, "_on_interaction_area_body_entered")):
					a.body_entered.connect(Callable(self, "_on_interaction_area_body_entered"))
				if not a.body_exited.is_connected(Callable(self, "_on_interaction_area_body_exited")):
					a.body_exited.connect(Callable(self, "_on_interaction_area_body_exited"))
				connected = true
	if connected:
		print("[door] Interaction area connected for ", name)
	if not connected:
		print("[door] No InteractionArea found under ", name, ". Add an Area2D named 'InteractionArea' (or *interact*) with a CollisionShape2D.")

func _connect_exit_area_signals():
	if Engine.is_editor_hint():
		return
	var connected := false
	var node_path: NodePath = NodePath("")
	if has_node("door_exit"):
		node_path = NodePath("door_exit")
	elif has_node("ExitArea"):
		node_path = NodePath("ExitArea")
	if node_path != NodePath(""):
		var ea: Area2D = get_node(node_path)
		if not ea.body_entered.is_connected(Callable(self, "_on_exit_area_body_entered")):
			ea.body_entered.connect(Callable(self, "_on_exit_area_body_entered"))
		connected = true
	if not connected:
		# Recursive fallback: find any Area2D descendant whose name hints at exit/door
		var areas: Array = find_children("", "Area2D", true, false)
		for ea2 in areas:
			var n := String(ea2.name).to_lower()
			if n.find("exit") != -1 or n.find("door_exit") != -1 or n.find("teleport") != -1:
				if not ea2.body_entered.is_connected(Callable(self, "_on_exit_area_body_entered")):
					ea2.body_entered.connect(Callable(self, "_on_exit_area_body_entered"))
				connected = true
	if connected:
		print("[door] Exit area connected for ", name)
	if not connected:
		print("[door] No ExitArea found under ", name, ". Add an Area2D named 'door_exit' or 'ExitArea' (or *exit*) with a CollisionShape2D for auto-teleport.")

func _unhandled_input(event):
	if player_in_range and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		# If this door requires a key and is currently locked, enforce the key
		if require_key:
			if is_locked and global.player_has_key:
				print("[door] Unlocking via interact (has key)")
				unlock()
			elif is_locked:
				print("[door] Locked and no key; showing message")
				player_in_range.show_monologue(locked_message)
			else:
				print("[door] Interact: going to next level")
				go_to_next_level()
		else:
			# No key required: if locked, unlock immediately and go
			if is_locked:
				print("[door] No key required: unlocking on interact")
				unlock()
			else:
				print("[door] Interact: going to next level (no key required)")
				go_to_next_level()

func _on_interaction_area_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = body
		player_in_range.show_interact_prompt()

func _on_interaction_area_body_exited(body: Node2D):
	if body.is_in_group("player"):
		if player_in_range:
			player_in_range.hide_interact_prompt()
		player_in_range = null

func _on_exit_area_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return
	# If key required and door is locked, do not auto-teleport. Prompt once if possible.
	if require_key and is_locked:
		if body.has_method("show_monologue"):
			body.show_monologue(locked_message)
		return
	if is_locked:
		# No key required: unlock and proceed
		print("[door] Auto-exit: unlocking (no key required)")
		unlock()
	else:
		print("[door] Auto-exit: going to next level")
		go_to_next_level()

func go_to_next_level():
	var dest := target_scene
	if dest == "auto":
		match global.current_scene:
			"map_3":
				dest = "door_side_1"
			"door_side_1":
				dest = "map_3"
			"map_4":
				dest = "door_side_2"
			"door_side_2":
				dest = "map_4"
			_:
				dest = "world"
	print("[door] Routing from ", global.current_scene, " to ", dest)
	
	# Special case: When going from door_side_2 to map_4, show the outro cutscene first
	if global.current_scene == "door_side_2" and dest == "map_4":
		print("Showing outro cutscene before map_4")
		get_tree().change_scene_to_file("res://scenes/outro_cutscene.tscn")
		return
		
	match dest:
		"map_2":
			global.go_to_map_2()
		"map_3":
			global.go_to_map_3()
		"map_4":
			global.go_to_map_4()
		"door_side_1":
			global.go_to_door_side_1()
		"door_side_2":
			global.go_to_door_side_2()
		_:
			global.go_to_world()

func lock():
	is_locked = true
	if is_instance_valid(door_sprite):
		door_sprite.play("locked")
	if is_instance_valid(collision_shape):
		collision_shape.disabled = false

func unlock():
	is_locked = false
	if player_in_range:
		player_in_range.hide_interact_prompt()
		player_in_range.show_monologue(unlocked_message)
	if is_instance_valid(door_sprite):
		door_sprite.play("opening")
		await door_sprite.animation_finished
		door_sprite.play("unlocked")
	if is_instance_valid(collision_shape):
		collision_shape.disabled = true 
	go_to_next_level()
