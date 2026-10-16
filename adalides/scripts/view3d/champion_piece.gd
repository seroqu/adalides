class_name ChampionPiece
extends Node3D
## Ficha 3D de un campeón: base del color del elemento, anillo del bando,
## icono de arquetipo, icono de elemento, barra de vida con estela de daño
## y marcas de estado (❄ congelado, ◌ sigilo, ☠ maldito). Sin nombre: el
## color y el símbolo bastan.

const BAR_W := 0.7
const BAR_H := 0.09

var champion: Champion
var side: int = 0
var _base: MeshInstance3D
var _ring: MeshInstance3D
var _arch: Sprite3D
var _elem: Sprite3D
var _status: Label3D
var _bar_bg: MeshInstance3D
var _bar_ghost: MeshInstance3D
var _bar_fill: MeshInstance3D
var _fill_mat: StandardMaterial3D
var _shown_hp: int = -1
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _clips: Dictionary = {} # "idle" / "attack" / "hit" / "death" → nombre del clip


## Rutas candidatas del modelo 3D de una carta, de más específica a más genérica.
static func model_paths(data: ChampionData) -> PackedStringArray:
	var out: PackedStringArray = []
	out.append("res://assets/models/%s.glb" % data.id)
	if not data.hero:
		out.append("res://assets/models/%s.glb" % Icons.ARCHETYPE_FILES.get(data.archetype, ""))
	else:
		out.append("res://assets/models/%s.glb" % Icons.ARCHETYPE_FILES.get(data.archetype, ""))
	return out


## Carga el modelo GLB si existe y lo coloca sobre la base; si no, se queda el icono.
func _load_model() -> void:
	for path in model_paths(champion.data):
		if not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path)
		if scene == null:
			continue
		_model = scene.instantiate()
		_model.position.y = 0.16
		_model.rotation_degrees.y = 180 if side == 1 else 0 # Mira al rival.
		add_child(_model)
		_fit_model()
		_anim = _find_anim(_model)
		if _anim != null:
			for name in _anim.get_animation_list():
				var lower := String(name).to_lower()
				for key in ["idle", "attack", "hit", "death"]:
					if lower.contains(key) and not _clips.has(key):
						_clips[key] = name
			if not _clips.has("idle") and _anim.get_animation_list().size() > 0:
				_clips["idle"] = _anim.get_animation_list()[0]
			play_clip("idle", true)
		_arch.position.y = 1.35 # El icono sube para no tapar el modelo.
		_arch.pixel_size = 0.0026
		return


## Escala el modelo para que mida ~0.9 unidades de alto y quede centrado en la casilla.
func _fit_model() -> void:
	var aabb := _model_aabb(_model)
	if aabb.size.y <= 0.0:
		return
	var factor := 0.9 / aabb.size.y
	_model.scale = Vector3.ONE * factor
	_model.position = Vector3(-aabb.get_center().x * factor, 0.16 - aabb.position.y * factor, -aabb.get_center().z * factor)


func _model_aabb(node: Node) -> AABB:
	var total := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var box: AABB = mi.global_transform * mi.get_aabb()
		box = Transform3D(global_transform.affine_inverse()) * box
		total = box if first else total.merge(box)
		first = false
	return total


func _find_anim(node: Node) -> AnimationPlayer:
	for child in node.find_children("*", "AnimationPlayer", true, false):
		return child
	return null


func play_clip(key: String, loop := false) -> void:
	if _anim == null or not _clips.has(key):
		return
	var name: StringName = _clips[key]
	var anim := _anim.get_animation(name)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_anim.play(name)
	if not loop and _clips.has("idle"):
		_anim.animation_finished.connect(func(_n: StringName) -> void: play_clip("idle", true), CONNECT_ONE_SHOT)


func has_model() -> bool:
	return _model != null


