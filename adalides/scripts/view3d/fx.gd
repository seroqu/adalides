class_name Fx
extends RefCounted
## Efectos de batalla: estallidos de partículas, textos flotantes y destellos.


static var _tex_cache := {}


## Degradado a partir de pares (offset, color); evita el lío de índices de Gradient.
static func ramp(points: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for p in points:
		offs.append(float(p[0]))
		cols.append(p[1])
	g.offsets = offs
	g.colors = cols
	return g


## Textura del paquete de partículas de Kenney (assets/particles).
static func tex(name: String) -> Texture2D:
	var path := name if name.begins_with("res://") else "res://assets/particles/%s.png" % name
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


## Material de sprite aditivo, teñible, para partículas y destellos.
static func sprite_material(name: String, color: Color, additive := true, billboard_particles := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex(name)
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if billboard_particles else BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	return mat


## Malla de partícula con sprite (quad de 1×1 con la textura indicada).
static func sprite_mesh(name: String, color: Color, additive := true) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = sprite_material(name, color, additive)
	return q


## Emisor continuo o de un disparo con sprites; quien llama lo coloca y lo enciende.
static func sprite_particles(name: String, color: Color, amount: int, lifetime: float, size_min: float, size_max: float, additive := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.mesh = sprite_mesh(name, color, additive)
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.angle_min = 0
	p.angle_max = 360
	var ramp := Fx.ramp([[0, Color(1, 1, 1, 0)], [0.15, Color(1, 1, 1, 1)], [1, Color(1, 1, 1, 0)]])
	p.color_ramp = ramp
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = sc
	return p


static func burst(parent: Node3D, pos: Vector3, color: Color, amount := 28, size := 0.08) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 70
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -4, 0)
	p.scale_amount_min = size
	p.scale_amount_max = size * 2
	p.color = color
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	p.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Anillo que se expande en el suelo (poderes de área, tiers).
static func ring(parent: Node3D, pos: Vector3, color: Color, radius := 1.2) -> void:
	var m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.38
	m.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos + Vector3(0, 0.08, 0)
	m.scale = Vector3(0.2, 1, 0.2)
	parent.add_child(m)
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(radius * 2.5, 1, radius * 2.5), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.chain().tween_callback(m.queue_free)


static func float_text(parent: Node3D, pos: Vector3, text: String, color: Color, size := 56) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 1.0, 0)
	parent.add_child(l)
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 2.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## Rayo entre dos puntos (ataques a distancia, poderes dirigidos).
static func beam(parent: Node3D, from: Vector3, to: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	var length := from.distance_to(to)
	box.size = Vector3(0.08, 0.08, length)
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 1.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	parent.add_child(m)
	var mid := (from + to) / 2.0 + Vector3(0, 0.5, 0)
	m.look_at_from_position(mid, to + Vector3(0, 0.5, 0), Vector3.UP)
	var tw := parent.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(m.queue_free)


# ---------------------------------------------------------------- ataques

static func _unshaded(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	return mat


## Malla de partícula según el elemento: brasas, esquirlas, chispas, rocas o jirones.
static func element_mesh(element: int) -> Mesh:
	match element:
		Rules.Element.HIELO:
			var p := PrismMesh.new()
			p.size = Vector3(0.5, 0.9, 0.3)
			return p
		Rules.Element.TRUENO:
			var b := BoxMesh.new()
			b.size = Vector3(0.12, 1.0, 0.12)
			return b
		Rules.Element.TIERRA:
			var c := BoxMesh.new()
			c.size = Vector3(0.6, 0.5, 0.6)
			return c
		_:
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 8
			s.rings = 4
			return s


static func _element_particles(element: int, color: Color, amount: int, size: float) -> CPUParticles3D:
	var name := "circle_05"
	match element:
		Rules.Element.FUEGO: name = "flame_05"
		Rules.Element.HIELO: name = "star_07"
		Rules.Element.TRUENO: name = "spark_04"
		Rules.Element.TIERRA: name = "dirt_02"
		Rules.Element.AIRE: name = "smoke_07"
		_: name = "star_05"
	var p := sprite_particles(name, color, amount, 0.6, size * 2.5, size * 5.0, element != Rules.Element.TIERRA)
	p.one_shot = true
	p.explosiveness = 1.0
	var ramp := Fx.ramp([[0, Color(1, 1, 1, 1)], [0.35, color], [1, Color(color.r, color.g, color.b, 0)]])
	p.color_ramp = ramp
	match element:
		Rules.Element.FUEGO:
			p.lifetime = 0.8
			p.gravity = Vector3(0, 2.5, 0) # Las llamas suben.
			p.damping_min = 2.0
			p.damping_max = 4.0
			p.angular_velocity_min = -90
			p.angular_velocity_max = 90
		Rules.Element.HIELO:
			p.lifetime = 0.8
			p.gravity = Vector3(0, -9, 0)
			p.angular_velocity_min = -360
			p.angular_velocity_max = 360
		Rules.Element.TRUENO:
			p.lifetime = 0.35
			p.gravity = Vector3.ZERO
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 9.0
			p.angular_velocity_min = -720
			p.angular_velocity_max = 720
		Rules.Element.TIERRA:
			p.lifetime = 0.8
			p.gravity = Vector3(0, -14, 0)
			p.angular_velocity_min = -200
			p.angular_velocity_max = 200
		Rules.Element.AIRE:
			p.lifetime = 0.9
			p.gravity = Vector3(0, 1.0, 0)
			p.damping_min = 3.0
			p.damping_max = 5.0
			p.spread = 180
			p.angular_velocity_min = -120
			p.angular_velocity_max = 120
		_:
			p.lifetime = 0.6
			p.gravity = Vector3(0, -5, 0)
	return p


## Destello plano que crece y se apaga (centro del impacto).
static func flash(parent: Node3D, pos: Vector3, color: Color, size := 1.4, duration := 0.22) -> void:
	for layer in [["light_01", 1.0, 0.0], ["circle_05", 0.7, 0.0], ["star_07", 1.3, 45.0]]:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		m.mesh = q
		var mat := sprite_material(layer[0], color if layer[0] != "circle_05" else Color.WHITE, true, false)
		mat.vertex_color_use_as_albedo = false
		mat.no_depth_test = true
		m.material_override = mat
		m.position = pos
		m.scale = Vector3.ONE * 0.2
		parent.add_child(m)
		var tw := parent.create_tween()
		tw.set_parallel(true)
		tw.tween_property(m, "scale", Vector3.ONE * size * float(layer[1]), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_delay(duration * 0.3)
		tw.chain().tween_callback(m.queue_free)


## Tajo: una estela curva orientada a la cámara que cruza al objetivo.
static func slash(parent: Node3D, pos: Vector3, color: Color, angle_deg := -35.0) -> void:
	var cam := parent.get_viewport().get_camera_3d()
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	m.mesh = q
	var mat := sprite_material("slash_02", Color.WHITE, true, false)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.vertex_color_use_as_albedo = false
	mat.albedo_color = color.lightened(0.35)
	mat.no_depth_test = true
	m.material_override = mat
	parent.add_child(m)
	if cam != null:
		m.look_at_from_position(pos, cam.global_position, Vector3.UP)
	else:
		m.position = pos
	m.rotate_object_local(Vector3.FORWARD, deg_to_rad(angle_deg))
	m.scale = Vector3(0.3, 0.3, 1)
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(1.2, 1.2, 1), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "rotation", m.rotation + m.basis.z * deg_to_rad(40.0 * signf(angle_deg)), 0.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18).set_delay(0.08)
	tw.chain().tween_callback(m.queue_free)


## Impacto: destello, chispas del elemento lanzadas en la dirección del golpe y polvo.
static func impact(parent: Node3D, pos: Vector3, color: Color, element: int, dir: Vector3, strength := 1.0) -> void:
	var center := pos + Vector3(0, 0.55, 0)
	flash(parent, center, color, 2.0 * strength)
	var p := _element_particles(element, color, int(34 * strength), 0.16)
	p.position = center
	var d := dir
	if d.length() < 0.01:
		d = Vector3.UP
	p.direction = (d + Vector3.UP * 0.6).normalized()
	p.spread = 45
	if p.initial_velocity_max == 1.0: # Valor por defecto: no lo fijó el elemento.
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.5
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)
	# Polvo en el suelo.
	var dust := sprite_particles("smoke_04", Color(0.75, 0.65, 0.55, 0.55), 10, 0.6, 0.35, 0.7, false)
	dust.position = pos + Vector3(0, 0.1, 0)
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.direction = Vector3.UP
	dust.spread = 80
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.2
	dust.gravity = Vector3(0, -1.0, 0)
	dust.angular_velocity_min = -60
	dust.angular_velocity_max = 60
	parent.add_child(dust)
	dust.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(dust.queue_free)


## Nube de polvo bajo los pies al embestir.
static func dust_puff(parent: Node3D, pos: Vector3, dir: Vector3) -> void:
	var p := sprite_particles("smoke_04", Color(0.75, 0.65, 0.55, 0.5), 8, 0.5, 0.3, 0.6, false)
	p.position = pos + Vector3(0, 0.1, 0)
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = (-dir + Vector3.UP * 0.4).normalized()
	p.spread = 40
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -0.8, 0)
	p.angular_velocity_min = -60
	p.angular_velocity_max = 60
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(0.9).timeout.connect(p.queue_free)


## Proyectil con estela que vuela del atacante al objetivo (arqueros en arco, magos recto).
## Devuelve al llegar; el impacto lo pone quien llama.
static func projectile(parent: Node3D, from: Vector3, to: Vector3, color: Color, element: int, arc: bool) -> void:
	var node := Node3D.new()
	var a := from + Vector3(0, 0.7, 0)
	var b := to + Vector3(0, 0.6, 0)
	node.position = a
	parent.add_child(node)
	var head := MeshInstance3D.new()
	head.mesh = element_mesh(element)
	head.scale = Vector3.ONE * 0.36
	head.material_override = _unshaded(color.lightened(0.3))
	node.add_child(head)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 1.2)
	glow.mesh = q
	var gm := sprite_material("circle_05", color, true, false)
	gm.vertex_color_use_as_albedo = false
	glow.material_override = gm
	node.add_child(glow)
	var trail_name := "flame_05" if element == Rules.Element.FUEGO else ("star_07" if element == Rules.Element.HIELO else "circle_05")
	var trail := sprite_particles(trail_name, color, 70, 0.5, 0.18, 0.4)
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.08
	trail.direction = Vector3.UP
	trail.spread = 180
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.6
	trail.gravity = Vector3(0, 0.8, 0) if element == Rules.Element.FUEGO else Vector3.ZERO
	var ramp := Fx.ramp([[0, Color(1, 1, 1, 1)], [1, Color(color.r, color.g, color.b, 0)]])
	trail.color_ramp = ramp
	node.add_child(trail)
	trail.emitting = true
	var dist := a.distance_to(b)
	var duration := clampf(0.08 * dist, 0.22, 0.4)
	var spin := head.create_tween()
	spin.set_loops()
	spin.tween_property(head, "rotation:y", TAU, 0.3).as_relative()
	var tw := parent.create_tween()
	var height := 1.4 if arc else 0.0
	tw.tween_method(func(t: float) -> void:
		var p := a.lerp(b, t)
		p.y += sin(t * PI) * height
		node.position = p, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE if arc else Tween.TRANS_LINEAR)
	await tw.finished
	head.visible = false
	glow.visible = false
	trail.emitting = false
	parent.get_tree().create_timer(0.5).timeout.connect(node.queue_free)


