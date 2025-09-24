# inventory_ui.gd (Definitive Diagnostic Version)
extends CanvasLayer

var slots: Array = [] # Will be filled in _ready() after resolving container

const ORDER := ["potion", "bread", "amulet"]

func _ready():
	# Resolve the container directly via absolute paths relative to this node
	var container = get_node_or_null("Margin/Col")
	if container == null:
		container = get_node_or_null("Margin/Row")
	if container == null:
		push_warning("InventoryUI: Missing 'Margin/Col' or 'Margin/Row' container")
		return

	# Initialize slot nodes (ensure array has 3 valid slots)
	slots = []
	for n in ["Slot1", "Slot2", "Slot3"]:
		var s = container.get_node_or_null(n)
		if s == null:
			push_warning("InventoryUI: Missing %s" % n)
		slots.append(s)

	# Connect to Inventory autoload directly
	var inv = get_node_or_null("/root/Inventory")
	if inv:
		inv.item_added.connect(_on_item_changed)
		inv.item_used.connect(_on_item_changed)
		inv.selection_changed.connect(_on_selection_changed)
		_refresh_all(inv.get_counts())
		_on_selection_changed(inv.selected_index)

func _unhandled_input(event):
	# Let the Inventory autoload handle hotkeys to prevent double-usage.
	pass

func _use_slot(idx: int) -> void:
	var inv = get_node_or_null("/root/Inventory")
	if inv:
		inv.set_selected_index(idx)

func _on_item_changed(item: String, new_count: int) -> void:
	var inv = get_node_or_null("/root/Inventory")
	if not inv:
		return
	_refresh_all(inv.get_counts())

func _on_selection_changed(index: int) -> void:
	for i in range(slots.size()):
		var slot = slots[i] if i < slots.size() else null
		if slot == null:
			continue
		var hi: Control = slot.get_node_or_null("Highlight")
		if hi:
			hi.visible = (i == index)
			hi.modulate = Color(1, 0.9, 0.2, 0.5) # stronger gold overlay
			hi.z_index = 10

func _refresh_all(counts: Dictionary) -> void:
	for i in range(3):
		var slot = slots[i] if i < slots.size() else null
		if slot == null:
			continue
		var item: String = ORDER[i]
		var icon = Inventory.ICONS.get(item, null)
		var icon_node: TextureRect = slot.get_node_or_null("Icon")
		if icon_node and icon:
			# Do not change layout; respect whatever you set in the scene.
			icon_node.texture = icon
		var c := int(counts.get(item, 0))
		var count_node = slot.get_node_or_null("Count")
		if count_node:
			count_node.text = ("x%d" % c) if c > 0 else ""
		slot.modulate = Color.WHITE if c > 0 else Color(1,1,1,0.5)
