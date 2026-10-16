class_name CardView
extends PanelContainer
## Tarjeta 2D de un campeón: icono de arquetipo, icono de elemento, nombre,
## ataque/vida, coste y poder. Emite `pressed` al pulsarla.

signal pressed

var card: ChampionData
var champion: Champion
var disabled: bool = false:
	set(v):
		disabled = v
		modulate.a = 0.45 if v else 1.0
		mouse_default_cursor_shape = Control.CURSOR_ARROW if v else Control.CURSOR_POINTING_HAND
var selected: bool = false:
	set(v):
		selected = v
		_apply_style()


func setup(p_card: ChampionData, p_champion: Champion = null, extra := "") -> void:
	card = p_card
	champion = p_champion
	custom_minimum_size = Vector2(140, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "%s\n%s" % [card.power.get("name", ""), card.power.get("text", "")]
	for c in get_children():
		c.queue_free()
	_apply_style()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var arch := TextureRect.new()
	arch.texture = Icons.archetype(card.archetype)
	arch.custom_minimum_size = Vector2(36, 36)
	arch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(arch)
	if card.second_archetype >= 0:
		var arch2 := TextureRect.new()
		arch2.texture = Icons.archetype(card.second_archetype)
		arch2.custom_minimum_size = Vector2(36, 36)
		arch2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arch2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(arch2)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	if card.element >= 0:
		var elem := TextureRect.new()
		elem.texture = Icons.element(card.element)
		elem.modulate = Icons.ELEMENT_COLORS[card.element]
		elem.custom_minimum_size = Vector2(28, 28)
		elem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		elem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(elem)
	else:
		var star := Label.new()
		star.text = "★ Héroe"
		star.modulate = Icons.HERO_COLOR
		head.add_child(star)
	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(name_label)
	var atk := champion.attack() if champion != null else card.attack
	var hp := champion.max_hp() if champion != null else card.defense
	var stats := Label.new()
	var copies := ""
	if champion != null and champion.copies > 1:
		copies = "  x%d%s" % [champion.copies, " AFI %d" % champion.afi() if champion.afi() > 0 else ""]
	stats.text = "⚔ %d   ♥ %d   ◆ %d%s" % [atk, hp, card.cost, copies]
	v.add_child(stats)
	var power := Label.new()
	power.text = card.power.get("name", "")
	power.modulate = Color(0.8, 0.85, 1.0)
	power.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(power)
	if extra != "":
		var ex := Label.new()
		ex.text = extra
		ex.modulate = Color(0.75, 0.75, 0.75)
		v.add_child(ex)


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	var base := Icons.color_of(card) if card != null else Color.GRAY
	style.bg_color = base.darkened(0.72)
	style.border_color = base if selected else base.darkened(0.3)
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()