# ---------------------------------------------------------------- poderes y tiers

## Pilar de luz vertical que crece desde el suelo y se desvanece: dos haces
## cruzados con el resplandor radial estirado, más un núcleo fino.
static func pillar(parent: Node3D, pos: Vector3, color: Color, height := 2.6, width := 0.9, duration := 0.9) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var mats: Array[StandardMaterial3D] = []
	for layer in [[width, color, 0.55], [width * 0.35, color.lightened(0.6), 0.9]]:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		q.center_offset = Vector3(0, 0.42, 0)
		m.mesh = q
		var mat := sprite_material("light_01", layer[1], true, false)
		mat.vertex_color_use_as_albedo = false
		mat.albedo_color.a = layer[2]
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.billboard_keep_scale = true
		mat.no_depth_test = false
		m.material_override = mat
		m.scale = Vector3(0.1, 0.2, 1)
		root.add_child(m)
		mats.append(mat)
		var tw := parent.create_tween()
		tw.set_parallel(true)
		tw.tween_property(m, "scale", Vector3(layer[0], height, 1), duration * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(m, "scale", Vector3(layer[0] * 0.3, height * 1.2, 1), duration * 0.7).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, duration * 0.7)
	# Motas que ascienden por el haz.
	var motes := sprite_particles("star_05", color.lightened(0.3), 18, duration, 0.08, 0.16)
	motes.one_shot = true
	motes.explosiveness = 0.5
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = width * 0.3
	motes.direction = Vector3.UP
	motes.spread = 8
	motes.initial_velocity_min = height * 1.2
	motes.initial_velocity_max = height * 2.0
	motes.gravity = Vector3.ZERO
	root.add_child(motes)
	motes.emitting = true
	parent.get_tree().create_timer(duration + 0.5).timeout.connect(root.queue_free)


