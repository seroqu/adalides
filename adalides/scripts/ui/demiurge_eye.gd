class_name DemiurgeEye
extends Control
## El ojo del Demiurgo para el menú: párpados que parpadean, iris dorado con
## pupila vertical que sigue al ratón, halo violeta y rayos que laten. Dibujado
## en código, sin texturas.

var _t: float = 0.0
var _open: float = 1.0 # 1 = abierto, 0 = cerrado.
var _blink_at: float = 2.5
var _blinking: bool = false
var _look := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(220, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blink_at = 1.5 + randf() * 2.0


func _process(delta: float) -> void:
	_t += delta
	# Mirada: la pupila deriva hacia el ratón, despacio.
	var target := Vector2.ZERO
	var vp := get_viewport()
	if vp != null:
		var mouse := vp.get_mouse_position()
		var center := get_global_rect().get_center()
		target = ((mouse - center) / 500.0).limit_length(1.0)
	_look = _look.lerp(target, delta * 2.5)
	# Parpadeo.
	if not _blinking and _t >= _blink_at:
		_blinking = true
		var tw := create_tween()
		tw.tween_property(self, "_open", 0.05, 0.09).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "_open", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			_blinking = false
			_blink_at = _t + 2.0 + randf() * 3.5)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var w := size.x * 0.46
	var h := size.y * 0.34 * _open
	var pulse := 0.5 + 0.5 * sin(_t * 1.6)
	# Halo violeta y rayos que laten en la oscuridad.
	for i in 6:
		var r := w * (1.25 + i * 0.16) + pulse * 6.0
		draw_circle(c, r, Color(0.35, 0.12, 0.5, 0.11 - i * 0.016))
	var rays := 16
	for i in rays:
		var a := TAU * i / rays + _t * 0.15
		var len := w * (1.35 + 0.25 * sin(_t * 2.0 + i * 1.3))
		var from := c + Vector2(cos(a), sin(a)) * w * 1.05
		var to := c + Vector2(cos(a), sin(a)) * len
		draw_line(from, to, Color(0.85, 0.7, 0.32, 0.25 + 0.2 * pulse), 2.0, true)
	# Almendra del ojo (dos arcos) rellena de oscuridad.
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var x := -w + 2.0 * w * i / n
		var k := 1.0 - pow(absf(x) / w, 2.0)
		pts.append(c + Vector2(x, -h * k))
	for i in n + 1:
		var x := w - 2.0 * w * i / n
		var k := 1.0 - pow(absf(x) / w, 2.0)
		pts.append(c + Vector2(x, h * k))
	if h > 1.0:
		draw_colored_polygon(pts, Color(0.06, 0.04, 0.1))
		# Esclerótica oscura con brillo hacia el centro.
		for i in 5:
			var f := 1.0 - i * 0.18
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(c + (p - c) * f)
			draw_colored_polygon(inner, Color(0.14 + i * 0.03, 0.08 + i * 0.02, 0.2 + i * 0.03, 0.55))
	# Iris y pupila, recortados por la almendra con un clip aproximado (se dibujan dentro).
	var iris_r := minf(h * 0.95, w * 0.42)
	if iris_r > 2.0:
		var ic := c + _look * Vector2(w * 0.35, h * 0.3)
		draw_circle(ic, iris_r * 1.12, Color(0.45, 0.25, 0.08, 0.9))
		draw_circle(ic, iris_r, Color(0.85, 0.62, 0.2))
		for i in 24:
			var a := TAU * i / 24 + _t * 0.3
			draw_line(ic + Vector2(cos(a), sin(a)) * iris_r * 0.35, ic + Vector2(cos(a), sin(a)) * iris_r * 0.98,
				Color(0.55, 0.35, 0.1, 0.6), 1.5, true)
		draw_circle(ic, iris_r * 0.78, Color(0.95, 0.78, 0.35, 0.75))
		# Pupila vertical (rendija) que se estrecha con el pulso.
		var pw := iris_r * (0.22 + 0.08 * pulse)
		var ph := iris_r * 0.9
		var pupil := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24
			pupil.append(ic + Vector2(cos(a) * pw, sin(a) * ph))
		draw_colored_polygon(pupil, Color(0.03, 0.02, 0.05))
		draw_circle(ic + Vector2(-iris_r * 0.35, -iris_r * 0.4), iris_r * 0.16, Color(1, 0.97, 0.85, 0.85))
	# Párpados: borde dorado de la almendra.
	if pts.size() > 2:
		draw_polyline(pts, Color(0.85, 0.7, 0.32, 0.9), 3.0, true)
		draw_line(pts[0], pts[n], Color(0.85, 0.7, 0.32, 0.9), 3.0, true)
	# Pestañas.
	for i in 5:
		var x := -w * 0.7 + w * 1.4 * i / 4.0
		var k := 1.0 - pow(absf(x) / w, 2.0)
		var base := c + Vector2(x, -h * k)
		draw_line(base, base + Vector2(x * 0.08, -10.0 - 6.0 * k), Color(0.85, 0.7, 0.32, 0.8), 2.0, true)
