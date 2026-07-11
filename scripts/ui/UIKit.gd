## UIKit — shared premium-UI building blocks: shader-drawn currency icons, neon
## buttons, currency chips, and electric-bordered panels (same language as the
## Shop cards). Consumers: `const UIKit = preload("res://scripts/ui/UIKit.gd")`.

const ICON_TICKET := 0
const ICON_PRISM := 1
const ICON_CORE := 2
const ICON_DROPLET := 3

# --- Palette (docs/DESIGN_SYSTEM.md §2) ---
const INK_0 := Color("04070d")
const INK_1 := Color("0a101c")
const INK_2 := Color("121a2b")
const TEXT_HI := Color("f2f7ff")
const TEXT_MID := Color("9fb0c8")
const TEXT_LOW := Color("5c6b82")
const CYAN := Color("37e6ff")
const TEAL := Color("2effc4")
const GOLD := Color("ffc53d")
const VIOLET := Color("b879ff")
const CORAL := Color("ff5c4d")

const COL_TICKET := GOLD
const COL_PRISM := VIOLET
const COL_CORE := TEAL
const COL_DROPLET := Color(0.4, 0.75, 1.0)

# --- Fonts (runtime-loaded, import-independent; OFL licensed, bundled) ---
static var _f_display: FontFile = null
static var _f_ui: Dictionary = {} # weight name -> FontFile
static var _f_variations: Dictionary = {} # cache key -> FontVariation

static func _load_font(path: String) -> FontFile:
	var f := FontFile.new()
	f.load_dynamic_font(path)
	return f

static func font_display(spacing: int = 2) -> Font:
	if _f_display == null:
		_f_display = _load_font("res://assets/fonts/Audiowide-Regular.ttf")
	if spacing == 0:
		return _f_display
	return _variation(_f_display, "display", spacing)

static func _font_weight(weight: String) -> FontFile:
	if not _f_ui.has(weight):
		_f_ui[weight] = _load_font("res://assets/fonts/Rajdhani-%s.ttf" % weight)
	return _f_ui[weight]

static func font_ui() -> Font:
	return _font_weight("Medium")

static func font_ui_semibold(spacing: int = 0) -> Font:
	var f := _font_weight("SemiBold")
	return f if spacing == 0 else _variation(f, "sb", spacing)

static func font_ui_bold(spacing: int = 0) -> Font:
	var f := _font_weight("Bold")
	return f if spacing == 0 else _variation(f, "b", spacing)

static func _variation(base: Font, key: String, spacing: int) -> FontVariation:
	var cache_key := "%s_%d" % [key, spacing]
	if not _f_variations.has(cache_key):
		var v := FontVariation.new()
		v.base_font = base
		v.spacing_glyph = spacing
		_f_variations[cache_key] = v
	return _f_variations[cache_key]

const ICON_SHADER_CODE := "
shader_type canvas_item;
uniform int icon_type = 0; // 0 ticket, 1 prism, 2 core, 3 droplet
uniform vec4 tint : source_color = vec4(1.0);

float sd_rbox(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}
float sd_hex(vec2 p, float r) {
	const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
	p = abs(p);
	p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
	p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
	return length(p) * sign(p.y);
}
vec3 hue2rgb(float h) {
	return clamp(vec3(abs(h*6.0-3.0)-1.0, 2.0-abs(h*6.0-2.0), 2.0-abs(h*6.0-4.0)), 0.0, 1.0);
}

void fragment() {
	vec2 p = UV - 0.5;
	vec2 q = vec2(abs(p.x), p.y);
	float d = 1.0;
	vec3 col = tint.rgb;
	float extra = 0.0;

	if (icon_type == 0) { // TICKET: rounded stub with side notches + perforation
		d = sd_rbox(p, vec2(0.36, 0.235), 0.07);
		d = max(d, -(length(p - vec2(-0.37, 0.0)) - 0.085));
		d = max(d, -(length(p - vec2(0.37, 0.0)) - 0.085));
		float dash = step(0.55, fract(p.y * 9.0)) * step(abs(p.x + 0.14), 0.014) * step(abs(p.y), 0.18);
		extra -= dash * 0.55; // punched perforation reads darker
		float star = 1.0 - smoothstep(0.0, 0.16, length(p - vec2(0.09, 0.0)));
		extra += star * 0.5;
	} else if (icon_type == 1) { // PRISM: faceted kite, iridescent
		d = (abs(q.x) * 1.25 + abs(p.y) * 0.92) - 0.31;
		float hue = fract(p.y * 1.1 + q.x * 0.7 + TIME * 0.12);
		col = mix(tint.rgb, hue2rgb(hue), 0.55);
		float facet = step(0.0, sin((p.x + p.y) * 26.0));
		extra += facet * 0.14;
	} else if (icon_type == 2) { // CORE: hex ring + pulsing heart
		float h = sd_hex(p * 1.02, 0.30);
		d = min(abs(h) - 0.05, length(p) - (0.095 + 0.012 * sin(TIME * 2.2)));
	} else { // DROPLET: teardrop with a highlight
		float circ = length(p - vec2(0.0, 0.10)) - 0.23;
		float edge = q.x * 0.865 - (p.y + 0.36) * 0.5;
		float tri = max(edge, p.y - 0.02);
		d = min(circ, tri);
		float hl = 1.0 - smoothstep(0.0, 0.12, length(p - vec2(-0.08, 0.02)));
		extra += hl * 0.55;
	}

	float aa = fwidth(d) * 1.4 + 0.002;
	float fill = 1.0 - smoothstep(0.0, aa, d);
	float glow = exp(-max(d, 0.0) * 10.0) * 0.7;
	vec3 base = col * (1.0 + extra);
	base += vec3(0.30) * (0.35 - p.y) * fill; // soft top light
	float rim = 1.0 - smoothstep(0.0, 0.035, abs(d));
	vec3 final_col = base * fill + tint.rgb * glow + vec3(1.0) * rim * 0.30;
	COLOR = vec4(final_col, max(fill, glow * 0.85) * tint.a);
}
"