## Glifo mágico en el suelo que gira, crece y se apaga.
static func glyph_floor(parent: Node3D, pos: Vector3, color: Color, size := 1.6, duration := 1.0, name := "magic_03") -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	m.mesh = q
	var mat := sprite_material(name, color, true, false)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.vertex_color_use_as_albedo = false
	m.material_override = mat
	m.position = pos + Vector3(0, 0.07, 0)
	m.rotation_degrees = Vector3(-90, 0, 0)
	m.scale = Vector3.ONE * 0.2
	parent.add_child(m)
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * size, duration * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "rotation_degrees:y", 160.0, duration).as_relative()
	tw.tween_property(mat, "albedo_color:a", 0.0, duration * 0.5).set_delay(duration * 0.5)
	tw.chain().tween_callback(m.queue_free)


## Remolino de partículas del elemento que sube en espiral alrededor de un punto.
static func swirl(parent: Node3D, pos: Vector3, color: Color, element: int, amount := 40, duration := 0.9) -> void:
	var name := "circle_05"
	match element:
		Rules.Element.FUEGO: name = "flame_05"
		Rules.Element.HIELO: name = "star_07"
		Rules.Element.TRUENO: name = "spark_04"
		Rules.Element.TIERRA: name = "dirt_02"
		Rules.Element.AIRE: name = "smoke_07"
		_: name = "star_05"
	var p := sprite_particles(name, color, amount, duration, 0.14, 0.3, element != Rules.Element.TIERRA)
	p.position = pos + Vector3(0, 0.1, 0)
	p.one_shot = true
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_radius = 0.55
	p.emission_ring_inner_radius = 0.4
	p.emission_ring_height = 0.1
	p.emission_ring_axis = Vector3.UP
	p.direction = Vector3.UP
	p.spread = 10
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 2.6
	p.tangential_accel_min = 6.0
	p.tangential_accel_max = 9.0
	p.radial_accel_min = -1.0
	p.radial_accel_max = 0.5
	p.gravity = Vector3.ZERO
	p.angular_velocity_min = -180
	p.angular_velocity_max = 180
	var ramp := Fx.ramp([[0, Color(1, 1, 1, 1)], [0.4, color], [1, Color(color.r, color.g, color.b, 0)]])
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(duration + 0.4).timeout.connect(p.queue_free)


