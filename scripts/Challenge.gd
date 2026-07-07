extends Control
## The Gauntlet — challenge select + ability tree ("Powers").
## UI is built in code (same pattern as Shop.gd's dynamic sections).

const STAGE_TITLES := ["The Deluge", "The Bounce House", "The Furnace", "The Refinery",
	"The Vault", "The Dark Prism", "The Grid", "The Void"]
const STAGE_THEMES := ["water", "slime", "lava", "acid", "gold", "rainbow", "neon_plasma", "galaxy"]

var current_tab := "challenges"
var list: VBoxContainer
var tickets_label: Label
var prisms_label: Label
var cores_label: Label
var droplets_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# --- Header: back, title, currencies ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	vbox.add_child(header)

	var back := Button.new()
	back.text = "  <  "
	back.add_theme_font_size_override("font_size", 30)
	back.pressed.connect(func():
		AudioManager.play_sfx("button")
		GameManager.goto_main_menu()
	)
	header.add_child(back)

	var title := Label.new()
	title.text = "THE GAUNTLET"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	tickets_label = _currency_label(Color(1.0, 0.85, 0.3))
	header.add_child(tickets_label)

	var buy_btn := Button.new()
	buy_btn.text = "+"
	buy_btn.tooltip_text = "Buy 1 ticket for %d prisms" % ChallengeManager.TICKET_PRISM_PRICE
	buy_btn.pressed.connect(func():
		if ChallengeManager.buy_ticket_with_prisms():
			AudioManager.play_sfx("power_up")
		else:
			AudioManager.play_sfx("miss")
		_refresh_header()
	)
	header.add_child(buy_btn)

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 26)
	vbox.add_child(row2)
	prisms_label = _currency_label(Color(0.8, 0.5, 1.0))
	cores_label = _currency_label(Color(0.3, 1.0, 0.8))
	droplets_label = _currency_label(Color(0.55, 0.8, 1.0))
	row2.add_child(prisms_label)
	row2.add_child(cores_label)
	row2.add_child(droplets_label)

	# --- Tabs ---
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 20)
	vbox.add_child(tabs)
	for t in [["challenges", "CHALLENGES"], ["powers", "POWERS"]]:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(220, 56)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(func():
			current_tab = t[0]
			AudioManager.play_sfx("button")
			_refresh()
		)
		tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	get_tree().set_quit_on_go_back(false)
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameManager.goto_main_menu()

func _currency_label(col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", col)
	return l

func _refresh_header() -> void:
	tickets_label.text = "🎟 %d" % ChallengeManager.get_tickets()
	prisms_label.text = "◆ %d Prisms" % ChallengeManager.get_prisms()
	cores_label.text = "⬡ %d Cores" % ChallengeManager.get_cores()
	droplets_label.text = "💧 %d" % ChallengeManager.get_droplets()

func _refresh() -> void:
	_refresh_header()
	for c in list.get_children():
		c.queue_free()
	if current_tab == "challenges":
		_build_challenges()
	else:
		_build_powers()

# ------------------------------------------------------------- CHALLENGES TAB --
func _build_challenges() -> void:
	for stage in range(STAGE_TITLES.size()):
		var t = ThemeManager.get_theme(STAGE_THEMES[stage])
		var unlocked = ChallengeManager.is_stage_unlocked(stage)

		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.07, 0.11, 0.92)
		style.set_corner_radius_all(14)
		style.set_border_width_all(2)
		var bcol: Color = t.get("drop_color", Color.WHITE)
		style.border_color = bcol if unlocked else Color(0.25, 0.25, 0.3)
		panel.add_theme_stylebox_override("panel", style)
		list.add_child(panel)

		var margin := MarginContainer.new()
		for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(m, 14)
		panel.add_child(margin)

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		margin.add_child(v)

		var head := Label.new()
		head.text = "STAGE %d — %s  ·  %s" % [stage + 1, str(t.get("name", "")).to_upper(), STAGE_TITLES[stage]]
		head.add_theme_font_size_override("font_size", 27)
		head.add_theme_color_override("font_color", bcol if unlocked else Color(0.5, 0.5, 0.55))
		v.add_child(head)

		if not unlocked:
			var lock := Label.new()
			lock.text = "🔒 Reach LEVEL %d in a run to unlock" % (stage + 1)
			lock.add_theme_font_size_override("font_size", 20)
			lock.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
			v.add_child(lock)
			continue

		var defs: Array = ChallengeManager.get_stage_challenges(stage)
		for i in range(defs.size()):
			v.add_child(_challenge_row(stage, i, defs[i], bcol))

