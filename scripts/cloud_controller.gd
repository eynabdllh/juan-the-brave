# cloud_controller.gd
extends ColorRect

func _process(delta):
	# This line takes the shader material...
	# ...and sets its "screen_size" parameter...
	# ...to the actual size of the game window's viewport.
	(material as ShaderMaterial).set_shader_parameter("screen_size", get_viewport_rect().size)