## Icono (elemento o arquetipo) que surge, crece y se eleva mirando a la cámara.
static func icon_rise(parent: Node3D, pos: Vector3, tex: Texture2D, color: Color, size := 0.0025, rise := 1.4, duration := 1.1) -> void:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = size
	s.modulate = Color(color.r, color.g, color.b, 0)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 5
	s.position = pos + Vector3(0, 0.6, 0)
	s.scale = Vector3.ONE * 0.3
	parent.add_child(s)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.8, 1.8)
	halo.mesh = q
	var hm := sprite_material("light_01", color, true, false)
	hm.vertex_color_use_as_albedo = false
	hm.no_depth_test = true
	halo.material_override = hm
	s.add_child(halo)
	halo.position.z = -0.01
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "modulate:a", 1.0, duration * 0.2)
	tw.tween_property(s, "scale", Vector3.ONE, duration * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", pos.y + 0.6 + rise, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tw.tween_property(hm, "albedo_color:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tw.chain().tween_callback(s.queue_free)


## Lluvia de partículas del elemento sobre una zona (tiers elementales).
static func rain(parent: Node3D, center: Vector3, extents: Vector3, color: Color, element: int, amount := 90) -> void:
	var p := _element_particles(element, color, amount, 0.16)
	p.position = center + Vector3(0, 2.6, 0)
	p.explosiveness = 0.3
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.DOWN
	p.spread = 15
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	if element == Rules.Element.FUEGO or element == Rules.Element.AIRE:
		p.gravity = Vector3(0, -2, 0)
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(1.8).timeout.connect(p.queue_free)


## Onda que recorre media mesa (tiers): un anillo plano que se expande muy ancho.
static func shockwave(parent: Node3D, pos: Vector3, color: Color, radius := 4.5, duration := 0.7) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	m.mesh = q
	var mat := sprite_material("circle_05", color, true, false)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.vertex_color_use_as_albedo = false
	m.material_override = mat
	m.position = pos + Vector3(0, 0.09, 0)
	m.rotation_degrees = Vector3(-90, 0, 0)
	m.scale = Vector3.ONE * 0.3
	parent.add_child(m)
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * radius * 2.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(m.queue_free)


## Escarcha: cristales que brotan alrededor y una bruma fría.
static func frost(parent: Node3D, pos: Vector3) -> void:
	var blue := Color(0.65, 0.88, 1.0)
	var crystals := sprite_particles("star_07", blue, 16, 1.2, 0.18, 0.38)
	crystals.position = pos + Vector3(0, 0.15, 0)
	crystals.one_shot = true
	crystals.explosiveness = 0.9
	crystals.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	crystals.emission_ring_radius = 0.42
	crystals.emission_ring_inner_radius = 0.2
	crystals.emission_ring_height = 0.05
	crystals.emission_ring_axis = Vector3.UP
	crystals.direction = Vector3.UP
	crystals.spread = 25
	crystals.initial_velocity_min = 0.4
	crystals.initial_velocity_max = 1.0
	crystals.gravity = Vector3(0, -0.6, 0)
	crystals.angular_velocity_min = -60
	crystals.angular_velocity_max = 60
	parent.add_child(crystals)
	crystals.emitting = true
	parent.get_tree().create_timer(1.8).timeout.connect(crystals.queue_free)
	var mist := sprite_particles("smoke_07", Color(0.7, 0.9, 1.0, 0.5), 10, 1.0, 0.5, 0.9, false)
	mist.position = pos + Vector3(0, 0.1, 0)
	mist.one_shot = true
	mist.explosiveness = 1.0
	mist.direction = Vector3.UP
	mist.spread = 60
	mist.initial_velocity_min = 0.3
	mist.initial_velocity_max = 0.8
	mist.gravity = Vector3.ZERO
	parent.add_child(mist)
	mist.emitting = true
	parent.get_tree().create_timer(1.6).timeout.connect(mist.queue_free)
	flash(parent, pos + Vector3(0, 0.5, 0), blue, 1.4, 0.3)


## Maldición: humo oscuro y símbolos violetas que orbitan.
static func curse(parent: Node3D, pos: Vector3) -> void:
	var purple := Color(0.75, 0.4, 1.0)
	var smoke := sprite_particles("smoke_04", Color(0.3, 0.1, 0.4, 0.75), 14, 1.1, 0.5, 0.9, false)
	smoke.position = pos + Vector3(0, 0.2, 0)
	smoke.one_shot = true
	smoke.explosiveness = 0.8
	smoke.direction = Vector3.UP
	smoke.spread = 45
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.2
	smoke.gravity = Vector3(0, 0.4, 0)
	parent.add_child(smoke)
	smoke.emitting = true
	parent.get_tree().create_timer(1.8).timeout.connect(smoke.queue_free)
	var runes := sprite_particles("symbol_01", purple, 14, 1.2, 0.16, 0.3)
	runes.position = pos + Vector3(0, 0.5, 0)
	runes.one_shot = true
	runes.explosiveness = 0.7
	runes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	runes.emission_ring_radius = 0.5
	runes.emission_ring_inner_radius = 0.45
	runes.emission_ring_height = 0.3
	runes.emission_ring_axis = Vector3.UP
	runes.direction = Vector3.UP
	runes.spread = 5
	runes.initial_velocity_min = 0.3
	runes.initial_velocity_max = 0.7
	runes.tangential_accel_min = 4.0
	runes.tangential_accel_max = 6.0
	runes.gravity = Vector3.ZERO
	parent.add_child(runes)
	runes.emitting = true
	parent.get_tree().create_timer(1.8).timeout.connect(runes.queue_free)
	glyph_floor(parent, pos, purple, 1.3, 1.0, "symbol_01")


## Esquiva: estela de imágenes fantasma del color dado.
static func afterimage(parent: Node3D, pos: Vector3, color: Color) -> void:
	for i in 3:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.1, 1.5)
		q.center_offset = Vector3(0, 0.55, 0)
		m.mesh = q
		var mat := sprite_material("light_01", color, true, false)
		mat.vertex_color_use_as_albedo = false
		mat.albedo_color.a = 0.9 - i * 0.25
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.material_override = mat
		m.position = pos + Vector3(-0.3 * i, 0.05, 0)
		parent.add_child(m)
		var tw := parent.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
		tw.tween_callback(m.queue_free)



