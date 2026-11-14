extends "res://scripts/character_profiles/selection_panel.gd"
## Item 15 MOCKUP: redesigned character select screen (preview for approval).
## Reuses the shipped panel's session logic (refresh / select_preview / choose /
## creator) unchanged; only the layout and presentation are rebuilt here.
const RedesignStage=preload("res://raid/scripts/select_redesign_stage.gd")
const TEAL=Color("7fd3c8")
const PANEL_FILL=Color(0.06,0.10,0.09,0.78)
const CARD_FILL=Color(0.09,0.14,0.13,0.86)
const STAT_MIN=3
const STAT_MAX=12
var variant:="sidebar" ## "sidebar" (A) or "carousel" (B)
var info_box:VBoxContainer
var stat_rows:Dictionary={}
var perk_row:HFlowContainer
var look_label:Label
var slot_label:Label
var mockup_tag:Label
var strip:HBoxContainer

class StatBar extends Control:
	var value:=0.0;var color:=Color("c6a975")
	func _init():custom_minimum_size=Vector2(120,10);size_flags_horizontal=Control.SIZE_EXPAND_FILL
	func _draw():
		var r=Rect2(Vector2(0,size.y*.5-4),Vector2(size.x,8))
		draw_rect(r,Color(1,1,1,.08))
		draw_rect(Rect2(r.position,Vector2(r.size.x*clampf(value,0,1),r.size.y)),color)
		for i in range(1,10):draw_line(Vector2(size.x*i/10.0,r.position.y),Vector2(size.x*i/10.0,r.end.y),Color(0.06,0.1,0.09,.9),1)

static func shade_rect(horizontal:bool,stops:PackedFloat32Array,colors:PackedColorArray)->TextureRect:
	var g=Gradient.new();g.offsets=stops;g.colors=colors
	var t=GradientTexture2D.new();t.gradient=g;t.width=256;t.height=256
	t.fill_from=Vector2(0,0);t.fill_to=Vector2(1,0) if horizontal else Vector2(0,1)
	var r=TextureRect.new();r.texture=t;r.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;r.stretch_mode=TextureRect.STRETCH_SCALE
	r.mouse_filter=Control.MOUSE_FILTER_IGNORE;r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);return r

func panel_box(fill:Color,border:Color,width:int=1,radius:int=10)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(width);s.set_corner_radius_all(radius)
	s.content_margin_left=22;s.content_margin_right=22;s.content_margin_top=18;s.content_margin_bottom=18
	return s

func caps(parent:Node,value:String,size:int=13,color:Color=COPPER)->Label:
	var l=text(parent,value,size,color);l.uppercase=true;l.autowrap_mode=TextServer.AUTOWRAP_OFF;return l

