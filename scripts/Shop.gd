extends Control

const UPGRADES = {
	"freeze_duration": {"name": "Freeze Duration", "desc": "Increases freeze time.", "base_cost": 100, "cost_mult": 1.5, "max_level": 5},
	"bomb_radius": {"name": "Bomb Radius", "desc": "Increases explosion size.", "base_cost": 100, "cost_mult": 1.5, "max_level": 5},
	"drain_amount": {"name": "Drain Power", "desc": "Increases flood drained.", "base_cost": 150, "cost_mult": 1.6, "max_level": 5},
	"shield_capacity": {"name": "Shield Capacity", "desc": "More hits absorbed.", "base_cost": 200, "cost_mult": 2.0, "max_level": 3}
}

const ABILITIES = {
	"time_warp": {"name": "Time Warp", "desc": "Slows time by 50% for 5s.", "cost": 0}, # Default
	"evaporation": {"name": "Evaporation", "desc": "Instantly drains 30% flood.", "cost": 1000},
	"tidal_wave": {"name": "Tidal Wave", "desc": "Wipes screen, scoring all.", "cost": 2000},
	"midas_touch": {"name": "Midas Touch", "desc": "8s of only Gold drops.", "cost": 3000},
	"auto_turret": {"name": "Auto-Turret", "desc": "Auto-pops drops for 4s.", "cost": 4000}
}

const PASSIVES = {
	"score_boost": {"name": "Score Boost", "desc": "+2 base score for drops.", "cost": 500},
	"magnetic_tap": {"name": "Magnetic Tap", "desc": "Slightly increases tap radius.", "cost": 1000},
	"streak_accelerator": {"name": "Streak Accelerator", "desc": "Multiplier builds 25% faster.", "cost": 1500},
	"juicy_drops": {"name": "Juicy Drops", "desc": "10% chance for 2x points/streak.", "cost": 2000},
	"toxic_immunity": {"name": "Toxic Immunity", "desc": "Toxic drops don't reset streak.", "cost": 2500},
	"mini_turret": {"name": "Mini Turret", "desc": "Tiny turret auto-shoots drops.", "cost": 4000},
	"chain_lightning": {"name": "Chain Lightning", "desc": "Chance to zap nearby drops.", "cost": 5000}
}

@onready var droplets_label: Label = $VBox/Header/DropletsLabel
@onready var back_button: Button = $VBox/Header/BackButton
@onready var list_container: VBoxContainer = $VBox/Scroll/List
@onready var tabs_container: HBoxContainer = HBoxContainer.new()

@onready var debug_panel: PanelContainer = $DebugPanel
@onready var debug_grant_btn: Button = $DebugPanel/VBox/GrantBtn
@onready var debug_reset_btn: Button = $DebugPanel/VBox/ResetBtn

var current_tab: String = "upgrades"

func _ready() -> void:
	back_button.pressed.connect(func():
		AudioManager.play_sfx("button")
		GameManager.goto_main_menu()
	)
	
	if OS.has_feature("editor"):
		debug_panel.visible = true
		debug_grant_btn.pressed.connect(_on_debug_grant)
		debug_reset_btn.pressed.connect(_on_debug_reset)
	else:
		debug_panel.visible = false
		
	# Setup tabs
	tabs_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_container.add_theme_constant_override("separation", 20)
	var btn_upg = Button.new()
	btn_upg.text = "UPGRADES"
	btn_upg.custom_minimum_size = Vector2(200, 60)
	btn_upg.add_theme_font_size_override("font_size", 28)
	btn_upg.pressed.connect(func(): current_tab = "upgrades"; AudioManager.play_sfx("button"); _refresh_ui())
	tabs_container.add_child(btn_upg)
	
	var btn_abl = Button.new()
	btn_abl.text = "ABILITIES"
	btn_abl.custom_minimum_size = Vector2(200, 60)
	btn_abl.add_theme_font_size_override("font_size", 28)
	btn_abl.pressed.connect(func(): current_tab = "abilities"; AudioManager.play_sfx("button"); _refresh_ui())
	tabs_container.add_child(btn_abl)
	
	var btn_pas = Button.new()
	btn_pas.text = "PASSIVES"
	btn_pas.custom_minimum_size = Vector2(200, 60)
	btn_pas.add_theme_font_size_override("font_size", 28)
	btn_pas.pressed.connect(func(): current_tab = "passives"; AudioManager.play_sfx("button"); _refresh_ui())
	tabs_container.add_child(btn_pas)
	
	$VBox.add_child(tabs_container)
	$VBox.move_child(tabs_container, 1) # Put under header
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	$VBox.add_child(spacer)
	$VBox.move_child(spacer, 2)
		
	_refresh_ui()