# ---------------------------------------------------------------- muerte y victoria

## Muerte: estallido del color del campeón, humo oscuro, alma que asciende,
## marca quemada en el suelo que se desvanece y, si es tuyo, un icono ✖ rojo.
static func death(parent: Node3D, pos: Vector3, color: Color, mine: bool) -> void:
	flash(parent, pos + Vector3(0, 0.5, 0), color, 1.6, 0.3)
	shockwave(parent, pos, Color(0.2, 0.1, 0.25), 1.6, 0.6)
	var smoke := sprite_particles("smoke_04", Color(0.12, 0.08, 0.16, 0.85), 18, 1.4, 0.5, 1.0, false)
	smoke.position = pos + Vector3(0, 0.2, 0)
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.direction = Vector3.UP
	smoke.spread = 50
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.6
	smoke.gravity = Vector3(0, 0.5, 0)
	smoke.angular_velocity_min = -40
	smoke.angular_velocity_max = 40
	parent.add_child(smoke)
	smoke.emitting = true
	parent.get_tree().create_timer(2.2).timeout.connect(smoke.queue_free)
	# Alma: una luz que sube temblando y se apaga, con motas detrás.
	var soul := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	soul.mesh = q
	var sm := sprite_material("light_01", color.lightened(0.5), true, false)
	sm.vertex_color_use_as_albedo = false
	sm.no_depth_test = true
	soul.material_override = sm
	soul.position = pos + Vector3(0, 0.5, 0)
	soul.scale = Vector3.ONE * 0.3
	parent.add_child(soul)
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(soul, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float) -> void:
		soul.position = pos + Vector3(sin(t * 9.0) * 0.12, 0.5 + t * 2.2, 0), 0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(sm, "albedo_color:a", 0.0, 0.7).set_delay(0.9)
	tw.chain().tween_callback(soul.queue_free)
	var motes := sprite_particles("star_05", color.lightened(0.4), 24, 1.4, 0.07, 0.16)
	motes.position = pos + Vector3(0, 0.3, 0)
	motes.one_shot = true
	motes.explosiveness = 0.4
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 0.3
	motes.direction = Vector3.UP
	motes.spread = 20
	motes.initial_velocity_min = 1.0
	motes.initial_velocity_max = 2.0
	motes.gravity = Vector3.ZERO
	parent.add_child(motes)
	motes.emitting = true
	parent.get_tree().create_timer(2.0).timeout.connect(motes.queue_free)
	# Marca quemada en el suelo.
	var scorch := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(1.1, 1.1)
	scorch.mesh = sq
	var scm := sprite_material("scorch_01", Color(0.05, 0.03, 0.06, 0.9), false, false)
	scm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	scm.vertex_color_use_as_albedo = false
	scorch.material_override = scm
	scorch.position = pos + Vector3(0, 0.075, 0)
	scorch.rotation_degrees = Vector3(-90, randf() * 360.0, 0)
	parent.add_child(scorch)
	var stw := parent.create_tween()
	stw.tween_interval(2.5)
	stw.tween_property(scm, "albedo_color:a", 0.0, 2.0)
	stw.tween_callback(scorch.queue_free)
	if mine:
		float_text(parent, pos + Vector3(0, 0.3, 0), "✖", Color(1, 0.35, 0.3), 72)
	else:
		float_text(parent, pos + Vector3(0, 0.3, 0), "✖", Color(0.9, 0.9, 0.9), 56)