func _ready():
	theme=MenuTheme.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 3D set fills the whole screen behind the UI.
	preview=RedesignStage.new()
	preview.screen_offset=0.0 if variant=="sidebar" else 0.42
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(preview)
	preview.custom_minimum_size=Vector2.ZERO
	var ink=Color(0.035,0.06,0.055)
	if variant=="sidebar":
		add_child(shade_rect(true,PackedFloat32Array([0,.30,.42,.62,.72,1]),PackedColorArray([Color(ink,.88),Color(ink,.70),Color(ink,0),Color(ink,0),Color(ink,.55),Color(ink,.85)])))
	else:
		add_child(shade_rect(true,PackedFloat32Array([0,.55,.68,1]),PackedColorArray([Color(ink,0),Color(ink,0),Color(ink,.6),Color(ink,.85)])))
	add_child(shade_rect(false,PackedFloat32Array([0,.14,.70,1]),PackedColorArray([Color(ink,.7),Color(ink,0),Color(ink,0),Color(ink,.9)])))
	selection_root=MarginContainer.new();selection_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]:selection_root.add_theme_constant_override("margin_"+side,44)
	selection_root.add_theme_constant_override("margin_top",30);selection_root.add_theme_constant_override("margin_bottom",28)
	add_child(selection_root)
	var main=VBoxContainer.new();main.add_theme_constant_override("separation",18);selection_root.add_child(main)
	# Header: crest + kicker + title.
	var header=HBoxContainer.new();header.add_theme_constant_override("separation",16);main.add_child(header)
	var crest=TextureRect.new();crest.texture=load("res://assets/ui/settlement_crest.png");crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;crest.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;crest.custom_minimum_size=Vector2(58,58);header.add_child(crest)
	var titles=VBoxContainer.new();titles.add_theme_constant_override("separation",0);header.add_child(titles)
	caps(titles,"The Settlement",14,COPPER)
	var heading=text(titles,"Choose your settler",34,INK);heading.autowrap_mode=TextServer.AUTOWRAP_OFF;heading.add_theme_font_override("font",MenuTheme.heading_font())
	var hspacer=Control.new();hspacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(hspacer)
	mockup_tag=caps(header,"MOCKUP • preview for approval",13,Color("e9b872"))
	mockup_tag.add_theme_stylebox_override("normal",panel_box(Color(0.3,0.2,0.08,.55),Color("c6a975"),1,6))
	columns=HBoxContainer.new();columns.add_theme_constant_override("separation",24);columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_child(columns)
	# Character list (left column in A, bottom strip in B).
	left_panel=PanelContainer.new();left_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	body=VBoxContainer.new();body.add_theme_constant_override("separation",12)
	if variant=="carousel":
		var wrap=VBoxContainer.new();wrap.add_theme_constant_override("separation",8);left_panel.add_child(wrap)
		strip=HBoxContainer.new();strip.add_theme_constant_override("separation",14);strip.alignment=BoxContainer.ALIGNMENT_CENTER
		wrap.add_child(body);wrap.add_child(strip)
	else:
		left_panel.add_child(body)
	if variant=="sidebar":columns.add_child(left_panel)
	var middle=Control.new();middle.size_flags_horizontal=Control.SIZE_EXPAND_FILL;middle.mouse_filter=Control.MOUSE_FILTER_IGNORE;columns.add_child(middle)
	# Info card (right).
	preview_panel=PanelContainer.new();preview_panel.add_theme_stylebox_override("panel",panel_box(PANEL_FILL,Color(.78,.66,.46,.45)))
	preview_panel.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;columns.add_child(preview_panel)
	preview_holder=VBoxContainer.new();preview_holder.add_theme_constant_override("separation",8);preview_panel.add_child(preview_holder)
	info_box=preview_holder
	slot_label=caps(preview_holder,"",13,TEAL)
	preview_name=text(preview_holder,"",40,INK);preview_name.add_theme_font_override("font",MenuTheme.heading_font())
	preview_stats=text(preview_holder,"",1,INK);preview_stats.hide()
	_divider(preview_holder)
	caps(preview_holder,"Attributes",12,MUTED)
	for key in ["str","int","dex"]:
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);preview_holder.add_child(row)
		var name_l=caps(row,{"str":"Strength","int":"Intellect","dex":"Dexterity"}[key],13,INK);name_l.custom_minimum_size.x=96;name_l.autowrap_mode=TextServer.AUTOWRAP_OFF
		var bar=StatBar.new();bar.color={"str":Color("d08a5a"),"int":Color("7fb7d3"),"dex":Color("9cc98a")}[key];row.add_child(bar)
		var v=text(row,"",18,COPPER);v.custom_minimum_size.x=28;v.autowrap_mode=TextServer.AUTOWRAP_OFF;v.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		stat_rows[key]=[bar,v]
	_divider(preview_holder)
	caps(preview_holder,"Traits",12,MUTED)
	perk_row=HFlowContainer.new();perk_row.add_theme_constant_override("h_separation",8);perk_row.add_theme_constant_override("v_separation",8);preview_holder.add_child(perk_row)
	_divider(preview_holder)
	caps(preview_holder,"Look",12,MUTED)
	look_label=text(preview_holder,"",15,INK)
	preview_note=text(preview_holder,"",13,MUTED)
	preview_panel.custom_minimum_size.x=380
	# Bottom bar: back • rotate • enter.
	if variant=="carousel":main.add_child(left_panel)
	var footer=HBoxContainer.new();footer.add_theme_constant_override("separation",16);main.add_child(footer)
	back_button=styled_button(footer,"‹  BACK",_back)
	var s1=Control.new();s1.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(s1)
	var rotate=HBoxContainer.new();rotate_controls=rotate;rotate.add_theme_constant_override("separation",8);footer.add_child(rotate)
	styled_button(rotate,"⟲",func():preview.set_angle(preview.angle-30)).custom_minimum_size.x=52
	caps(rotate,"Turn",12,MUTED).custom_minimum_size.y=48
	rotate.get_child(1).vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	styled_button(rotate,"⟳",func():preview.set_angle(preview.angle+30)).custom_minimum_size.x=52
	var s2=Control.new();s2.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(s2)
	enter_button=styled_button(footer,"ENTER THE SETTLEMENT  ›",func():if not selected_slot.is_empty():choose(selected_slot),true)
	enter_button.custom_minimum_size=Vector2(300,56);enter_button.add_theme_font_size_override("font_size",20)
	enter_button.disabled=true
	resized.connect(layout);layout();refresh()

func _divider(parent:Node):
	var line=ColorRect.new();line.color=Color(.78,.66,.46,.25);line.custom_minimum_size.y=1;parent.add_child(line)

func layout():
	if not is_instance_valid(left_panel):return
	if variant=="sidebar":left_panel.custom_minimum_size.x=clampf(size.x*.27,280,420)
	if is_instance_valid(preview_panel):preview_panel.custom_minimum_size.x=clampf(size.x*.25,300,400)

func label(value:String):
	return caps(body,value,13,COPPER)

