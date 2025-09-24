extends Control

@onready var icon: TextureRect = $HBox/Icon
@onready var label: Label = $HBox/Label

func setup(tex: Texture2D, text: String) -> void:
	if icon:
		icon.texture = tex
	if label:
		label.text = text

func play_and_free() -> void:
	# Small float up + fade
	modulate.a = 0.0
	position = Vector2(0, -18)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.12)
	tw.tween_property(self, "position", position + Vector2(0, -14), 0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(Callable(self, "queue_free"))