## Victoria: onda dorada, lluvia de estrellas sobre todo el campo y haces en las esquinas.
static func victory(parent: Node3D, center: Vector3, color: Color) -> void:
	shockwave(parent, center, color, 6.0, 1.0)
	glyph_floor(parent, center, Color(color.r, color.g, color.b, 0.8), 8.5, 2.4, "res://assets/icons/rune_ring.svg")
	var stars := sprite_particles("star_07", color, 160, 2.2, 0.12, 0.3)
	stars.position = center + Vector3(0, 4.0, 0)
	stars.one_shot = true
	stars.explosiveness = 0.35
	stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	stars.emission_box_extents = Vector3(3.5, 0.2, 4.0)
	stars.direction = Vector3.DOWN
	stars.spread = 20
	stars.initial_velocity_min = 0.6
	stars.initial_velocity_max = 1.6
	stars.gravity = Vector3(0, -1.6, 0)
	stars.angular_velocity_min = -180
	stars.angular_velocity_max = 180
	parent.add_child(stars)
	stars.emitting = true
	parent.get_tree().create_timer(3.0).timeout.connect(stars.queue_free)
	var sparks := sprite_particles("spark_04", Color(1, 0.95, 0.7), 90, 1.4, 0.15, 0.35)
	sparks.position = center + Vector3(0, 0.3, 0)
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sparks.emission_ring_radius = 3.5
	sparks.emission_ring_inner_radius = 3.3
	sparks.emission_ring_height = 0.1
	sparks.emission_ring_axis = Vector3.UP
	sparks.direction = Vector3.UP
	sparks.spread = 15
	sparks.initial_velocity_min = 5.0
	sparks.initial_velocity_max = 8.0
	sparks.gravity = Vector3(0, -6, 0)
	parent.add_child(sparks)
	sparks.emitting = true
	parent.get_tree().create_timer(2.0).timeout.connect(sparks.queue_free)


