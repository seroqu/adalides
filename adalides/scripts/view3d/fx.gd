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
