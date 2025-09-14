extends Node

var player_current_attack = false	
var current_scene = "world"

var transition_scene = false

var player_exit_doorside_posx = 195
var player_exit_doorside_posy = 15
var player_start_posx = 59
var player_start_posy = 90 

var game_first_loadin = true

func finish_changescenes():
	if transition_scene == true:
		transition_scene = false
		if current_scene == "world":
			current_scene = "door_side"
		else:
			current_scene = "world"
