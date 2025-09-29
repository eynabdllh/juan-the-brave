extends CanvasLayer

@export var player_id: int = 1

@onready var health_bar: ProgressBar = $Root/Health/BarRow/Bar
@onready var player_name: Label = $Root/Health/Name
@onready var enemies_icon: TextureRect = $Root/BottomRow/Enemies/Icon
@onready var enemies_label: Label = $Root/BottomRow/Enemies/Label
@onready var key_icon: TextureRect = $Root/BottomRow/Key/Icon
@onready var buffs_row: HBoxContainer = $Root/BottomRow/Buffs
@onready var buff_template: HBoxContainer = $Root/BottomRow/Buffs/BuffTemplate
@onready var _dim: ColorRect = $Dim

var _buff_widgets := {} # name -> {container, label, info}

func _ready():
	# Static config
	player_name.text = "Juan"
		# Subscribe to global signals (shared bottom row)
	if has_node("/root/global"):
		var g = get_node("/root/global")
		g.player_health_changed.connect(_on_health_changed)
		g.enemies_progress_changed.connect(_on_enemies_changed)
		g.key_changed.connect(_on_key_changed)
		g.buff_started.connect(_on_buff_started)
		g.buff_ended.connect(_on_buff_ended)
		g.buff_tick.connect(_on_buff_tick)
		g.heal_applied.connect(_on_heal_applied)
		# Initialize from current values if accessible
		_on_key_changed(g.player_has_key)

	# Subscribe to game_state for per-player health
	var gs := get_node_or_null("/root/game_state")
	if gs:
		gs.player_health_changed.connect(_on_player_health_changed)
		gs.player_max_health_changed.connect(_on_player_max_health_changed)
		# Initialize
		var h = gs.get_health(player_id)
		if h > 0:
			_on_health_changed(h)

func _on_health_changed(value: int) -> void:
	if is_instance_valid(health_bar):
		health_bar.value = value

func _on_player_health_changed(pid: int, value: int) -> void:
	if pid != player_id:
		return
	_on_health_changed(value)

func _on_player_max_health_changed(pid: int, maxv: int) -> void:
	if pid != player_id:
		return
	if is_instance_valid(health_bar):
		health_bar.max_value = maxv

func _on_enemies_changed(defeated: int, total: int) -> void:
	if is_instance_valid(enemies_label):
		enemies_label.text = str(defeated) + "/" + str(total)

func _on_key_changed(has_key: bool) -> void:
	if is_instance_valid(key_icon):
		key_icon.modulate = Color.WHITE if has_key else Color(1,1,1,0.2)

func _on_buff_started(name: String, duration: float, info: String) -> void:
	# Instance from template so you can manually edit size/font/colors in the scene
	if _buff_widgets.has(name):
		_remove_buff(name)
	var cont: HBoxContainer = buff_template.duplicate()
	cont.visible = true
	cont.name = "buff_" + name
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buffs_row.add_child(cont)

	var icon: TextureRect = cont.get_node("Icon")
	if icon:
		var tex := _get_buff_icon(name)
		icon.texture = tex
		icon.visible = tex != null
	var label: Label = cont.get_node("Label")
	if label:
		label.text = _format_buff_label(info, int(round(duration)))

	_buff_widgets[name] = {
		"container": cont,
		"label": label,
		"info": info
	}

func _on_buff_ended(name: String) -> void:
	_remove_buff(name)

func _remove_buff(name: String) -> void:
	if not _buff_widgets.has(name):
		return
	var data = _buff_widgets[name]
	if is_instance_valid(data.get("container")):
		data["container"].queue_free()
	_buff_widgets.erase(name)

func _on_buff_tick(name: String, remaining_seconds: int) -> void:
	if not _buff_widgets.has(name):
		return
	var data = _buff_widgets[name]
	var label: Label = data.get("label")
	if is_instance_valid(label):
		var info: String = String(data.get("info", ""))
		label.text = _format_buff_label(info, max(0, remaining_seconds))

func _on_heal_applied(amount: int) -> void:
	# Show +X HP text beside the health bar
	var lbl := Label.new()
	lbl.text = "+%d HP" % amount
	lbl.modulate = Color(0.3, 1.0, 0.3)
	$Root/Health.add_child(lbl)
	# Position to the right of the bar
	var bar := health_bar # $Root/Health/BarRow/Bar
	if is_instance_valid(bar):
		lbl.position = bar.position + Vector2(bar.size.x + 8, 0)
	else:
		lbl.position = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -12), 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(Callable(lbl, "queue_free"))

func _get_buff_icon(name: String) -> Texture2D:
	# Support specific potion variants (potion_speed, potion_DAMAGE, potion_INVINCIBLE)
	if name == "amulet":
		return load("res://assets/objects/amulet.png")
	if name == "potion" or name.begins_with("potion_"):
		return load("res://assets/objects/potion.png")
	return null

func _format_buff_label(info: String, secs: int) -> String:
	return "%s %ds" % [info, secs]