func _refresh_ui() -> void:
	droplets_label.text = "Droplets: %d" % ThemeManager.get_droplets()
	
	for c in list_container.get_children():
		c.queue_free()
		
	if current_tab == "upgrades":
		var current_upgrades = SaveManager.get_value("upgrades", {})
		for key in UPGRADES.keys():
			var info = UPGRADES[key]
			var level = current_upgrades.get(key, 1)
			list_container.add_child(_create_upgrade_item(key, info, level))
	elif current_tab == "abilities":
		var unlocked = SaveManager.get_value("unlocked_abilities", ["time_warp"])
		var equipped = SaveManager.get_value("equipped_ability", "time_warp")
		for key in ABILITIES.keys():
			var info = ABILITIES[key]
			var is_unlocked = (key in unlocked)
			var is_equipped = (key == equipped)
			list_container.add_child(_create_ability_item(key, info, is_unlocked, is_equipped))
	elif current_tab == "passives":
		var grid = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		list_container.add_child(grid)
		
		var unlocked = SaveManager.get_value("unlocked_passives", [])
		var owned = SaveManager.get_value("owned_passives", [])
		for key in PASSIVES.keys():
			var info = PASSIVES[key]
			var is_unlocked = (key in unlocked)
			var is_owned = (key in owned)
			grid.add_child(_create_passive_item(key, info, is_unlocked, is_owned))

func _create_upgrade_item(u_id: String, info: Dictionary, level: int) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 120)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var vbox_text = VBoxContainer.new()
	vbox_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_text.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vbox_text)
	
	var name_lbl = Label.new()
	name_lbl.text = "%s (Lv %d/%d)" % [info.name, level, info.max_level]
	name_lbl.add_theme_font_size_override("font_size", 32)
	vbox_text.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = info.desc
	desc_lbl.add_theme_font_size_override("font_size", 20)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox_text.add_child(desc_lbl)
	
	var cost = int(info.base_cost * pow(info.cost_mult, level - 1))
	
	var price_lbl = Label.new()
	price_lbl.add_theme_font_size_override("font_size", 24)
	if level >= info.max_level:
		price_lbl.text = "MAX LEVEL"
		price_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		price_lbl.text = "%d Droplets" % cost
		price_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox_text.add_child(price_lbl)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(160, 80)
	btn.add_theme_font_size_override("font_size", 28)
	hbox.add_child(btn)
	
	if level >= info.max_level:
		btn.text = "MAXED"
		btn.disabled = true
	else:
		btn.text = "UPGRADE"
		btn.pressed.connect(func():
			var dr = ThemeManager.get_droplets()
			if dr >= cost:
				SaveManager.set_value("droplets", float(dr - cost))
				var ups = SaveManager.get_value("upgrades", {})
				ups[u_id] = level + 1
				SaveManager.set_value("upgrades", ups)
				AudioManager.play_sfx("power_up")
				_refresh_ui()
			else:
				AudioManager.play_sfx("miss")
		)
		
	return panel