static var _icon_shader: Shader = null
static var _card_shader: Shader = null

static func icon(type: int, size: float = 30.0, tint: Color = Color.WHITE) -> ColorRect:
	if _icon_shader == null:
		_icon_shader = Shader.new()
		_icon_shader.code = ICON_SHADER_CODE
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _icon_shader
	m.set_shader_parameter("icon_type", type)
	m.set_shader_parameter("tint", tint)
	r.material = m
	r.color = Color.WHITE
	return r

static func icon_color(type: int) -> Color:
	match type:
		ICON_TICKET: return COL_TICKET
		ICON_PRISM: return COL_PRISM
		ICON_CORE: return COL_CORE
	return COL_DROPLET

## Pill chip: [icon] value — returns the panel; the Label is child "Value".
static func chip(icon_type: int, text: String, icon_size: float = 26.0, font_size: int = 22) -> PanelContainer:
	var tint := icon_color(icon_type)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.075, 0.125, 0.82)
	st.set_corner_radius_all(999) # full pill — droplet-round, per the liquid language
	st.set_border_width_all(1)
	st.border_color = Color(tint.r, tint.g, tint.b, 0.3)
	st.content_margin_left = 12
	st.content_margin_right = 14
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	panel.add_child(h)
	h.add_child(icon(icon_type, icon_size, tint))
	var l := Label.new()
	l.name = "Value"
	l.text = text
	l.add_theme_font_override("font", font_ui_semibold(1))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", tint.lightened(0.35))
	h.add_child(l)
	return panel

static func set_chip_text(chip_panel: PanelContainer, text: String) -> void:
	var l: Label = chip_panel.find_child("Value", true, false)
	if l: l.text = text

## Liquid Glass button (docs/DESIGN_SYSTEM.md): a glass capsule holding glowing
## accent liquid with a live waveline. filled=true -> nearly full (primary CTA);
## otherwise a low puddle. Pressing sloshes the fill.
static func neon_button(text: String, accent: Color, min_size: Vector2, font_size: int = 22, filled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	style_button(b, accent, filled)
	return b

## Apply the Liquid Glass look to any Button (scene-defined or new).
static func style_button(b: Button, accent: Color, filled: bool = false) -> void:
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 22
	pad.content_margin_right = 22
	pad.content_margin_top = 10
	pad.content_margin_bottom = 10
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, pad)
	b.add_theme_font_override("font", font_ui_semibold(2))
	var quiet_col := accent.lightened(0.5)
	b.add_theme_color_override("font_color", Color.WHITE if filled else quiet_col)
	b.add_theme_color_override("font_hover_color", Color.WHITE if filled else quiet_col.lightened(0.2))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", TEXT_LOW)

	# The vessel: a shader rect drawn behind the button's own text.
	if b.has_node("LiquidGlass"):
		b.get_node("LiquidGlass").queue_free()
	var rect := ColorRect.new()
	rect.name = "LiquidGlass"
	rect.show_behind_parent = true
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/ui/liquid_glass.gdshader")
	m.set_shader_parameter("accent", accent)
	m.set_shader_parameter("fill_level", 0.82 if filled else 0.16)
	m.set_shader_parameter("wave_amp", 2.2 if filled else 1.6)
	rect.material = m
	b.add_child(rect)

	var sync := func():
		m.set_shader_parameter("rect_size", b.size)
		m.set_shader_parameter("corner_radius", b.size.y * 0.5) # capsule
	b.resized.connect(sync)
	sync.call()

	# Fluid feedback: the liquid rises and brightens under the thumb.
	var base_fill := 0.82 if filled else 0.16
	b.button_down.connect(func():
		m.set_shader_parameter("brightness", 1.3)
		m.set_shader_parameter("fill_level", minf(1.0, base_fill + 0.14))
	)
	var release := func():
		m.set_shader_parameter("brightness", 1.0)
		m.set_shader_parameter("fill_level", base_fill)
	b.button_up.connect(release)
	b.mouse_exited.connect(release)

