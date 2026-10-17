class_name GameTheme
extends RefCounted
## Tema visual del juego: fuentes serif, paneles oscuros con borde dorado y
## botones con relieve. Se construye en código para no depender de .tres.

const GOLD := Color(0.85, 0.7, 0.32)
const GOLD_DIM := Color(0.55, 0.45, 0.22)
const PANEL := Color(0.07, 0.06, 0.11, 0.94)
const PANEL_LIGHT := Color(0.13, 0.11, 0.19)
const TEXT := Color(0.93, 0.9, 0.84)
const TEXT_DIM := Color(0.7, 0.67, 0.62)

static var _theme: Theme
static var body_font: Font
static var bold_font: Font
static var title_font: Font


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	body_font = load("res://assets/fonts/NotoSerif-Regular.ttf")
	bold_font = load("res://assets/fonts/NotoSerif-Bold.ttf")
	title_font = load("res://assets/fonts/NotoSerifDisplay-Black.ttf")
	var t := Theme.new()
	t.default_font = body_font
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", body_font)
	t.set_font_size("normal_font_size", "RichTextLabel", 13)
	# Paneles
	t.set_stylebox("panel", "PanelContainer", panel_style())
	var rich := panel_style()
	rich.bg_color = Color(0.03, 0.03, 0.06, 0.8)
	rich.border_color = GOLD_DIM
	rich.set_border_width_all(1)
	t.set_stylebox("normal", "RichTextLabel", rich)
	# Botones
	t.set_font("font", "Button", bold_font)
	t.set_font_size("font_size", "Button", 14)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.42, 0.4))
	t.set_stylebox("normal", "Button", button_style(PANEL_LIGHT, GOLD_DIM))
	t.set_stylebox("hover", "Button", button_style(PANEL_LIGHT.lightened(0.12), GOLD))
	t.set_stylebox("pressed", "Button", button_style(Color(0.25, 0.2, 0.1), GOLD))
	var off := button_style(Color(0.1, 0.06, 0.08), Color(0.6, 0.22, 0.2))
	off.set_border_width_all(1)
	t.set_stylebox("disabled", "Button", off)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	# Barras de scroll discretas
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = GOLD_DIM
	grabber.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber", "HScrollBar", grabber)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.3)
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("scroll", "HScrollBar", track)
	_theme = t
	return t


static func panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = GOLD_DIM
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(12)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	return s


static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


## Botón destacado (acción principal de la fase).
static func primary_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", button_style(Color(0.32, 0.24, 0.08), GOLD))
	b.add_theme_stylebox_override("hover", button_style(Color(0.42, 0.32, 0.12), Color(1, 0.85, 0.45)))
	b.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	b.add_theme_font_size_override("font_size", 15)


static func title(text: String, size := 22) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	return l


static func heading(text: String, size := 15) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", bold_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l
