extends Control
## The Gauntlet — challenge select + ability tree ("Powers").
## Premium procedural UI built from UIKit (electric cards, shader icons, neon buttons).

const UIKit = preload("res://scripts/ui/UIKit.gd")

const STAGE_TITLES := ["The Deluge", "The Bounce House", "The Furnace", "The Refinery",
	"The Vault", "The Dark Prism", "The Grid", "The Void"]
const STAGE_THEMES := ["water", "slime", "lava", "acid", "gold", "rainbow", "neon_plasma", "galaxy"]

var current_tab := "challenges"
var list: VBoxContainer
var tickets_chip: PanelContainer
var prisms_chip: PanelContainer
var cores_chip: PanelContainer
var droplets_chip: PanelContainer
var tabs_box: HBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Depth: dark vignette gradient over the animated menu background.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.01, 0.02, 0.05, 0.93))
	grad.set_color(1, Color(0.03, 0.05, 0.10, 0.80))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	var dim := TextureRect.new()
	dim.texture = gtex
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 14
	vbox.offset_right = -14
	vbox.offset_top = 10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# --- Header ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	var back := UIKit.neon_button("‹", Color(0.55, 0.9, 1.0), Vector2(64, 56), 32)
	back.pressed.connect(func():
		AudioManager.play_sfx("button")
		GameManager.goto_main_menu()
	)
	header.add_child(back)

	var title := UIKit.heading("THE GAUNTLET", 32, Color(0.62, 0.93, 1.0), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	tickets_chip = UIKit.chip(UIKit.ICON_TICKET, "0", 30, 25)
	header.add_child(tickets_chip)

	var buy_btn := UIKit.neon_button("+", UIKit.COL_TICKET, Vector2(52, 52), 28)
	buy_btn.tooltip_text = "Buy 1 ticket for %d prisms" % ChallengeManager.TICKET_PRISM_PRICE
	buy_btn.pressed.connect(func():
		if ChallengeManager.buy_ticket_with_prisms():
			AudioManager.play_sfx("power_up")
		else:
			AudioManager.play_sfx("miss")
		_refresh_header()
	)
	header.add_child(buy_btn)

	# --- Currency row ---
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 16)
	vbox.add_child(row2)
	prisms_chip = UIKit.chip(UIKit.ICON_PRISM, "0")
	cores_chip = UIKit.chip(UIKit.ICON_CORE, "0")
	droplets_chip = UIKit.chip(UIKit.ICON_DROPLET, "0")
	row2.add_child(prisms_chip)
	row2.add_child(cores_chip)
	row2.add_child(droplets_chip)

	# --- Tabs ---
	tabs_box = HBoxContainer.new()
	tabs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_box.add_theme_constant_override("separation", 16)
	vbox.add_child(tabs_box)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)

	get_tree().set_quit_on_go_back(false)
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameManager.goto_main_menu()

func _refresh_header() -> void:
	UIKit.set_chip_text(tickets_chip, str(ChallengeManager.get_tickets()))
	UIKit.set_chip_text(prisms_chip, str(ChallengeManager.get_prisms()))
	UIKit.set_chip_text(cores_chip, str(ChallengeManager.get_cores()))
	UIKit.set_chip_text(droplets_chip, str(ChallengeManager.get_droplets()))

func _rebuild_tabs() -> void:
	for c in tabs_box.get_children():
		c.queue_free()
	for t in [["challenges", "CHALLENGES"], ["powers", "POWERS"]]:
		var active: bool = current_tab == t[0]
		var b := UIKit.neon_button(t[1], Color(0.55, 0.9, 1.0), Vector2(230, 54), 24, active)
		if not active:
			b.pressed.connect(func():
				current_tab = t[0]
				AudioManager.play_sfx("button")
				_refresh()
			)
		tabs_box.add_child(b)

func _refresh() -> void:
	_refresh_header()
	_rebuild_tabs()
	for c in list.get_children():
		c.queue_free()
	if current_tab == "challenges":
		_build_challenges()
	else:
		_build_powers()
	UIKit.animate_in(list.get_children(), 0.05)

