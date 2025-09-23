extends CanvasLayer

@onready var health_bar: ProgressBar = $Root/Health/Bar
@onready var player_name: Label = $Root/Health/Name
@onready var enemies_icon: TextureRect = $Root/BottomRow/Enemies/Icon
@onready var enemies_label: Label = $Root/BottomRow/Enemies/Label
@onready var key_icon: TextureRect = $Root/BottomRow/Key/Icon

func _ready():
	# Static config
	player_name.text = "Juan"
	# Subscribe to global signals
	if has_node("/root/global"):
		var g = get_node("/root/global")
		g.player_health_changed.connect(_on_health_changed)
		g.enemies_progress_changed.connect(_on_enemies_changed)
		g.key_changed.connect(_on_key_changed)
		# Initialize from current values if accessible
		_on_key_changed(g.player_has_key)

func _on_health_changed(value: int) -> void:
	if is_instance_valid(health_bar):
		health_bar.value = value

func _on_enemies_changed(defeated: int, total: int) -> void:
	if is_instance_valid(enemies_label):
		enemies_label.text = str(defeated) + "/" + str(total)

func _on_key_changed(has_key: bool) -> void:
	if is_instance_valid(key_icon):
		key_icon.modulate = Color.WHITE if has_key else Color(1,1,1,0.35)
