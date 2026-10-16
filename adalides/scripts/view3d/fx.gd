class_name Fx
extends RefCounted
## Efectos de batalla: estallidos de partículas, textos flotantes y destellos.


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
	var p := CPUParticles3D.new()
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.scale_amount_min = size
	p.scale_amount_max = size * 2.2
	p.color = color
	p.mesh = element_mesh(element)
	var mat := _unshaded(color)
	mat.no_depth_test = false
	p.mesh.surface_set_material(0, mat)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0))
	ramp.add_point(0.35, color)
	p.color_ramp = ramp
	match element:
		Rules.Element.FUEGO:
			p.lifetime = 0.75
			p.gravity = Vector3(0, 2.5, 0) # Las brasas suben.
			p.damping_min = 2.0
			p.damping_max = 4.0
		Rules.Element.HIELO:
			p.lifetime = 0.8
			p.gravity = Vector3(0, -9, 0)
			p.angular_velocity_min = -360
			p.angular_velocity_max = 360
		Rules.Element.TRUENO:
			p.lifetime = 0.35
			p.gravity = Vector3.ZERO
			p.particle_flag_align_y = true
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 9.0
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
		_:
			p.lifetime = 0.6
			p.gravity = Vector3(0, -5, 0)
	return p


## Destello plano que crece y se apaga (centro del impacto).
static func flash(parent: Node3D, pos: Vector3, color: Color, size := 1.4, duration := 0.22) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	m.mesh = q
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(color.r, color.g, color.b, 0))
	g.add_point(0.3, color)
	tex.gradient = g
	var mat := _unshaded(Color.WHITE)
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.material_override = mat
	m.position = pos
	m.scale = Vector3.ONE * 0.2
	parent.add_child(m)
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * size, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration).set_delay(duration * 0.3)
	tw.chain().tween_callback(m.queue_free)


## Tajo: una estela curva orientada a la cámara que cruza al objetivo.
static func slash(parent: Node3D, pos: Vector3, color: Color, angle_deg := -35.0) -> void:
	var cam := parent.get_viewport().get_camera_3d()
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 0.34)
	m.mesh = q
	var tex := GradientTexture2D.new()
	tex.fill_from = Vector2(0, 0.5)
	tex.fill_to = Vector2(1, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0))
	g.set_color(1, Color(color.r, color.g, color.b, 0))
	g.add_point(0.5, Color(1, 1, 1, 1))
	g.add_point(0.25, color)
	g.add_point(0.75, color)
	tex.gradient = g
	var mat := _unshaded(Color.WHITE)
	mat.albedo_texture = tex
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.material_override = mat
	parent.add_child(m)
	if cam != null:
		m.look_at_from_position(pos, cam.global_position, Vector3.UP)
	else:
		m.position = pos
	m.rotate_object_local(Vector3.FORWARD, deg_to_rad(angle_deg))
	m.scale = Vector3(0.1, 1.6, 1)
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(1.5, 0.8, 1), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.16).set_delay(0.08)
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
	var dust := CPUParticles3D.new()
	dust.position = pos + Vector3(0, 0.05, 0)
	dust.amount = 12
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.lifetime = 0.55
	dust.direction = Vector3.UP
	dust.spread = 80
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 2.2
	dust.gravity = Vector3(0, -1.5, 0)
	dust.scale_amount_min = 0.25
	dust.scale_amount_max = 0.45
	var dm := SphereMesh.new()
	dm.radius = 0.5
	dm.height = 1.0
	dm.radial_segments = 6
	dm.rings = 3
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.55, 0.45, 0.35, 0.5)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	dust.mesh = dm
	var dramp := Gradient.new()
	dramp.set_color(0, Color(1, 1, 1, 0.6))
	dramp.set_color(1, Color(1, 1, 1, 0))
	dust.color_ramp = dramp
	parent.add_child(dust)
	dust.emitting = true
	parent.get_tree().create_timer(1.0).timeout.connect(dust.queue_free)


## Nube de polvo bajo los pies al embestir.
static func dust_puff(parent: Node3D, pos: Vector3, dir: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.05, 0)
	p.amount = 8
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.direction = (-dir + Vector3.UP * 0.4).normalized()
	p.spread = 40
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -1, 0)
	p.scale_amount_min = 0.22
	p.scale_amount_max = 0.4
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.5, 0.4, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.5))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
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
	q.size = Vector2(1.1, 1.1)
	glow.mesh = q
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0.9))
	g.set_color(1, Color(color.r, color.g, color.b, 0))
	tex.gradient = g
	var gm := _unshaded(Color.WHITE)
	gm.albedo_texture = tex
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.material_override = gm
	node.add_child(glow)
	var trail := CPUParticles3D.new()
	trail.local_coords = false
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.08
	trail.direction = Vector3.UP
	trail.spread = 180
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.6
	trail.gravity = Vector3(0, 0.5, 0) if element == Rules.Element.FUEGO else Vector3.ZERO
	trail.scale_amount_min = 0.1
	trail.scale_amount_max = 0.2
	trail.amount = 60
	trail.lifetime = 0.45
	trail.mesh = element_mesh(element)
	var tmat := _unshaded(color)
	tmat.no_depth_test = false
	trail.mesh.surface_set_material(0, tmat)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0))
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
