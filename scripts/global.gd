# global.gd (Definitive, Working Version)
extends Node

var player_current_attack = false	
var current_scene = "world"

var player_exit_doorside_pos = Vector2(195, 15)
var player_start_pos = Vector2(59, 90) 

var game_first_loadin = true
var player_has_key = false

# --- NEW: This will store the names of enemies we have killed ---
var killed_enemies = []

# --- NEW: A function to add a killed enemy to our list ---
func add_killed_enemy(enemy_name):
	if not killed_enemies.has(enemy_name):
		killed_enemies.append(enemy_name)
	print("Killed enemies are now: ", killed_enemies)

func go_to_door_side():
	current_scene = "door_side"
	get_tree().change_scene_to_file("res://scenes/door_side.tscn")

func go_to_world():
	current_scene = "world"
	get_tree().change_scene_to_file("res://scenes/world.tscn")