func _reward_chips(r: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if r.get("droplets", 0) > 0:
		h.add_child(UIKit.chip(UIKit.ICON_DROPLET, str(r.droplets), 20, 16))
	if r.get("cores", 0) > 0:
		h.add_child(UIKit.chip(UIKit.ICON_CORE, str(r.cores), 20, 16))
	if r.get("prisms", 0) > 0:
		h.add_child(UIKit.chip(UIKit.ICON_PRISM, str(r.prisms), 20, 16))
	return h

# ------------------------------------------------------------- CHALLENGES TAB --
func _build_challenges() -> void:
	for stage in range(STAGE_TITLES.size()):
		var t = ThemeManager.get_theme(STAGE_THEMES[stage])
		var unlocked = ChallengeManager.is_stage_unlocked(stage)
		var accent: Color = t.get("drop_color", Color.WHITE)
		if not unlocked:
			accent = Color(0.28, 0.30, 0.36)

		# The stage's own liquid pools at the bottom of its glass vessel —
		# and RISES as you clear its challenges (progress you can see).
		var defs_all: Array = ChallengeManager.get_stage_challenges(stage)
		var cleared: int = ChallengeManager.get_stage_cleared_count(stage)
		var fill := 0.035
		if unlocked:
			fill = 0.06 + 0.30 * (float(cleared) / maxf(1.0, float(defs_all.size())))
		var card := UIKit.LiquidPanel.new(accent, fill, 26.0, 16)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(card)

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		card.content.add_child(v)

		var head_row := HBoxContainer.new()
		head_row.add_theme_constant_override("separation", 10)
		v.add_child(head_row)
		var head := UIKit.heading(STAGE_TITLES[stage].to_upper(), 27,
			accent.lightened(0.25) if unlocked else Color(0.55, 0.55, 0.6))
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head_row.add_child(head)
		var sub := Label.new()
		sub.text = "STAGE %d · %s" % [stage + 1, str(t.get("name", "")).to_upper()]
		sub.add_theme_font_size_override("font_size", 16)
		sub.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
		head_row.add_child(sub)
		if unlocked:
			var prog := Label.new()
			prog.text = "%d/%d" % [cleared, defs_all.size()]
			prog.add_theme_font_override("font", UIKit.font_ui_bold(1))
			prog.add_theme_font_size_override("font_size", 18)
			prog.add_theme_color_override("font_color",
				UIKit.TEAL if cleared == defs_all.size() else accent.lightened(0.3))
			head_row.add_child(prog)

		if not unlocked:
			var lock := Label.new()
			lock.text = "Reach LEVEL %d in a run to open this gate" % (stage + 1)
			lock.add_theme_font_size_override("font_size", 19)
			lock.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
			v.add_child(lock)
			continue

		var defs: Array = ChallengeManager.get_stage_challenges(stage)
		for i in range(defs.size()):
			if i > 0:
				var sep := ColorRect.new()
				sep.custom_minimum_size = Vector2(0, 1)
				sep.color = Color(accent.r, accent.g, accent.b, 0.14)
				v.add_child(sep)
			v.add_child(_challenge_row(stage, i, defs[i], accent))

func _challenge_row(stage: int, index: int, def: Dictionary, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var open = ChallengeManager.is_challenge_unlocked(stage, index)
	var done = ChallengeManager.is_completed(stage, def.id)
	var is_boss: bool = def.get("is_boss", false)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	text.add_child(name_row)
	if is_boss:
		name_row.add_child(UIKit.tag("BOSS", Color(1.0, 0.45, 0.35)))
	if done:
		name_row.add_child(UIKit.tag("CLEARED", Color(0.35, 1.0, 0.55)))
	var name_l := Label.new()
	name_l.text = str(def.name).replace("⚔ ", "")
	name_l.add_theme_font_size_override("font_size", 23)
	name_l.add_theme_color_override("font_color",
		Color.WHITE if open else Color(0.5, 0.52, 0.58))
	name_row.add_child(name_l)

	var desc_l := Label.new()
	desc_l.text = str(def.desc) if open else "Clear the previous trial first"
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.add_theme_font_size_override("font_size", 16)
	desc_l.add_theme_color_override("font_color", Color(0.66, 0.71, 0.78))
	text.add_child(desc_l)

	if open and not done:
		var chips := _reward_chips(def.get("rewards", {}))
		text.add_child(chips)

	if not open:
		var lock_l := Label.new()
		lock_l.text = "🔒"
		lock_l.add_theme_font_size_override("font_size", 26)
		lock_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lock_l)
	else:
		var cost: int = ChallengeManager.get_attempt_cost(stage, def)
		var label := "PRACTICE" if done else "PLAY"
		var sub := "FREE" if cost == 0 else "1 TICKET"
		var btn := UIKit.neon_button("%s\n%s" % [label, sub], accent, Vector2(148, 76), 19, not done)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func(): _try_start(stage, def))
		row.add_child(btn)
	return row

