# inventory_ui.gd (Definitive Diagnostic Version)
extends CanvasLayer

var item_container: VBoxContainer
var item_slots: Dictionary = {}
var items_in_slots: Dictionary = {}

# The 'async' keyword allows us to use 'await'
func _ready():
	# Wait for one frame to ensure the entire scene tree is fully initialized.
	await get_tree().process_frame
	
	# --- DIAGNOSTIC STEP 1: Find the first node in the path ---
	print("--- INVENTORY UI DIAGNOSTIC ---")
	var margin_container_node = find_child("MarginContainer")
	
	if margin_container_node == null:
		print("ERROR: CRITICAL FAILURE! Could not find a child node named 'MarginContainer'.")
		print("SOLUTION: Please check the InventoryUI.tscn scene tree and make sure the MarginContainer is a direct child of the root InventoryUI node and is spelled EXACTLY 'MarginContainer'.")
		return # Stop the function here to prevent a crash.
	else:
		print("SUCCESS: Found 'MarginContainer' node.")

	# --- DIAGNOSTIC STEP 2: Find the second node in the path ---
	item_container = margin_container_node.find_child("VBoxContainer")
	
	if item_container == null:
		print("ERROR: CRITICAL FAILURE! Found 'MarginContainer', but could not find a child named 'VBoxContainer' inside it.")
		print("SOLUTION: Please check the InventoryUI.tscn scene tree and make sure the VBoxContainer is a direct child of MarginContainer and is spelled EXACTLY 'VBoxContainer'.")
		return # Stop the function here.
	else:
		print("SUCCESS: Found 'VBoxContainer' node. The UI should now work.")
		
	# --- The rest of the script can now run safely ---
	for i in item_container.get_child_count():
		var slot_number = i + 1
		var slot_node = item_container.get_child(i)
		if slot_node is Panel and slot_node.has_node("ItemIcon"):
			var icon_node = slot_node.get_node("ItemIcon")
			item_slots[slot_number] = icon_node
			icon_node.hide()

func add_item(slot_number: int, item_texture: Texture2D):
	if not item_container:
		await _ready()

	if item_slots.has(slot_number):
		var icon_node = item_slots[slot_number]
		icon_node.texture = item_texture
		icon_node.show()
		items_in_slots[slot_number] = item_texture

func remove_item(slot_number: int):
	if item_slots.has(slot_number):
		var icon_node = item_slots[slot_number]
		icon_node.hide()
		icon_node.texture = null
		items_in_slots.erase(slot_number)
