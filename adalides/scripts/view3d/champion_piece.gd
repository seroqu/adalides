class_name ChampionPiece
extends Node3D
## Ficha 3D de un campeón: base del color del elemento, icono de arquetipo,
## icono de elemento y etiqueta con nombre y vida. Todo mira a la cámara.

var champion: Champion
var side: int = 0
var _base: MeshInstance3D
var _ring: MeshInstance3D
var _arch: Sprite3D
var _elem: Sprite3D
var _label: Label3D


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
	_arch.pixel_size = 0.0040
	_arch.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_arch.position.y = 0.42
	_arch.shaded = false
	add_child(_arch)
	if ch.data.element >= 0:
		_elem = Sprite3D.new()
		_elem.texture = Icons.element(ch.data.element)
		_elem.modulate = color
		_elem.pixel_size = 0.0020
		_elem.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_elem.position = Vector3(0.3, 0.72, 0)
		_elem.shaded = false
		add_child(_elem)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0036
	_label.font_size = 46
	_label.outline_size = 12
	_label.position.y = 1.3
	_label.no_depth_test = true
	add_child(_label)
	refresh()


func refresh() -> void:
	if champion == null:
		return
	var tags: PackedStringArray = []
	if champion.frozen > 0:
		tags.append("❄")
	if champion.stealth:
		tags.append("◌")
	if champion.cursed:
		tags.append("☠")
	var name := champion.data.display_name.replace(" de ", "\nde ")
	_label.text = "%s\n%d/%d %s" % [name, champion.hp, champion.max_hp(), " ".join(tags)]
	_label.modulate = Color.WHITE if champion.alive else Color(0.5, 0.5, 0.5)
	var ratio := float(champion.hp) / maxf(champion.max_hp(), 1)
	_base.scale = Vector3(1, maxf(ratio, 0.2), 1)
	if champion.stealth:
		_arch.modulate = Color(1, 1, 1, 0.45)
	else:
		_arch.modulate = Color.WHITE