func _try_start(stage: int, def: Dictionary) -> void:
	var cost: int = ChallengeManager.get_attempt_cost(stage, def)
	if cost > 0:
		if not ChallengeManager.spend_ticket():
			AudioManager.play_sfx("miss")
			UIKit.set_chip_text(tickets_chip, "0 — buy or wait!")
			return
	AudioManager.play_sfx("power_up")
	GameManager.challenge_ticket_spent = cost > 0
	GameManager.start_challenge(stage, def)

# ----------------------------------------------------------------- POWERS TAB --
func _build_powers() -> void:
	var info := Label.new()
	info.text = "Cores are earned by conquering challenges — power is earned, never bought."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Color(0.55, 0.85, 0.75))
	list.add_child(info)

	var unlocked_abilities: Array = SaveManager.get_value("unlocked_abilities", ["time_warp"])
	for ability in ChallengeManager.ABILITY_TREE.keys():
		var have: bool = ability in unlocked_abilities
		var accent := Color(0.3, 1.0, 0.8) if have else Color(0.28, 0.30, 0.36)
		var card := UIKit.LiquidPanel.new(accent, 0.10 if have else 0.04, 26.0, 16)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		card.content.add_child(v)

		var head_row := HBoxContainer.new()
		head_row.add_theme_constant_override("separation", 10)
		v.add_child(head_row)
		var head := UIKit.heading(ability.replace("_", " ").to_upper(), 25,
			accent.lightened(0.3) if have else Color(0.55, 0.55, 0.6))
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head_row.add_child(head)
		if not have:
			head_row.add_child(UIKit.tag("UNLOCK IN SHOP", Color(0.7, 0.7, 0.8)))

		var nodes: Array = ChallengeManager.ABILITY_TREE[ability]
		for i in range(nodes.size()):
			if i > 0:
				var sep := ColorRect.new()
				sep.custom_minimum_size = Vector2(0, 1)
				sep.color = Color(accent.r, accent.g, accent.b, 0.14)
				v.add_child(sep)
			v.add_child(_node_row(ability, i, nodes[i], have))

func _node_row(ability: String, index: int, node: Dictionary, ability_unlocked: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var owned = ChallengeManager.is_node_owned(ability, node.id)
	var open = ability_unlocked and ChallengeManager.is_node_unlockable(ability, index)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	text.add_child(name_row)
	if owned:
		name_row.add_child(UIKit.tag("OWNED", Color(0.35, 1.0, 0.55)))
	var name_l := Label.new()
	name_l.text = str(node.name)
	name_l.add_theme_font_size_override("font_size", 21)
	name_l.add_theme_color_override("font_color",
		Color(0.5, 1.0, 0.7) if owned else (Color.WHITE if open else Color(0.5, 0.52, 0.58)))
	name_row.add_child(name_l)

	var desc_l := Label.new()
	desc_l.text = str(node.desc)
	desc_l.add_theme_font_size_override("font_size", 16)
	desc_l.add_theme_color_override("font_color", Color(0.66, 0.71, 0.78))
	text.add_child(desc_l)

	if not owned:
		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 8)
		cost_row.add_child(UIKit.chip(UIKit.ICON_CORE, str(node.cost_cores), 18, 15))
		cost_row.add_child(UIKit.chip(UIKit.ICON_DROPLET, str(node.cost_droplets), 18, 15))
		text.add_child(cost_row)

	if owned:
		pass # tag already shows it
	elif not open:
		var lock_l := Label.new()
		lock_l.text = "🔒"
		lock_l.add_theme_font_size_override("font_size", 24)
		lock_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lock_l)
	else:
		var afford: bool = ChallengeManager.get_cores() >= node.cost_cores \
			and ChallengeManager.get_droplets() >= node.cost_droplets
		var btn := UIKit.neon_button("UNLOCK", Color(0.3, 1.0, 0.8), Vector2(140, 58), 19, afford)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func():
			if ChallengeManager.buy_node(ability, node.id):
				AudioManager.play_sfx("power_up")
			else:
				AudioManager.play_sfx("miss")
			_refresh()
		)
		row.add_child(btn)
	return row