func _create_ability_item(a_id: String, info: Dictionary, is_unlocked: bool, is_equipped: bool) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 140)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(100, 100)
	var icon_path = "res://assets/icons/icon_%s.jpg" % a_id
	var icon_tex = null
	
	if ResourceLoader.exists(icon_path):
		icon_tex = load(icon_path)
		
	if icon_tex == null:
		var img = Image.new()
		if img.load(icon_path) == OK:
			icon_tex = ImageTexture.create_from_image(img)
			
	if icon_tex != null:
		preview.texture = icon_tex
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(preview)
	
	var sp1 = Control.new()
	sp1.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(sp1)
	
	var vbox_text = VBoxContainer.new()
	vbox_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_text.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(vbox_text)
	
	var name_lbl = Label.new()
	name_lbl.text = info.name
	name_lbl.add_theme_font_size_override("font_size", 32)
	vbox_text.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = info.desc
	desc_lbl.add_theme_font_size_override("font_size", 20)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox_text.add_child(desc_lbl)
	
	var price_lbl = Label.new()
	price_lbl.add_theme_font_size_override("font_size", 24)
	if is_unlocked:
		price_lbl.text = "Unlocked"
		price_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		price_lbl.text = "%d Droplets" % info.cost
		price_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox_text.add_child(price_lbl)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(160, 80)
	btn.add_theme_font_size_override("font_size", 28)
	hbox.add_child(btn)
	
	if is_equipped:
		btn.text = "EQUIPPED"
		btn.disabled = true
	elif is_unlocked:
		btn.text = "EQUIP"
		btn.pressed.connect(func():
			AudioManager.play_sfx("button")
			SaveManager.set_value("equipped_ability", a_id)
			_refresh_ui()
		)
	else:
		btn.text = "UNLOCK"
		btn.pressed.connect(func():
			var dr = ThemeManager.get_droplets()
			if dr >= info.cost:
				SaveManager.set_value("droplets", float(dr - info.cost))
				var unl = SaveManager.get_value("unlocked_abilities", ["time_warp"])
				unl.append(a_id)
				SaveManager.set_value("unlocked_abilities", unl)
				SaveManager.set_value("equipped_ability", a_id)
				AudioManager.play_sfx("power_up")
				_refresh_ui()
			else:
				AudioManager.play_sfx("miss")
		)
		
	return panel