func _challenge_row(stage: int, index: int, def: Dictionary, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var open = ChallengeManager.is_challenge_unlocked(stage, index)
	var done = ChallengeManager.is_completed(stage, def.id)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var name_l := Label.new()
	name_l.text = ("✓ " if done else "") + str(def.name)
	name_l.add_theme_font_size_override("font_size", 23)
	name_l.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.6) if done else (Color.WHITE if open else Color(0.5, 0.5, 0.55)))
	text.add_child(name_l)

	var desc_l := Label.new()
	desc_l.text = str(def.desc) if open else "Complete the previous challenge first"
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.add_theme_font_size_override("font_size", 17)
	desc_l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	text.add_child(desc_l)

	var r: Dictionary = def.get("rewards", {})
	var reward_l := Label.new()
	var bits: Array = ["💧%d" % r.get("droplets", 0), "⬡%d" % r.get("cores", 0)]
	if r.get("prisms", 0) > 0: bits.append("◆%d" % r.get("prisms", 0))
	reward_l.text = "First clear:  " + "  ".join(bits)
	reward_l.add_theme_font_size_override("font_size", 16)
	reward_l.add_theme_color_override("font_color", accent.lightened(0.2))
	text.add_child(reward_l)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 74)
	btn.add_theme_font_size_override("font_size", 21)
	if not open:
		btn.text = "🔒"
		btn.disabled = true
	else:
		var cost: int = ChallengeManager.get_attempt_cost(stage, def)
		if done:
			btn.text = "PRACTICE\nFREE"
		elif cost == 0:
			btn.text = "PLAY\nFREE TRY"
		else:
			btn.text = "PLAY\n1 🎟"
		btn.pressed.connect(func(): _try_start(stage, def))
	row.add_child(btn)
	return row

func _try_start(stage: int, def: Dictionary) -> void:
	var cost: int = ChallengeManager.get_attempt_cost(stage, def)
	if cost > 0:
		if not ChallengeManager.spend_ticket():
			AudioManager.play_sfx("miss")
			tickets_label.text = "🎟 0 — need tickets!"
			return
	AudioManager.play_sfx("power_up")
	GameManager.challenge_ticket_spent = cost > 0
	GameManager.start_challenge(stage, def)

# ----------------------------------------------------------------- POWERS TAB --
func _build_powers() -> void:
	var info := Label.new()
	info.text = "Cores (⬡) are earned by completing challenges — power is earned, never bought."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_color", Color(0.6, 0.9, 0.8))
	list.add_child(info)

	var unlocked_abilities: Array = SaveManager.get_value("unlocked_abilities", ["time_warp"])
	for ability in ChallengeManager.ABILITY_TREE.keys():
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.07, 0.11, 0.92)
		style.set_corner_radius_all(14)
		style.set_border_width_all(2)
		style.border_color = Color(0.3, 1.0, 0.8, 0.7) if ability in unlocked_abilities else Color(0.25, 0.25, 0.3)
		panel.add_theme_stylebox_override("panel", style)
		list.add_child(panel)

		var margin := MarginContainer.new()
		for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(m, 14)
		panel.add_child(margin)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		margin.add_child(v)

		var head := Label.new()
		head.text = ability.replace("_", " ").to_upper()
		head.add_theme_font_size_override("font_size", 25)
		v.add_child(head)

		var nodes: Array = ChallengeManager.ABILITY_TREE[ability]
		for i in range(nodes.size()):
			v.add_child(_node_row(ability, i, nodes[i], ability in unlocked_abilities))

func _node_row(ability: String, index: int, node: Dictionary, ability_unlocked: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var owned = ChallengeManager.is_node_owned(ability, node.id)
	var open = ability_unlocked and ChallengeManager.is_node_unlockable(ability, index)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_l := Label.new()
	name_l.text = ("✓ " if owned else "") + str(node.name) + " — " + str(node.desc)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 20)
	name_l.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.6) if owned else (Color.WHITE if open else Color(0.5, 0.5, 0.55)))
	text.add_child(name_l)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(170, 56)
	btn.add_theme_font_size_override("font_size", 18)
	if owned:
		btn.text = "OWNED"
		btn.disabled = true
	elif not open:
		btn.text = "🔒"
		btn.disabled = true
	else:
		btn.text = "⬡%d + 💧%d" % [node.cost_cores, node.cost_droplets]
		btn.pressed.connect(func():
			if ChallengeManager.buy_node(ability, node.id):
				AudioManager.play_sfx("power_up")
			else:
				AudioManager.play_sfx("miss")
			_refresh()
		)
	row.add_child(btn)
	return row
