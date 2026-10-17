class_name Deco
extends RefCounted
## Decorado compartido por la mesa del draft y el campo de batalla: sellos
## arcanos que giran, braseros con llamas y luz que parpadea, y motas de luz.


## Gira los sellos y hace parpadear los braseros; llamar desde _process.
static func animate(sigils: Array[Node3D], flames: Array[OmniLight3D], time: float, delta: float) -> void:
	for i in sigils.size():
		sigils[i].rotation.y += delta * (0.25 if i % 2 == 0 else -0.18)
	for i in flames.size():
		flames[i].light_energy = 1.6 + sin(time * 9.0 + i * 1.7) * 0.35 + sin(time * 23.0 + i) * 0.15


## Motas de luz que flotan en una caja.
static func motes(parent: Node3D, pos: Vector3, extents: Vector3, color: Color, amount := 80) -> CPUParticles3D:
	var m := Fx.sprite_particles("star_05", color, amount, 6.0, 0.08, 0.2)
	m.position = pos
	m.preprocess = 6.0
	m.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	m.emission_box_extents = extents
	m.direction = Vector3.UP
	m.spread = 60
	m.initial_velocity_min = 0.08
	m.initial_velocity_max = 0.25
	m.gravity = Vector3(0, 0.03, 0)
	m.angular_velocity_min = -40
	m.angular_velocity_max = 40
	var ramp := Fx.ramp([[0, Color(1, 1, 1, 0)], [0.3, Color(1, 1, 1, 1)], [0.7, Color(1, 1, 1, 1)], [1, Color(1, 1, 1, 0)]])
	m.color_ramp = ramp
	parent.add_child(m)
	m.emitting = true
	return m


static func sigil_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/icons/rune_ring.svg")
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func sigil(parent: Node3D, pos: Vector3, size: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	m.rotation_degrees.x = -90
	m.material_override = sigil_material(color)
	pivot.add_child(m)
	parent.add_child(pivot)
	return pivot


static func brazier(parent: Node3D, pos: Vector3) -> OmniLight3D:
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.3
	cyl.height = 0.9
	base.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.2, 0.16, 0.12)
	bm.metallic = 0.5
	bm.roughness = 0.5
	base.material_override = bm
	base.position = pos + Vector3(0, 0.45, 0)
	parent.add_child(base)
	var bowl := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.42
	bc.bottom_radius = 0.2
	bc.height = 0.28
	bowl.mesh = bc
	var bwm := StandardMaterial3D.new()
	bwm.albedo_color = Color(0.55, 0.42, 0.18)
	bwm.metallic = 0.7
	bwm.roughness = 0.35
	bowl.material_override = bwm
	bowl.position = pos + Vector3(0, 1.0, 0)
	parent.add_child(bowl)
	var fire := Fx.sprite_particles("flame_05", Color(1, 0.5, 0.12), 30, 0.9, 0.25, 0.5)
	fire.position = pos + Vector3(0, 1.1, 0)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.18
	fire.direction = Vector3.UP
	fire.spread = 10
	fire.initial_velocity_min = 1.0
	fire.initial_velocity_max = 2.0
	fire.gravity = Vector3(0, 1.5, 0)
	fire.angle_min = -15
	fire.angle_max = 15
	fire.angular_velocity_min = -30
	fire.angular_velocity_max = 30
	var ramp := Fx.ramp([[0, Color(1, 0.95, 0.6, 1)], [0.4, Color(1, 0.5, 0.1, 0.9)], [1, Color(0.6, 0.1, 0.05, 0)]])
	fire.color_ramp = ramp
	parent.add_child(fire)
	fire.emitting = true
	var embers := Fx.sprite_particles("circle_05", Color(1, 0.7, 0.3), 16, 1.6, 0.06, 0.12)
	embers.position = pos + Vector3(0, 1.3, 0)
	embers.direction = Vector3.UP
	embers.spread = 35
	embers.initial_velocity_min = 0.8
	embers.initial_velocity_max = 1.8
	embers.gravity = Vector3(0, 0.6, 0)
	parent.add_child(embers)
	embers.emitting = true
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.6, 0)
	light.light_color = Color(1, 0.7, 0.35)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.shadow_enabled = false
	parent.add_child(light)
	return light