func _create_passive_item(p_id: String, info: Dictionary, is_unlocked: bool, is_owned: bool) -> Control:
	var margin_wrap = MarginContainer.new()
	margin_wrap.add_theme_constant_override("margin_left", 20)
	margin_wrap.add_theme_constant_override("margin_right", 20)
	margin_wrap.add_theme_constant_override("margin_top", 15)
	margin_wrap.add_theme_constant_override("margin_bottom", 25)
	
	var card_base = Control.new()
	card_base.custom_minimum_size = Vector2(300, 480)
	card_base.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin_wrap.add_child(card_base)
	
	# Drop shadow behind the shader card
	var shadow = Panel.new()
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shadow_style = StyleBoxFlat.new()
	shadow_style.bg_color = Color(0,0,0,0)
	shadow_style.shadow_color = Color(0.1, 0.7, 1.0, 0.4)
	shadow_style.shadow_size = 35
	shadow_style.corner_radius_top_left = 25
	shadow_style.corner_radius_top_right = 25
	shadow_style.corner_radius_bottom_left = 25
	shadow_style.corner_radius_bottom_right = 25
	shadow.add_theme_stylebox_override("panel", shadow_style)
	card_base.add_child(shadow)
	
	# The incredibly detailed AI-like shader background
	var shader_bg = ColorRect.new()
	shader_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var smat = ShaderMaterial.new()
	smat.shader = load("res://assets/passives/electric_card.gdshader")
	shader_bg.material = smat
	card_base.add_child(shader_bg)
	
	if not is_unlocked:
		smat.set_shader_parameter("line_color", Color(0.3, 0.3, 0.3, 0.7))
		smat.set_shader_parameter("bg_color", Color(0.04, 0.04, 0.05, 0.95))
		shadow_style.shadow_color = Color(0,0,0,0) # No shadow for locked
	elif is_owned:
		smat.set_shader_parameter("line_color", Color(0.2, 1.0, 0.4, 0.9))
		shadow_style.shadow_color = Color(0.1, 1.0, 0.2, 0.3)
	else:
		smat.set_shader_parameter("line_color", Color(0.15, 0.9, 1.0, 0.9))
		
	var content_margin = MarginContainer.new()
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 15)
	content_margin.add_theme_constant_override("margin_right", 15)
	content_margin.add_theme_constant_override("margin_top", 15)
	content_margin.add_theme_constant_override("margin_bottom", 15)
	card_base.add_child(content_margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	content_margin.add_child(vbox)
	
	# Load the unique icon for each card
	var icon_path_png = "res://assets/passives/%s_icon.png" % p_id
	var icon_path_jpg = "res://assets/passives/%s_icon.jpg" % p_id
	var icon_tex = null
	
	if ResourceLoader.exists(icon_path_png):
		icon_tex = load(icon_path_png)
	elif ResourceLoader.exists(icon_path_jpg):
		icon_tex = load(icon_path_jpg)
		
	if icon_tex == null:
		var img = Image.new()
		if FileAccess.file_exists(icon_path_png) and img.load(icon_path_png) == OK:
			icon_tex = ImageTexture.create_from_image(img)
		elif FileAccess.file_exists(icon_path_jpg) and img.load(icon_path_jpg) == OK:
			icon_tex = ImageTexture.create_from_image(img)
			
	var preview_wrap = MarginContainer.new()
	preview_wrap.add_theme_constant_override("margin_top", 0)
	preview_wrap.add_theme_constant_override("margin_bottom", 0)
	vbox.add_child(preview_wrap)
	
	var preview = TextureRect.new()
	if icon_tex != null:
		preview.texture = icon_tex
	preview.custom_minimum_size = Vector2(220, 220)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# Additive blend mode removes the dark background from the DALL-E icon
	# and makes it glow naturally over the card's gradient!
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	preview.material = mat
	
	preview_wrap.add_child(preview)
	
	var name_lbl = Label.new()
	name_lbl.text = info.name
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	name_lbl.add_theme_color_override("font_shadow_color", Color(0.1, 0.6, 1.0, 0.5))
	vbox.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = info.desc
	desc_lbl.add_theme_font_size_override("font_size", 18)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	desc_lbl.custom_minimum_size = Vector2(0, 55)
	vbox.add_child(desc_lbl)
	
	var price_lbl = Label.new()
	price_lbl.add_theme_font_size_override("font_size", 24)
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_owned:
		price_lbl.text = "ACTIVE"
		price_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		price_lbl.add_theme_color_override("font_shadow_color", Color(0, 0.8, 0, 0.5))
	elif is_unlocked:
		price_lbl.text = "Buy: %d" % info.cost
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Shiny yellow droplet color
		price_lbl.add_theme_color_override("font_shadow_color", Color(0.8, 0.6, 0, 0.5))
	else:
		price_lbl.text = "LOCKED"
		price_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	vbox.add_child(price_lbl)
	
	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_base.add_child(btn)
	
	if not is_unlocked:
		card_base.modulate = Color(0.6, 0.6, 0.6, 0.9)
	elif is_owned:
		pass # Colors handled by shader parameters now
		
	if is_unlocked and not is_owned:
		btn.pressed.connect(func():
			var dr = ThemeManager.get_droplets()
			if dr >= info.cost:
				SaveManager.set_value("droplets", float(dr - info.cost))
				var owned_arr = SaveManager.get_value("owned_passives", [])
				owned_arr.append(p_id)
				SaveManager.set_value("owned_passives", owned_arr)
				AudioManager.play_sfx("power_up")
				_refresh_ui()
			else:
				AudioManager.play_sfx("miss")
		)
	elif not is_unlocked:
		btn.pressed.connect(func():
			AudioManager.play_sfx("miss")
		)
		
	return margin_wrap

func _on_debug_grant() -> void:
	var current = ThemeManager.get_droplets()
	SaveManager.set_value("droplets", float(current + 10000))
	_refresh_ui()

func _on_debug_reset() -> void:
	SaveManager.reset_to_default()
	SaveManager.save_data_to_disk()
	_refresh_ui()