func refresh():
	if is_instance_valid(strip):
		for c in strip.get_children():strip.remove_child(c);c.queue_free()
	super.refresh()
	if variant=="carousel":
		for child in body.get_children():
			if child is Button:body.remove_child(child);strip.add_child(child)
			elif child is Label and child!=status:child.hide()
	for child in body.get_children():
		if child is Label and child.text.begins_with("Saved appearance"):
			child.text="Stats are rolled at creation. Gameplay bonuses are not active yet."
			if variant=="carousel":child.hide()
		if child is Button and not cards.values().has(child):
			# "+ Create second character" as a quiet dashed slot.
			child.add_theme_stylebox_override("normal",panel_box(Color(0,0,0,.25),Color(.78,.66,.46,.35),1,10))
			child.add_theme_stylebox_override("hover",panel_box(Color(.1,.15,.14,.5),Color("c6a975"),1,10))
			child.add_theme_color_override("font_color",MUTED)
			if variant=="carousel":child.custom_minimum_size=Vector2(240,92)
	if is_instance_valid(status) and variant=="carousel" and status.text.is_empty():status.hide()

func select_preview(slot:String):
	super.select_preview(slot)
	if not profiles.has(slot):return
	var profile:Dictionary=profiles[slot]
	for key in cards:_style_card(key,key==selected_slot)
	slot_label.text=("Slot %s" % slot.trim_prefix("slot_"))+("  •  New arrival" if not profile.get("intro_seen",false) else "  •  Returning settler")
	for key in stat_rows:
		var v=int(profile.stats[key])
		stat_rows[key][0].value=float(v-STAT_MIN+1)/float(STAT_MAX-STAT_MIN+1);stat_rows[key][0].queue_redraw()
		stat_rows[key][1].text=str(v)
	for c in perk_row.get_children():perk_row.remove_child(c);c.queue_free()
	var perks:Array=profile.get("perks",[])
	if perks.is_empty():caps(perk_row,"None chosen",12,MUTED)
	for perk in perks:
		var chip=Label.new();chip.text=str(Rules.LABELS.get(perk,perk)).replace(" (prototype)","")
		chip.add_theme_font_size_override("font_size",14);chip.add_theme_color_override("font_color",INK)
		chip.add_theme_stylebox_override("normal",_chip_box(int(Rules.COSTS.get(perk,0))))
		perk_row.add_child(chip)
	var a:Dictionary=profile.appearance
	var hair={"none":"No hair","hair_short02_v1":"Short crop","hair_bob01_v1":"Bob"}.get(a.hair,a.hair)
	var tint=str(a.get("hair_tint","natural")).replace("_"," ")
	look_label.text="%s, %s  •  %s eyes" % [hair,tint,"Brown" if a.eyes=="eye_brown_v1" else "Blue"]
	if preview_note.text.begins_with("Saved face"):preview_note.text="Shown with saved look and equipped clothing."

func _chip_box(cost:int)->StyleBoxFlat:
	var s=panel_box(Color(.12,.2,.18,.9) if cost>0 else Color(.22,.14,.1,.9),TEAL if cost>0 else Color("d08a5a"),1,12)
	s.content_margin_left=10;s.content_margin_right=10;s.content_margin_top=3;s.content_margin_bottom=3
	return s

func _style_card(slot:String,active:bool):
	var card:Button=cards[slot];var p:Dictionary=profiles[slot]
	card.text="";card.custom_minimum_size=Vector2(240,104) if variant=="carousel" else Vector2(0,104)
	var normal=panel_box(Color(.13,.21,.19,.92) if active else CARD_FILL,Color("c6a975") if active else Color(.5,.62,.56,.35),2 if active else 1,10)
	if active:normal.border_width_left=6
	for state in ["normal","hover","focus","pressed"]:card.add_theme_stylebox_override(state,normal)
	var holder=card.get_node_or_null("CardContent")
	if holder!=null:card.remove_child(holder);holder.queue_free()
	var box=VBoxContainer.new();box.name="CardContent";box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);box.offset_left=22;box.offset_top=14;box.offset_right=-16;box.offset_bottom=-12
	box.add_theme_constant_override("separation",4);card.add_child(box)
	var top=HBoxContainer.new();top.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(top)
	var n=text(top,p.appearance.name,24,INK if active else Color(.85,.82,.74));n.add_theme_font_override("font",MenuTheme.heading_font());n.size_flags_horizontal=Control.SIZE_EXPAND_FILL;n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var tag=caps(top,"Slot "+slot.trim_prefix("slot_"),11,TEAL if active else MUTED);tag.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var stats=HBoxContainer.new();stats.add_theme_constant_override("separation",10);stats.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(stats)
	for key in ["str","int","dex"]:
		var l=caps(stats,"%s %d"%[key,int(p.stats[key])],13,COPPER if active else MUTED);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;l.autowrap_mode=TextServer.AUTOWRAP_OFF
	var hint=text(box,"Selected" if active else "Click to preview",12,TEAL if active else Color(.6,.68,.64,.8));hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
