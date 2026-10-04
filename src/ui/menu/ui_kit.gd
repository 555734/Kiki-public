class_name UiKit
extends RefCounted
## The menu's look, as widgets: headings, fields, buttons and the styles they
## wear. Shared by the start panel and the screens it opens (the purchase
## screen, versus), so they read as one place rather than bolted together.

static func heading(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = TranslationServer.translate(text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	var f := Art.font()
	if f != null:
		l.add_theme_font_override("font", f)
	return l

static func field(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = TranslationServer.translate(placeholder)
	e.custom_minimum_size = Vector2(0, 54)
	e.add_theme_font_size_override("font_size", 21)
	e.add_theme_color_override("font_color", Color("123f70"))
	e.add_theme_color_override("font_placeholder_color", Color("8aa5bc"))
	e.add_theme_stylebox_override("normal", control_style(Color("eaf4fb"), 0.94, 10))
	e.add_theme_stylebox_override("focus", control_style(Color("bce7fb"), 1.0, 10))
	return e

static func spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

## Deliberately large: this is a phone held sideways, and the first thing
## anyone touches should not need aiming.
static func action_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = TranslationServer.translate(text)
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color("064d92"))
	b.add_theme_stylebox_override("normal", control_style(Color("d9f1ff"), 0.96))
	b.add_theme_stylebox_override("hover", control_style(Color("86dcf4"), 1.0))
	b.add_theme_stylebox_override("pressed", control_style(Color("4ecbdc"), 1.0))
	var f := Art.font()
	if f != null:
		b.add_theme_font_override("font", f)
	b.pressed.connect(handler)
	return b

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.90)
	style.border_color = Color(0.50, 0.72, 0.88, 0.50)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.05, 0.30, 0.52, 0.20)
	style.shadow_size = 12
	return style

static func stage_style(colour: Color, alpha: float, radius: int, border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colour.r, colour.g, colour.b, alpha)
	style.border_color = colour
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = border
	style.content_margin_top = border
	style.content_margin_right = border
	style.content_margin_bottom = border
	style.shadow_color = Color(0.05, 0.30, 0.52, 0.22)
	style.shadow_size = 12
	return style

static func control_style(colour: Color, alpha: float, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(colour.r, colour.g, colour.b, alpha)
	style.border_color = Color(colour.r, colour.g, colour.b, minf(1.0, alpha + 0.35))
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style

## A soft vertical fade, used to sit writing on top of artwork without
## putting a hard edge across it. `top` flips it to darken the top instead,
## which is what keeps the ✓ readable over a bright sky.
static func scrim(height: int, top: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.012, 0.055, 0.115, 0.0))
	gradient.set_color(1, Color(0.012, 0.055, 0.115, 0.90 if not top else 0.42))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 64
	texture.fill_from = Vector2(0, 0) if not top else Vector2(0, 1)
	texture.fill_to = Vector2(0, 1) if not top else Vector2(0, 0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top:
		rect.set_anchors_preset(Control.PRESET_TOP_WIDE)
		rect.offset_top = 5
		rect.offset_bottom = float(height)
	else:
		rect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		rect.offset_top = -float(height)
		rect.offset_bottom = -5
	rect.offset_left = 5
	rect.offset_right = -5
	return rect