static func _legacy_style_button(b: Button, accent: Color, filled: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(14)
	normal.set_border_width_all(2)
	if filled:
		normal.bg_color = Color(accent.r * 0.32, accent.g * 0.32, accent.b * 0.32, 0.98)
		normal.border_color = accent
		normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.4)
		normal.shadow_size = 10
	else:
		normal.bg_color = Color(0.05, 0.07, 0.11, 0.95)
		normal.border_color = Color(accent.r, accent.g, accent.b, 0.65)
		normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
		normal.shadow_size = 6

	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	hover.shadow_size = normal.shadow_size + 4

	var pressed := normal.duplicate()
	pressed.bg_color = Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, 1.0)
	pressed.border_color = Color.WHITE

	var disabled := StyleBoxFlat.new()
	disabled.set_corner_radius_all(14)
	disabled.set_border_width_all(1)
	disabled.bg_color = Color(0.05, 0.06, 0.09, 0.85)
	disabled.border_color = Color(0.3, 0.32, 0.38, 0.5)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", font_ui_semibold(2))
	b.add_theme_color_override("font_color", accent.lightened(0.45))
	b.add_theme_color_override("font_hover_color", accent.lightened(0.6))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", TEXT_LOW)

## Electric card panel (the Shop-card shader). Put content in .content.
## A PanelContainer so its minimum size comes from the content (works in VBoxes);
## the shader rect is a sibling child, laid out to the same full rect behind it.
class ElectricPanel extends PanelContainer:
	var content: MarginContainer
	var _rect: ColorRect

	func _init(accent: Color, corner: float = 18.0, margin: int = 16) -> void:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_rect = ColorRect.new()
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = load("res://assets/passives/electric_card.gdshader")
		m.set_shader_parameter("line_color", accent)
		m.set_shader_parameter("bg_color", Color(0.035, 0.045, 0.075, 0.96))
		m.set_shader_parameter("corner_radius", corner)
		_rect.material = m
		add_child(_rect)

		content = MarginContainer.new()
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			content.add_theme_constant_override(side, margin)
		add_child(content)
		_rect.resized.connect(_sync_size)

	func _sync_size() -> void:
		if _rect and _rect.material:
			_rect.material.set_shader_parameter("rect_size", _rect.size)

	func set_accent(accent: Color) -> void:
		if _rect and _rect.material:
			_rect.material.set_shader_parameter("line_color", accent)

## display=true -> Audiowide (screen titles, big moments); else Rajdhani Bold caps.
## Liquid Glass panel: a glass vessel with the accent liquid pooled at the bottom.
## Use for menu sections and stage panels (electric cards stay for actual CARDS).
class LiquidPanel extends PanelContainer:
	var content: MarginContainer
	var _rect: ColorRect
	var _mat: ShaderMaterial

	func _init(accent: Color, fill: float = 0.13, corner: float = 26.0, margin: int = 16) -> void:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_rect = ColorRect.new()
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://assets/ui/liquid_glass.gdshader")
		_mat.set_shader_parameter("accent", accent)
		_mat.set_shader_parameter("fill_level", fill)
		_mat.set_shader_parameter("corner_radius", corner)
		_mat.set_shader_parameter("wave_amp", 2.8)
		_mat.set_shader_parameter("wave_speed", 0.6)
		_rect.material = _mat
		add_child(_rect)
		content = MarginContainer.new()
		for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			content.add_theme_constant_override(side, margin)
		add_child(content)
		_rect.resized.connect(func(): _mat.set_shader_parameter("rect_size", _rect.size))

	func set_accent(accent: Color) -> void:
		_mat.set_shader_parameter("accent", accent)

static func heading(text: String, font_size: int, color: Color, display: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_display(2) if display else font_ui_bold(3))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 8)
	return l

## Staggered entrance: fade + gentle scale pop (container-safe — no position tweens).
static func animate_in(nodes: Array, stagger: float = 0.05) -> void:
	for i in range(nodes.size()):
		var n = nodes[i]
		if not (n is Control): continue
		n.modulate.a = 0.0
		var tw: Tween = n.create_tween()
		tw.tween_interval(0.04 + i * stagger)
		tw.tween_callback(func():
			n.pivot_offset = n.size / 2.0
			n.scale = Vector2(0.94, 0.94)
		)
		tw.tween_property(n, "modulate:a", 1.0, 0.18)
		tw.parallel().tween_property(n, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Small filled tag pill, e.g. "BOSS".
static func tag(text: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.95)
	st.set_corner_radius_all(8)
	st.set_border_width_all(1)
	st.border_color = accent
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_ui_semibold(2))
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", accent.lightened(0.5))
	panel.add_child(l)
	return panel
