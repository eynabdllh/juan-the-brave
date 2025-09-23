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

    # Initialize slot nodes
    slots = [
        container.get_node_or_null("Slot1"),
        container.get_node_or_null("Slot2"),
        container.get_node_or_null("Slot3")
    ]

    # Connect to Inventory autoload directly
    var inv = get_node_or_null("/root/Inventory")
    if inv:
        inv.item_added.connect(_on_item_changed)
        inv.item_used.connect(_on_item_changed)
        inv.selection_changed.connect(_on_selection_changed)
        _refresh_all(inv.get_counts())
        _on_selection_changed(inv.selected_index)

func _unhandled_input(event):
    if event.is_action_pressed("use_slot_1"):
        _use_slot(0)
    elif event.is_action_pressed("use_slot_2"):
        _use_slot(1)
    elif event.is_action_pressed("use_slot_3"):
        _use_slot(2)

func _use_slot(idx: int) -> void:
    var inv = get_node_or_null("/root/Inventory")
    if inv:
        inv.set_selected_index(idx)
        inv.use_selected()

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
        var hi = slot.get_node_or_null("Highlight")
        if hi:
            hi.visible = (i == index)

func _refresh_all(counts: Dictionary) -> void:
    for i in range(3):
        var slot = slots[i] if i < slots.size() else null
        if slot == null:
            continue
        var item: String = ORDER[i]
        var icon = Inventory.ICONS.get(item, null)
        var icon_node = slot.get_node_or_null("Icon")
        if icon and icon_node:
            icon_node.texture = icon
        var c := int(counts.get(item, 0))
        var count_node = slot.get_node_or_null("Count")
        if count_node:
            count_node.text = ("x%d" % c) if c > 0 else ""
        slot.modulate = Color.WHITE if c > 0 else Color(1,1,1,0.5)