func setup(ch: Champion, p_side: int) -> void:
	champion = ch
	side = p_side
	var color := Icons.color_of(ch.data)
	_base = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.36
	cyl.height = 0.16
	_base.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.25
	_base.material_override = mat
	_base.position.y = 0.08
	add_child(_base)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.36
	torus.outer_radius = 0.42
	_ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.3, 0.6, 1.0) if side == 0 else Color(1.0, 0.35, 0.3)
	rmat.emission_enabled = true
	rmat.emission = rmat.albedo_color * 0.6
	_ring.material_override = rmat
	_ring.position.y = 0.02
	add_child(_ring)
	_arch = Sprite3D.new()
	_arch.texture = Icons.archetype(ch.data.archetype)
	_arch.pixel_size = 0.0044
	_arch.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_arch.position.y = 0.5
	_arch.shaded = false
	add_child(_arch)
	if ch.data.element >= 0:
		_elem = Sprite3D.new()
		_elem.texture = Icons.element(ch.data.element)
		_elem.modulate = color
		_elem.pixel_size = 0.0022
		_elem.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_elem.position = Vector3(0.32, 0.78, 0)
		_elem.shaded = false
		add_child(_elem)
	# Barra de vida: fondo, estela (daño reciente) y relleno, ancladas a la izquierda.
	var border := Color(0.25, 0.55, 1.0) if side == 0 else Color(1.0, 0.3, 0.28)
	_bar_bg = _bar_quad(border, BAR_W + 0.08, BAR_H + 0.07, 0)
	var inner := _bar_quad(Color(0.05, 0.05, 0.08, 1.0), BAR_W + 0.02, BAR_H + 0.02, 1)
	inner.position.x -= 0.01
	_bar_ghost = _bar_quad(Color(1.0, 0.85, 0.3, 1.0), BAR_W, BAR_H, 2)
	_bar_fill = _bar_quad(Color(0.4, 0.9, 0.4, 1.0), BAR_W, BAR_H, 3)
	_fill_mat = _bar_fill.material_override
	_status = Label3D.new()
	_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status.pixel_size = 0.004
	_status.font_size = 40
	_status.outline_size = 10
	_status.no_depth_test = true
	_status.position.y = 1.32
	add_child(_status)
	_load_model()
	refresh()


## Barra anclada a la izquierda: el quad crece desde su origen (center_offset) y
## el origen se coloca medio ancho hacia +X, que con la cámara del juego es la
## izquierda de la pantalla.
func _bar_quad(color: Color, w: float, h: float, priority: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	quad.center_offset = Vector3(w / 2.0, 0, 0)
	m.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.no_depth_test = true
	mat.render_priority = priority
	m.material_override = mat
	m.position = Vector3(w / 2.0, 1.08, 0)
	add_child(m)
	return m


func _ratio(hp: int) -> float:
	return clampf(float(hp) / maxf(champion.max_hp(), 1), 0.0, 1.0)


func _fill_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.4, 0.9, 0.4)
	if ratio > 0.25:
		return Color(1.0, 0.8, 0.3)
	return Color(1.0, 0.35, 0.3)


## Muestra una vida concreta con animación: el relleno cae de golpe y la
## estela amarilla se consume después (efecto de pérdida de vida).
func show_hp(hp: int) -> void:
	var ratio := _ratio(hp)
	var old := _ratio(_shown_hp) if _shown_hp >= 0 else _ratio(champion.hp)
	_shown_hp = hp
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_bar_fill, "scale:x", maxf(ratio, 0.001), 0.12)
	tw.tween_property(_fill_mat, "albedo_color", _fill_color(ratio), 0.12)
	if ratio < old:
		_bar_ghost.scale.x = maxf(old, 0.001)
		tw.chain().tween_property(_bar_ghost, "scale:x", maxf(ratio, 0.001), 0.45).set_delay(0.35).set_trans(Tween.TRANS_SINE)
	else:
		_bar_ghost.scale.x = maxf(ratio, 0.001)
	_refresh_status()


func flash(color: Color) -> void:
	play_clip("hit")
	var mat: StandardMaterial3D = _base.material_override
	var original := Icons.color_of(champion.data)
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color", color, 0.08)
	tw.tween_property(mat, "albedo_color", original, 0.3)


func shake() -> void:
	var origin := position
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "position", origin + Vector3(0.08 if i % 2 == 0 else -0.08, 0, 0), 0.04)
	tw.tween_property(self, "position", origin, 0.04)


## Embestida hacia un punto y vuelta (ataque cuerpo a cuerpo).
func lunge(target: Vector3) -> Tween:
	play_clip("attack")
	var origin := position
	var toward := origin.lerp(target, 0.35)
	var tw := create_tween()
	tw.tween_property(self, "position", toward, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, 0.18).set_trans(Tween.TRANS_SINE)
	return tw


## Sincroniza la barra y las marcas con el estado real del campeón, sin animar.
func refresh() -> void:
	if champion == null:
		return
	_shown_hp = champion.hp
	var ratio := _ratio(champion.hp)
	_bar_fill.scale.x = maxf(ratio, 0.001)
	_bar_ghost.scale.x = maxf(ratio, 0.001)
	_fill_mat.albedo_color = _fill_color(ratio)
	_refresh_status()


func _refresh_status() -> void:
	var tags: PackedStringArray = []
	if champion.frozen > 0:
		tags.append("❄")
	if champion.stealth:
		tags.append("◌")
	if champion.cursed:
		tags.append("☠")
	_status.text = " ".join(tags)
	_arch.modulate = Color(1, 1, 1, 0.45) if champion.stealth else Color.WHITE
	if champion.frozen > 0:
		_arch.modulate = Color(0.6, 0.85, 1.0)
