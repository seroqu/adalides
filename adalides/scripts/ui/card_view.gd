class_name CardView
extends PanelContainer
## Tarjeta 2D de un campeón: banda de color del elemento con los iconos,
## nombre, ataque/vida/coste y poder. Emite `pressed` al pulsarla.

signal pressed
signal hovered(card_view: CardView)
signal unhovered(card_view: CardView)

var card: ChampionData
var champion: Champion
var disabled: bool = false:
	set(v):
		disabled = v
		modulate = Color(0.55, 0.55, 0.55) if v else Color.WHITE
		mouse_default_cursor_shape = Control.CURSOR_ARROW if v else Control.CURSOR_POINTING_HAND
var selected: bool = false:
	set(v):
		selected = v
		_apply_style()


func setup(p_card: ChampionData, p_champion: Champion = null, extra := "") -> void:
	card = p_card
	champion = p_champion
	custom_minimum_size = Vector2(156, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "%s\n%s" % [card.power.get("name", ""), card.power.get("text", "")]
	for c in get_children():
		c.queue_free()
	_apply_style()
	var color := Icons.color_of(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	# Banda superior con el color del elemento y los iconos.
	var band := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = color.darkened(0.25)
	bs.set_corner_radius_all(5)
	bs.set_content_margin_all(4)
	band.add_theme_stylebox_override("panel", bs)
	v.add_child(band)
	var head := HBoxContainer.new()
	band.add_child(head)
	for a in card.archetypes():
		var arch := TextureRect.new()
		arch.texture = Icons.archetype(a)
		arch.custom_minimum_size = Vector2(40, 40)
		arch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arch.modulate = Color(0.08, 0.06, 0.1)
		head.add_child(arch)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	if card.element >= 0:
		var elem := TextureRect.new()
		elem.texture = Icons.element(card.element)
		elem.custom_minimum_size = Vector2(34, 34)
		elem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		elem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		elem.modulate = Color(0.08, 0.06, 0.1)
		head.add_child(elem)
	else:
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 22)
		star.add_theme_color_override("font_color", Color(0.1, 0.05, 0.15))
		head.add_child(star)
	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.add_theme_font_override("font", GameTheme.bold_font)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(name_label)
	var atk := champion.attack() if champion != null else card.attack
	var hp := champion.max_hp() if champion != null else card.defense
	var stats := RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.fit_content = true
	stats.scroll_active = false
	stats.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	stats.add_theme_font_size_override("normal_font_size", 16)
	stats.add_theme_font_override("normal_font", GameTheme.bold_font)
	var copies := ""
	if champion != null and champion.copies > 1:
		copies = "  [color=#f0d080]x%d%s[/color]" % [champion.copies, " AFI %d" % champion.afi() if champion.afi() > 0 else ""]
	stats.text = "[color=#ff8a70]⚔ %d[/color]  [color=#7ee07e]♥ %d[/color]  [color=#9ecbff]◆ %d[/color]%s" % [atk, hp, card.cost, copies]
	v.add_child(stats)
	var power := Label.new()
	power.text = card.power.get("name", "")
	power.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
	power.add_theme_font_size_override("font_size", 13)
	power.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(power)
	if extra != "":
		var ex := Label.new()
		ex.name = "Extra"
		ex.text = extra
		ex.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		ex.add_theme_font_size_override("font_size", 12)
		ex.autowrap_mode = TextServer.AUTOWRAP_WORD
		v.add_child(ex)


## Cambia el texto pequeño de abajo sin reconstruir la carta.
func set_extra(text: String) -> void:
	var ex: Label = find_child("Extra", true, false)
	if ex != null:
		ex.text = text


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	var base := Icons.color_of(card) if card != null else Color.GRAY
	style.bg_color = Color(0.1, 0.09, 0.14)
	style.border_color = Color(0.45, 1.0, 0.55) if selected else base
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _ready() -> void:
	mouse_entered.connect(func() -> void: hovered.emit(self))
	mouse_exited.connect(func() -> void: unhovered.emit(self))