## Derrota: humo rojo oscuro que cubre tu mitad y ascuas que caen.
static func defeat(parent: Node3D, center: Vector3) -> void:
	var smoke := sprite_particles("smoke_07", Color(0.35, 0.05, 0.08, 0.8), 40, 2.4, 0.9, 1.6, false)
	smoke.position = center + Vector3(0, 0.2, 0)
	smoke.one_shot = true
	smoke.explosiveness = 0.5
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(3.0, 0.1, 1.6)
	smoke.direction = Vector3.UP
	smoke.spread = 30
	smoke.initial_velocity_min = 0.3
	smoke.initial_velocity_max = 0.8
	smoke.gravity = Vector3(0, 0.3, 0)
	smoke.angular_velocity_min = -20
	smoke.angular_velocity_max = 20
	parent.add_child(smoke)
	smoke.emitting = true
	parent.get_tree().create_timer(3.5).timeout.connect(smoke.queue_free)
	var ash := sprite_particles("circle_05", Color(1.0, 0.4, 0.2), 60, 2.5, 0.05, 0.12)
	ash.position = center + Vector3(0, 3.0, 0)
	ash.one_shot = true
	ash.explosiveness = 0.2
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(3.2, 0.2, 1.8)
	ash.direction = Vector3.DOWN
	ash.spread = 30
	ash.initial_velocity_min = 0.3
	ash.initial_velocity_max = 0.9
	ash.gravity = Vector3(0, -0.8, 0)
	parent.add_child(ash)
	ash.emitting = true
	parent.get_tree().create_timer(3.5).timeout.connect(ash.queue_free)



