class_name HandCard
extends Control
## Carta de la mano: la misma carta que hay sobre la mesa (marco teñido del
## elemento, retrato, elemento, coste, poder, ataque y vida), dibujada en 2D
## con la fuente nítida. Emite `pressed`, `hovered` y `unhovered`.

signal pressed
signal hovered(card: HandCard)
signal unhovered(card: HandCard)

const W := 150.0
const H := W * 720.0 / 512.0

var card: ChampionData
var champion: Champion
var extra: String = ""
var selected: bool = false:
	set(v):
		selected = v
		queue_redraw()
var disabled: bool = false:
	set(v):
		disabled = v
		modulate = Color(0.6, 0.6, 0.6) if v else Color.WHITE
var base_position := Vector2.ZERO # Pose en el abanico, para volver tras el hover.
var base_rotation: float = 0.0


func setup(p_card: ChampionData, p_champion: Champion = null, p_extra := "") -> void:
	card = p_card
	champion = p_champion
	extra = p_extra
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = Vector2(W / 2.0, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "%s\n%s" % [card.power.get("name", ""), card.power.get("text", "")]
	queue_redraw()


func set_extra(text: String) -> void:
	extra = text
	queue_redraw()


func _ready() -> void:
	mouse_entered.connect(func() -> void: hovered.emit(self))
	mouse_exited.connect(func() -> void: unhovered.emit(self))


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


## Punto de la textura de la carta (0..512 × 0..720) a píxeles del control.
func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y) * (W / 512.0)


func _text(pos: Vector2, text: String, size: int, color: Color, font: Font = null, align := HORIZONTAL_ALIGNMENT_CENTER, width := -1.0) -> void:
	var f := font if font != null else GameTheme.bold_font
	var w := width if width > 0 else W
	var origin := pos - Vector2(w / 2.0, 0) if align == HORIZONTAL_ALIGNMENT_CENTER else pos
	draw_string_outline(f, origin, text, align, w, size, int(maxi(2, size / 5)), Color(0, 0, 0, 0.85))
	draw_string(f, origin, text, align, w, size, color)


func _draw() -> void:
	if card == null:
		return
	var k := W / 512.0
	var color := Icons.color_of(card)
	# Marco teñido y sombra.
	draw_rect(Rect2(Vector2(3, 4), Vector2(W, H)), Color(0, 0, 0, 0.45))
	draw_texture_rect(Icons.card_frame(), Rect2(Vector2.ZERO, Vector2(W, H)), false, color)
	# Nombre (se reduce si no cabe).
	var name_size := 15
	while name_size > 9 and GameTheme.bold_font.get_string_size(card.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > 430 * k:
		name_size -= 1
	_text(_p(256, 78) + Vector2(0, name_size * 0.35), card.display_name, name_size, Color.WHITE)
	# Retrato: icono del arquetipo (y el segundo en los héroes).
	var portrait := 274.0 * k
	if card.second_archetype >= 0:
		var small := 214.0 * k
		draw_texture_rect(Icons.archetype(card.archetype), Rect2(_p(200, 305) - Vector2(small, small) / 2.0, Vector2(small, small)), false, color.lightened(0.15))
		draw_texture_rect(Icons.archetype(card.second_archetype), Rect2(_p(330, 305) - Vector2(small, small) / 2.0, Vector2(small, small)), false, color.lightened(0.15))
	else:
		draw_texture_rect(Icons.archetype(card.archetype), Rect2(_p(256, 305) - Vector2(portrait, portrait) / 2.0, Vector2(portrait, portrait)), false, color.lightened(0.15))
	# Elemento y coste.
	if card.element >= 0:
		var es := 113.0 * k
		draw_texture_rect(Icons.element(card.element), Rect2(_p(100, 418) - Vector2(es, es) / 2.0, Vector2(es, es)), false, Color.WHITE)
	else:
		_text(_p(118, 428), "★ Héroe", 9, Icons.HERO_COLOR)
	_text(_p(408, 428), "◆ %d" % card.cost, 12, Color(0.62, 0.8, 1.0))
	# Poder, ataque y vida (con las copias aplicadas).
	var power := String(card.power.get("name", ""))
	var ps := 9
	while ps > 6 and GameTheme.bold_font.get_string_size(power, HORIZONTAL_ALIGNMENT_LEFT, -1, ps).x > 420 * k:
		ps -= 1
	_text(_p(256, 616) + Vector2(0, ps * 0.35), power, ps, Color(1.0, 0.88, 0.6))
	var atk := champion.attack() if champion != null else card.attack
	var hp := champion.max_hp() if champion != null else card.defense
	_text(_p(118, 670), "⚔ %d" % atk, 13, Color(1, 0.55, 0.45))
	_text(_p(394, 670), "♥ %d" % hp, 13, Color(0.55, 0.9, 0.55))
	# Copias: chapa dorada en la esquina del retrato.
	if champion != null and champion.copies > 1:
		var label := "×%d" % champion.copies + (" AFI %d" % champion.afi() if champion.afi() > 0 else "")
		var tw := GameTheme.bold_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10
		var chip := Rect2(_p(454, 150) - Vector2(tw, 0), Vector2(tw, 16))
		draw_rect(chip, Color(0.12, 0.09, 0.05, 0.95))
		draw_rect(chip, GameTheme.GOLD, false, 1.0)
		_text(chip.position + Vector2(tw / 2.0, 12), label, 10, GameTheme.GOLD)
	# Nota (vender por…, en el tablero…) sobre el borde inferior.
	if extra != "":
		var er := Rect2(Vector2(10, H - 15), Vector2(W - 20, 13))
		draw_rect(er, Color(0.05, 0.04, 0.08, 0.85))
		_text(Vector2(W / 2.0, H - 5), extra, 8, GameTheme.TEXT_DIM)
	# Selección: borde verde que brilla.
	if selected:
		draw_rect(Rect2(Vector2(-3, -3), Vector2(W + 6, H + 6)), Color(0.45, 1.0, 0.55, 0.95), false, 3.0)
		draw_rect(Rect2(Vector2(-7, -7), Vector2(W + 14, H + 14)), Color(0.45, 1.0, 0.55, 0.35), false, 3.0)
