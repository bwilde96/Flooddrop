extends Control

const UPGRADES = {
	"freeze_duration": {"name": "Freeze Duration", "desc": "Increases freeze time.", "base_cost": 100, "cost_mult": 1.5, "max_level": 5},
	"bomb_radius": {"name": "Bomb Radius", "desc": "Increases explosion size.", "base_cost": 100, "cost_mult": 1.5, "max_level": 5},
	"drain_amount": {"name": "Drain Power", "desc": "Increases flood drained.", "base_cost": 150, "cost_mult": 1.6, "max_level": 5},
	"shield_capacity": {"name": "Shield Capacity", "desc": "More hits absorbed.", "base_cost": 200, "cost_mult": 2.0, "max_level": 3}
}

const ABILITIES = {
	"time_warp": {"name": "Time Warp", "desc": "Slows time by 50% for 5s.", "cost": 0, "icon_path": "user://icon_time_warp_*.png"}, # Default
	"evaporation": {"name": "Evaporation", "desc": "Instantly drains 30% flood.", "cost": 1000, "icon_path": "user://icon_evaporation_*.png"},
	"tidal_wave": {"name": "Tidal Wave", "desc": "Wipes screen, scoring all.", "cost": 2000, "icon_path": "user://icon_tidal_wave_*.png"},
	"midas_touch": {"name": "Midas Touch", "desc": "8s of only Gold drops.", "cost": 3000, "icon_path": "user://icon_midas_touch_*.png"},
	"auto_turret": {"name": "Auto-Turret", "desc": "Auto-pops drops for 4s.", "cost": 4000, "icon_path": "user://icon_auto_turret_*.png"}
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
	btn_upg.custom_minimum_size = Vector2(250, 60)
	btn_upg.add_theme_font_size_override("font_size", 28)
	btn_upg.pressed.connect(func(): current_tab = "upgrades"; AudioManager.play_sfx("button"); _refresh_ui())
	tabs_container.add_child(btn_upg)
	
	var btn_abl = Button.new()
	btn_abl.text = "ABILITIES"
	btn_abl.custom_minimum_size = Vector2(250, 60)
	btn_abl.add_theme_font_size_override("font_size", 28)
	btn_abl.pressed.connect(func(): current_tab = "abilities"; AudioManager.play_sfx("button"); _refresh_ui())
	tabs_container.add_child(btn_abl)
	
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
	else:
		var unlocked = SaveManager.get_value("unlocked_abilities", ["time_warp"])
		var equipped = SaveManager.get_value("equipped_ability", "time_warp")
		for key in ABILITIES.keys():
			var info = ABILITIES[key]
			var is_unlocked = (key in unlocked)
			var is_equipped = (key == equipped)
			list_container.add_child(_create_ability_item(key, info, is_unlocked, is_equipped))

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
	var icon_tex = load(icon_path)
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

func _on_debug_grant() -> void:
	var current = ThemeManager.get_droplets()
	SaveManager.set_value("droplets", float(current + 10000))
	_refresh_ui()

func _on_debug_reset() -> void:
	SaveManager.reset_to_default()
	SaveManager.save_data_to_disk()
	_refresh_ui()
