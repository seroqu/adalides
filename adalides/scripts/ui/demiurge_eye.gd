class_name DemiurgeEye
extends Control
## El ojo del Demiurgo del menú, como en el vídeo de victoria: almendra dorada con
## rayos finos de distinta longitud, iris de anillos con runas, pupila oscura con
## rendija luminosa y brillo. Parpadea, late y mira hacia el ratón. Dibujado en código.

const GOLD := Color(0.86, 0.69, 0.32)
const GOLD_LIGHT := Color(0.98, 0.88, 0.6)
const GOLD_PALE := Color(0.99, 0.95, 0.8)
const DARK := Color(0.08, 0.05, 0.12)

var _t: float = 0.0
var _open: float = 1.0 # 1 = abierto, 0 = cerrado.
var _blink_at: float = 2.5
var _blinking: bool = false
var _look := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(300, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blink_at = 1.5 + randf() * 2.0


func _process(delta: float) -> void:
	_t += delta
	var target := Vector2.ZERO
	var vp := get_viewport()
	if vp != null:
		var mouse := vp.get_mouse_position()
		var center := get_global_rect().get_center()
		target = ((mouse - center) / 600.0).limit_length(1.0)
	_look = _look.lerp(target, delta * 2.5)
	if not _blinking and _t >= _blink_at:
		_blinking = true
		var tw := create_tween()
		tw.tween_property(self, "_open", 0.04, 0.09).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "_open", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void:
			_blinking = false
			_blink_at = _t + 2.5 + randf() * 4.0)
	queue_redraw()


