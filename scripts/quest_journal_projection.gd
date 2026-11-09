extends RefCounted
# Read-only projection. Never accepts/turns in quests, refreshes progression,
# grants rewards, writes saves or infers numeric XP.
const RequestState = preload("res://scripts/request_state.gd")

static func entries(request, onboarding, inventory,fishing=null,plot=null) -> Array:
	var result: Array = []
	var delivery_status: String = request.status
	var delivery_lines: Array[String] = []
	for item in RequestState.REQUIRED:
		var title: String = "Timber" if item == "timber" else ("Metal scrap" if item == "metal" else String(item))
		var carried:int=inventory.amount("carried",item)
		var needed:int=maxi(0,RequestState.REQUIRED[item]-carried)
		delivery_lines.append("%s: %d / %d carried — %s" % [title,carried,RequestState.REQUIRED[item],"Ready" if needed==0 else "%d more needed"%needed])
	result.append({"id":"courtyard_repairs","title":"Courtyard repairs","status":"Completed" if delivery_status == "completed" else ("Active" if delivery_status == "active" else "Available at board"),"objective":"Completed; reward received." if delivery_status == "completed" else "\n".join(delivery_lines),"reward":"%d settlement credits, once" % RequestState.REWARD,"where":"Physical request board by the fountain","note":"Only carried materials count. No daily reset or shared progress."})
	var home_status: String = onboarding.status
	var home_objective: String = "Build an enclosed, roofed 2×2 home with a door."
	if home_status == "move_active": home_objective = "Bring Home Stash inside your completed 2×2 home. Restore the enclosure first if needed."
	elif home_status == "completed":
		if onboarding.home_step == "bench_pending": home_objective = "Build a ground-floor workbench from the build wheel. Carry 2 Timber and 1 Metal scrap; keep its front approach clear."
		elif onboarding.home_step == "bed_pending": home_objective = "Place a cosmetic starter bed from the build wheel. Keep its full foundation footprint, doorways and access clear. Free in this prototype; no sleep, healing or respawn."
		else: home_objective = "Prototype Home milestones complete."
	if plot!=null and home_status in ["house_pending","move_active"]:
		home_objective+="\n\n"+onboarding.home_checklist(plot)
	result.append({"id":"starter_home","title":"Your first Home","status":"Completed" if home_status == "completed" and onboarding.home_step == "complete" else "Active","objective":home_objective,"reward":"","where":"Your Home plot","note":"Home Stash MOVE is unlocked after the valid starter-home milestone; no extra item or credit reward."})
	var clothing_step: String = onboarding.clothing_step
	var outfit_done: bool = clothing_step in ["dye_active","complete"]
	var outfit_objective: String = "Accept A fresh outfit at the physical request board, then visit the tailor at the west path end."
	if clothing_step == "talk_dan": outfit_objective = "Visit Tailor & Dyes at the west path end."
	elif clothing_step == "claim_pending": outfit_objective = "The full outfit is reserved with the tailor. Make safe inventory space, then return to claim it."
	elif outfit_done: outfit_objective = "Basic clothing set claimed."
	result.append({"id":"fresh_outfit","title":"A fresh outfit","status":"Completed" if outfit_done else ("Available at board" if clothing_step == "available" else "Active"),"objective":outfit_objective,"reward":"One basic jacket, gloves, pants and boots, once","where":"Request board → Tailor & Dyes at the west path end","note":"No armor or weapons. Items are not automatically equipped."})
	# Do not display the follow-up as active before its real prerequisite.
	if outfit_done:
		result.append({"id":"make_it_yours","title":"Make it yours","status":"Completed" if clothing_step == "complete" else "Active","objective":"A changed eligible dye was committed." if clothing_step == "complete" else "With the tailor, commit a changed fabric dye on a jacket, gloves or pants. Preview/cancel does not count.","reward":"","where":"Tailor & Dyes at the west path end","note":"One free committed dye per eligible clothing slot per save. Boots are excluded. No extra quest reward."})
	if fishing!=null:
		result.append({"id":"first_catch","title":"First catch","status":"Completed" if fishing.status=="completed" else ("Active" if fishing.status=="active" else "Available at board"),"objective":"Delivered and saved." if fishing.status=="completed" else ("Carry your stream fish to the physical board (%d carried)."%inventory.amount("carried","stream_fish") if fishing.caught else "Use the free test rod at the northern stream, east of the Hall. Make one free carried space first."),"reward":"","where":"Physical request board → east side of Hall → northern stream → board","note":"One starter-request catch in this prototype. No bait, durability, credits or XP. Repeatable fishing is not enabled yet."})
	return result
