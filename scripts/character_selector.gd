extends Control

# Character Selection System
# Allows players to choose between different character types

signal character_selected(character_scene_path: String)

# Available characters
var characters = {
	"Juan": {
		"scene_path": "res://scenes/networked_player.tscn",
		"description": "Balanced fighter with standard abilities",
		"stats": {
			"speed": 100,
			"health": 100,
			"attack": 20,
			"special": "None"
		}
	},
	"Ruby": {
		"scene_path": "res://scenes/networked_ruby_player.tscn", 
		"description": "Fast warrior with dash ability",
		"stats": {
			"speed": 120,
			"health": 120,
			"attack": 25,
			"special": "Dash"
		}
	}
}

var selected_character: String = "Juan"

@onready var character_name_label: Label
@onready var character_description_label: Label
@onready var character_stats_label: Label
@onready var prev_button: Button
@onready var next_button: Button
@onready var select_button: Button

func _ready():
	# Find UI elements
	character_name_label = $VBox/CharacterName
	character_description_label = $VBox/Description
	character_stats_label = $VBox/Stats
	prev_button = $VBox/HBox/PrevButton
	next_button = $VBox/HBox/NextButton
	select_button = $VBox/SelectButton
	
	# Connect signals
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	select_button.pressed.connect(_on_select_pressed)
	
	# Initialize display
	_update_character_display()

func _on_prev_pressed():
	var character_names = characters.keys()
	var current_index = character_names.find(selected_character)
	current_index = (current_index - 1) % character_names.size()
	selected_character = character_names[current_index]
	_update_character_display()

func _on_next_pressed():
	var character_names = characters.keys()
	var current_index = character_names.find(selected_character)
	current_index = (current_index + 1) % character_names.size()
	selected_character = character_names[current_index]
	_update_character_display()

func _on_select_pressed():
	var character_data = characters[selected_character]
	character_selected.emit(character_data.scene_path)
	print("Selected character: ", selected_character)

func _update_character_display():
	var character_data = characters[selected_character]
	
	character_name_label.text = selected_character
	character_description_label.text = character_data.description
	
	var stats_text = "Stats:\n"
	stats_text += "Speed: " + str(character_data.stats.speed) + "\n"
	stats_text += "Health: " + str(character_data.stats.health) + "\n"
	stats_text += "Attack: " + str(character_data.stats.attack) + "\n"
	stats_text += "Special: " + character_data.stats.special
	
	character_stats_label.text = stats_text

func get_selected_character_path() -> String:
	return characters[selected_character].scene_path