## Contorno de la almendra: dos arcos simétricos, con las puntas afiladas.
func _almond(c: Vector2, w: float, h: float, n := 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var x := -w + 2.0 * w * i / n
		var k := 1.0 - pow(absf(x) / w, 1.6)
		pts.append(c + Vector2(x, -h * k))
	for i in n + 1:
		var x := w - 2.0 * w * i / n
		var k := 1.0 - pow(absf(x) / w, 1.6)
		pts.append(c + Vector2(x, h * k))
	return pts


## ¿Está el punto dentro de la almendra (párpados)?
func _inside(p: Vector2, c: Vector2, w: float, h: float) -> bool:
	var x := absf(p.x - c.x)
	if x >= w:
		return false
	return absf(p.y - c.y) <= h * (1.0 - pow(x / w, 1.6))


## Circunferencia recortada por los párpados.
func _ring_clipped(ic: Vector2, radius: float, width: float, color: Color, c: Vector2, w: float, h: float) -> void:
	var n := 96
	var prev := Vector2.ZERO
	var prev_in := false
	for i in n + 1:
		var a := TAU * i / n
		var p := ic + Vector2(cos(a), sin(a)) * radius
		var now_in := _inside(p, c, w, h)
		if i > 0 and prev_in and now_in:
			draw_line(prev, p, color, width, true)
		prev = p
		prev_in = now_in


## Disco recortado por los párpados (abanico de triángulos desde el centro).
func _disc_clipped(ic: Vector2, radius: float, color: Color, c: Vector2, w: float, h: float) -> void:
	var n := 72
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var p := ic + Vector2(cos(a), sin(a)) * radius
		if not _inside(p, c, w, h):
			# Acorta el radio hasta el párpado.
			var lo := 0.0
			var hi := radius
			for _k in 12:
				var mid := (lo + hi) / 2.0
				if _inside(ic + Vector2(cos(a), sin(a)) * mid, c, w, h):
					lo = mid
				else:
					hi = mid
			p = ic + Vector2(cos(a), sin(a)) * lo
		pts.append(p)
	draw_colored_polygon(pts, color)


## Runa pseudoaleatoria (dos o tres trazos) centrada en un punto y orientada según un ángulo.
func _rune(p: Vector2, angle: float, size: float, color: Color, k: int) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var nrm := Vector2(-dir.y, dir.x)
	var s1 := 0.5 + 0.5 * sin(k * 2.3)
	var s2 := 0.5 + 0.5 * cos(k * 1.7)
	draw_line(p - nrm * size * 0.5, p + nrm * size * 0.5, color, 1.4, true)
	draw_line(p - nrm * size * (0.5 - s1 * 0.6), p + dir * size * 0.5 * (0.4 + s2 * 0.6), color, 1.2, true)
	if k % 3 == 0:
		draw_line(p + nrm * size * 0.1, p - dir * size * 0.45, color, 1.2, true)


func _draw() -> void:
	var c := size / 2.0 + Vector2(0, 4)
	var w := size.x * 0.36
	var h := size.y * 0.3 * _open
	var pulse := 0.5 + 0.5 * sin(_t * 1.4)
	# Halo violeta en la oscuridad.
	for i in 6:
		var r := w * (1.1 + i * 0.18) + pulse * 6.0
		draw_circle(c, r, Color(0.4, 0.14, 0.55, 0.12 - i * 0.017))
	# Rayos: muchos, finos, alternando largos y cortos; los largos llevan una punta de rombo.
	var rays := 56
	for i in rays:
		var a := TAU * i / rays - PI / 2.0 + sin(_t * 0.25) * 0.03
		var long := i % 2 == 0
		var cardinal := i % 14 == 0
		var base_len := w * (1.55 if long else 1.3)
		if cardinal:
			base_len = w * 1.9
		var len := base_len + w * 0.08 * sin(_t * 2.0 + i * 0.9)
		var d := Vector2(cos(a), sin(a))
		# Los rayos nacen del borde de la almendra (más cerca arriba y abajo).
		var ellipse := Vector2(w * 1.02, h * 1.9 + w * 0.2)
		var start := c + Vector2(d.x * ellipse.x, d.y * ellipse.y)
		var tip := c + d * len
		var alpha := 0.55 + 0.35 * pulse if long else 0.35 + 0.25 * pulse
		draw_line(start, tip, Color(GOLD.r, GOLD.g, GOLD.b, alpha), 2.2 if cardinal else 1.3, true)
		if long:
			var ds := 4.5 if cardinal else 3.0
			var nrm := Vector2(-d.y, d.x)
			var diamond := PackedVector2Array([tip - d * ds * 1.6, tip + nrm * ds, tip + d * ds * 1.6, tip - nrm * ds])
			draw_colored_polygon(diamond, Color(GOLD_LIGHT.r, GOLD_LIGHT.g, GOLD_LIGHT.b, alpha))
	if h < 1.0:
		# Cerrado: solo el párpado como línea.
		draw_line(c + Vector2(-w, 0), c + Vector2(w, 0), GOLD, 3.0, true)
		return
	# Almendra dorada con degradado hacia el centro.
	var pts := _almond(c, w, h)
	draw_colored_polygon(pts, Color(0.62, 0.45, 0.16))
	for i in 4:
		var f := 0.93 - i * 0.14
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(c + (p - c) * f)
		draw_colored_polygon(inner, Color(0.78 + i * 0.05, 0.6 + i * 0.07, 0.28 + i * 0.1, 0.9))
	# Iris grande recortado por los párpados: anillo oscuro con runas doradas, anillo dorado
	# con runas oscuras, centro negro con rendija luminosa (como el ojo del vídeo).
	var r := minf(h * 1.35, w * 0.46)
	var ic := c + _look * Vector2(w * 0.28, h * 0.2)
	_disc_clipped(ic, r, DARK, c, w, h)
	_ring_clipped(ic, r * 0.985, 1.5, GOLD, c, w, h)
	for k in 28:
		var a := TAU * k / 28 + _t * 0.06
		var p := ic + Vector2(cos(a), sin(a)) * r * 0.86
		if _inside(p, c, w, h):
			_rune(p, a, r * 0.14, GOLD_LIGHT, k)
	_disc_clipped(ic, r * 0.72, Color(0.8, 0.62, 0.26), c, w, h)
	_ring_clipped(ic, r * 0.72, 1.2, GOLD_PALE, c, w, h)
	for k in 18:
		var a := TAU * k / 18 - _t * 0.1
		var p := ic + Vector2(cos(a), sin(a)) * r * 0.6
		if _inside(p, c, w, h):
			_rune(p, a, r * 0.11, DARK, k + 7)
	_disc_clipped(ic, r * 0.47, DARK, c, w, h)
	_ring_clipped(ic, r * 0.47, 1.0, GOLD, c, w, h)
	# Rendija vertical que late como brasa.
	var sw := r * (0.07 + 0.03 * pulse)
	var sh := r * 0.38
	var slit := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20
		slit.append(ic + Vector2(cos(a) * sw, sin(a) * sh))
	draw_colored_polygon(slit, Color(1.0, 0.85, 0.45, 0.55 + 0.4 * pulse))
	draw_circle(ic + Vector2(r * 0.16, -r * 0.18), r * 0.09, Color(1, 0.98, 0.9, 0.9))
	# Párpado: borde grueso dorado de la almendra y un segundo trazo fino.
	draw_polyline(pts, GOLD, 4.0, true)
	var outer := PackedVector2Array()
	for p in pts:
		outer.append(c + (p - c) * 1.07)
	draw_polyline(outer, Color(GOLD.r, GOLD.g, GOLD.b, 0.5), 1.5, true)
	draw_line(pts[0], outer[0], GOLD, 2.0, true)
	draw_line(pts[48], outer[48], GOLD, 2.0, true)
