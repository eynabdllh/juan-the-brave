extends HSlider

@export var audio_bus_name: String

var audio_bus_id: int = -1

func _ready():
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)

func _on_value_changed(new_value: float) -> void:
	if audio_bus_id < 0:
		return
	var v: float = clamp(new_value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(audio_bus_id, linear_to_db(v))
