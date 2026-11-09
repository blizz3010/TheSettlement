extends RefCounted
# Read-only panel copy. Eligibility and transactions stay in starter_clothing.
static func text(inventory, onboarding) -> String:
	match onboarding.clothing_step:
		"available":
			return "A fresh outfit • Available\nAccept A fresh outfit at the request board, then visit Tailor & Dyes at the west path end.\nOne free basic jacket, gloves, pants and boots. No armor; not automatically equipped."
		"talk_dan", "claim_pending":
			var title:String = "A fresh outfit • Reserved with the tailor" if onboarding.clothing_step == "claim_pending" else "A fresh outfit • Ready to claim"
			var space:int = maxi(0,inventory.capacity("carried")-inventory.used("carried"))
			var action:String = "Make room for the full outfit: four free carried units needed (%d available). Then claim here." % space if space < 4 else "Claim the full outfit here. Placement is checked before anything is granted."
			return title+"\n"+action+"\nBasic jacket, gloves, pants and boots; not automatically equipped."
		"dye_active":
			return "Make it yours • Active\n"+dye_hint(inventory)+"\nChange the fabric color and commit it. Preview or cancel does not finish the quest. Boots cannot be dyed."
		"complete":
			return "Clothing quests • Complete\nYour outfit was claimed and a changed dye committed.\n"+dye_hint(inventory)
	return "Clothing progress unavailable."

static func dye_hint(inventory) -> String:
	var remaining:bool = false
	var stored:bool = false
	for slot in ["jacket","gloves","pants"]:
		if not inventory.dye_free_used[slot]: remaining = true
	for entry in inventory.equipment_owned.values():
		var slot:String = inventory.equipment_definitions()[entry.definition_id].category
		if slot not in ["jacket","gloves","pants"] or inventory.dye_free_used[slot]: continue
		if entry.location in ["carried","equipped"]:
			return "Select a garment marked free dye available. First committed dye is free per slot, per save."
		if entry.location in ["home_stash","lockbox"]: stored = true
	if stored:
		return "Withdraw a garment with unused free dye from Home Stash or Lockbox before dyeing it here."
	if remaining:
		return "No carried or equipped garment has unused free dye. Free uses are tracked per slot, not per item."
	return "All three free dye uses are spent. Paid dye is unavailable; its credit price is not selected."

static func concise(inventory,onboarding)->String:
	match onboarding.clothing_step:
		"available":return "Free starter outfit · Accept A fresh outfit at the request board."
		"talk_dan","claim_pending":
			var room=maxi(0,inventory.capacity("carried")-inventory.used("carried"))
			return "Free starter outfit · Ready to claim." if room>=4 else "Free starter outfit · Make %d more carried spaces."%(4-room)
		"dye_active":return "Make it yours · Open Dye and commit a changed fabric color."
		"complete":return "Starter outfit complete · Free dye is tracked per clothing slot."
	return "Clothing progress unavailable."