# ---------------------------------------------------------------- quién ataca a quién

## Línea de ataque a ras de suelo del atacante al objetivo, con punta de flecha,
## que se dibuja de origen a destino y se desvanece. Devuelve el nodo para borrarlo.
static func attack_line(parent: Node3D, from: Vector3, to: Vector3, color: Color, hold := 0.5) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var a := from + Vector3(0, 0.12, 0)
	var b := to + Vector3(0, 0.12, 0)
	var dir := (b - a)
	var length := dir.length()
	if length < 0.05:
		root.queue_free()
		return root
	dir = dir / length
	var head_len := 0.42
	var body_len := maxf(length - head_len - 0.35, 0.05)
	# Cuerpo: quad plano con un degradado que se "enciende" del atacante al objetivo.
	var line := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 1.0)
	q.center_offset = Vector3(0, 0.5, 0)
	line.mesh = q
	var tex := GradientTexture2D.new()
	tex.fill_from = Vector2(0.5, 1.0)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.gradient = ramp([[0, Color(color.r, color.g, color.b, 0.15)], [0.7, Color(color.r, color.g, color.b, 0.9)], [1, Color(1, 1, 1, 1)]])
	var mat := _unshaded(Color.WHITE)
	mat.albedo_texture = tex
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.no_depth_test = true
	line.material_override = mat
	line.position = a + dir * 0.35
	line.rotation_degrees.x = -90
	line.rotation.y = atan2(dir.x, dir.z)
	line.scale = Vector3(1, 0.01, 1)
	root.add_child(line)
	# Punta: triángulo plano.
	var tri := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(Vector3(-0.3, 0, 0))
	st.add_vertex(Vector3(0.3, 0, 0))
	st.add_vertex(Vector3(0, 0, head_len))
	st.add_vertex(Vector3(0.3, 0, 0))
	st.add_vertex(Vector3(-0.3, 0, 0))
	st.add_vertex(Vector3(0, 0, head_len))
	tri.mesh = st.commit()
	var tmat := _unshaded(color.lightened(0.3))
	tmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tmat.no_depth_test = true
	tri.material_override = tmat
	tri.position = b - dir * head_len
	tri.rotation.y = atan2(dir.x, dir.z)
	tri.scale = Vector3.ONE * 0.01
	root.add_child(tri)
	var tw := parent.create_tween()
	tw.tween_property(line, "scale:y", body_len, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(tri, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_property(tmat, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(root.queue_free)
	return root


## Mira pulsante en el suelo bajo el objetivo: anillo rotatorio del color del atacante.
static func target_marker(parent: Node3D, pos: Vector3, color: Color, duration := 0.9) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	m.mesh = q
	var mat := sprite_material("magic_03", color, true, false)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.vertex_color_use_as_albedo = false
	mat.no_depth_test = true
	m.material_override = mat
	m.position = pos + Vector3(0, 0.1, 0)
	m.rotation_degrees = Vector3(-90, 0, 0)
	m.scale = Vector3.ONE * 0.2
	parent.add_child(m)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.44
	torus.outer_radius = 0.5
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	var rmat := _unshaded(color.lightened(0.2))
	rmat.no_depth_test = true
	ring.material_override = rmat
	ring.position = pos + Vector3(0, 0.1, 0)
	ring.scale = Vector3.ONE * 1.6
	parent.add_child(ring)
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 1.3, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "rotation_degrees:y", 120.0, duration).as_relative()
	tw.chain().tween_interval(maxf(duration - 0.5, 0.0))
	tw.chain().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.parallel().tween_property(rmat, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(func() -> void:
		m.queue_free()
		ring.queue_free())
