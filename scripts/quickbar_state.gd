extends RefCounted
# Transient selected index; authoritative assignments persist in InventoryState.
signal selection_changed(index:int)
# Six user-specified slots; HUD width/input range derive from this count.
const SLOT_COUNT=6
var selected_index:int=0
func select(index:Variant)->bool:
	if not index is int or index<0 or index>=SLOT_COUNT:return false
	if selected_index!=index:
		selected_index=index
		selection_changed.emit(index)
	return true
