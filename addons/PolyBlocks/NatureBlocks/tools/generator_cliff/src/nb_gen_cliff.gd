# POLYBLOCKS | NATUREBLOCKS | CLIFF GENERATOR TOOL
# bukkbeek.github.io

@tool
extends Node3D

@export_tool_button("Generate Cliffs") var generate_button: Callable = generate_cliffs
@export_tool_button("Clear Cliffs") var clear_button: Callable = clear_cliffs

@export var cliff_path: Path3D

@export_group("Cliff Setup")
@export var use_random_seed: bool = true
@export var random_seed: int = 12345
@export_range(1, 5000, 1) var cliff_amount: int = 50
@export var scale_min: float = 0.8
@export var scale_max: float = 1.2
@export_range(0.0, 360.0, 1.0) var rotation_variance_degrees: float = 360.0
@export var align_to_path_tangent: bool = false
@export var add_collision: bool = false

@export_group("Plain Setup")
@export var plain_height: float = 4.6

enum Biome {
	CANYON,
	CAVE,
	DESERT,
	GREY,
	ICE,
	MOSS,
	RIVER,
	SAND,
	SWAMP,
	VERDANT,
}
const BIOME_NAMES := {
	Biome.CANYON: "canyon",
	Biome.CAVE: "cave",
	Biome.DESERT: "desert",
	Biome.GREY: "grey",
	Biome.ICE: "ice",
	Biome.MOSS: "moss",
	Biome.RIVER: "river",
	Biome.SAND: "sand",
	Biome.SWAMP: "swamp",
	Biome.VERDANT: "verdant",
}

@export_group("Materials")
@export var cliff_material_biome: Biome = Biome.SWAMP
@export var plain_material_biome: Biome = Biome.MOSS


@export_group("Resource Paths")
@export_dir var materials_root_path: String = "res://PolyBlocks/NatureBlocks/source_files/materials/terrain"
var cliff_mesh_paths: Array[String] = [
	"res://PolyBlocks/NatureBlocks/tools/generator_cliff/src/nbmesh_cliff1.mesh",
	"res://PolyBlocks/NatureBlocks/tools/generator_cliff/src/nbmesh_cliff2.mesh",
	"res://PolyBlocks/NatureBlocks/tools/generator_cliff/src/nbmesh_cliff3.mesh",
	"res://PolyBlocks/NatureBlocks/tools/generator_cliff/src/nbmesh_cliff4.mesh",
	"res://PolyBlocks/NatureBlocks/tools/generator_cliff/src/nbmesh_cliff5.mesh",
]

const GENERATED_CLIFF_PREFIX := "nbgen_cliff_variant_"
const CLIFF_WALL_NODE_NAME := "CliffWall"
const PLAIN_NODE_NAME := "CliffPlain"
const COLLISION_NODE_NAME := "CliffCollision"

var _rng := RandomNumberGenerator.new()


func generate_cliffs() -> void:
	if cliff_path == null or not is_instance_valid(cliff_path):
		push_warning("CliffTool: Assign a Path3D node to 'Cliff Path' first.")
		return
	if cliff_path.curve == null or cliff_path.curve.get_point_count() < 3:
		push_warning("CliffTool: The assigned Path3D needs a closed Curve3D with at least 3 points.")
		return
	if cliff_mesh_paths.is_empty():
		push_warning("CliffTool: No cliff mesh paths assigned.")
		return
	if scale_min > scale_max:
		push_warning("CliffTool: scale_min is greater than scale_max.")
		return

	if use_random_seed:
		randomize()
		random_seed = randi()
	_rng.seed = random_seed

	clear_cliffs()

	var boundary_pts: Array = _sample_boundary()
	var base_y: float = _average_height(boundary_pts)
	var flip_winding: bool = _compute_flip_winding(boundary_pts)

	_generate_cliff_scatter()
	var plain_mesh: ArrayMesh = _generate_plain_mesh(boundary_pts, base_y, flip_winding)
	var wall_mesh: ArrayMesh = _generate_cliff_wall(boundary_pts, base_y, flip_winding)

	if add_collision:
		_generate_cliff_collision(wall_mesh, plain_mesh)


func clear_cliffs() -> void:
	for child in get_children():
		if child.name.begins_with(GENERATED_CLIFF_PREFIX):
			remove_child(child)
			child.free()
	var wall: Node = get_node_or_null(CLIFF_WALL_NODE_NAME)
	if wall:
		remove_child(wall)
		wall.free()
	var plain: Node = get_node_or_null(PLAIN_NODE_NAME)
	if plain:
		remove_child(plain)
		plain.free()
	var collision: Node = get_node_or_null(COLLISION_NODE_NAME)
	if collision:
		remove_child(collision)
		collision.free()


func _generate_cliff_scatter() -> void:
	var meshes: Array[Mesh] = _load_meshes()
	if meshes.is_empty():
		return

	var cliff_material: Material = _load_biome_material(cliff_material_biome)
	if cliff_material == null:
		return

	var curve: Curve3D = cliff_path.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		push_warning("CliffTool: Path3D curve has zero baked length.")
		return

	var transforms_by_variant: Array[Array] = []
	for i in range(meshes.size()):
		transforms_by_variant.append([])

	for i in range(cliff_amount):
		var dist: float = _rng.randf_range(0.0, length)
		var sample: Dictionary = _sample_at_distance(curve, dist)

		var local_pos: Vector3 = to_local(sample.world_pos)

		var spin: float = _rng.randf_range(0.0, deg_to_rad(rotation_variance_degrees))
		var instance_basis: Basis
		if align_to_path_tangent:
			instance_basis = Basis.looking_at(sample.world_tangent, Vector3.UP)
			instance_basis = instance_basis.rotated(Vector3.UP, spin)
		else:
			instance_basis = Basis(Vector3.UP, spin)

		var x_scale: float = _rng.randf_range(scale_min, scale_max)
		instance_basis = instance_basis.scaled(Vector3(x_scale, x_scale, x_scale))

		var variant_index: int = _rng.randi_range(0, meshes.size() - 1)
		transforms_by_variant[variant_index].append(Transform3D(instance_basis, local_pos))

	var generated_count := 0
	for variant_index in range(meshes.size()):
		var xforms: Array = transforms_by_variant[variant_index]
		if xforms.is_empty():
			continue

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		mm.use_custom_data = false
		mm.mesh = meshes[variant_index]
		mm.instance_count = xforms.size()

		for i in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i])

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s%d" % [GENERATED_CLIFF_PREFIX, variant_index + 1]
		mmi.multimesh = mm
		mmi.material_override = cliff_material

		add_child(mmi)
		_set_owner(mmi)

		generated_count += xforms.size()

	print("CliffTool: generated %d cliffs across %d variants. seed=%d" % [generated_count, meshes.size(), random_seed])


func _sample_at_distance(curve: Curve3D, offset: float) -> Dictionary:
	var length: float = curve.get_baked_length()
	var local_pos: Vector3 = curve.sample_baked(offset, true)

	var delta: float = max(length * 0.001, 0.001)
	var offset_fwd: float = min(offset + delta, length)
	var offset_back: float = max(offset - delta, 0.0)
	var local_fwd: Vector3 = curve.sample_baked(offset_fwd, true)
	var local_back: Vector3 = curve.sample_baked(offset_back, true)

	var tangent_local: Vector3 = local_fwd - local_back
	if tangent_local.length() < 0.00001:
		tangent_local = Vector3.FORWARD
	tangent_local = tangent_local.normalized()

	var world_pos: Vector3 = cliff_path.global_transform * local_pos
	var world_tangent: Vector3 = (cliff_path.global_transform.basis * tangent_local).normalized()

	return {
		"world_pos": world_pos,
		"world_tangent": world_tangent,
	}


func _load_meshes() -> Array[Mesh]:
	var meshes: Array[Mesh] = []
	for path in cliff_mesh_paths:
		var mesh: Mesh = load(path)
		if mesh == null:
			push_warning("CliffTool: could not load cliff mesh at %s" % path)
			continue
		meshes.append(mesh)
	return meshes


func _load_biome_material(biome: Biome) -> Material:
	var biome_name: String = BIOME_NAMES[biome]
	var mat_path: String = "%s/nbmat_terrain_%s.tres" % [materials_root_path, biome_name]
	var material: Material = load(mat_path)

	if material == null:
		push_warning("CliffTool: could not load biome material at %s" % mat_path)

	return material


func _sample_boundary() -> Array:
	var curve: Curve3D = cliff_path.curve
	var count: int = curve.get_point_count()
	var result: Array = []

	for i in range(count):
		var local_pos: Vector3 = curve.get_point_position(i)
		var world_pos: Vector3 = cliff_path.global_transform * local_pos
		result.append(world_pos)

	return result


func _average_height(pts: Array) -> float:
	var sum: float = 0.0
	for p in pts:
		sum += p.y
	return sum / float(pts.size())


func _compute_flip_winding(pts: Array) -> bool:
	var area: float = 0.0
	var count: int = pts.size()
	for i in range(count):
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[(i + 1) % count]
		area += p0.x * p1.z - p1.x * p0.z
	return area < 0.0


func _generate_plain_mesh(pts: Array, base_y: float, flip_winding: bool) -> ArrayMesh:
	var boundary_world: Array = []
	for p in pts:
		boundary_world.append(Vector3(p.x, base_y + plain_height, p.z))

	var polygon_2d := PackedVector2Array()
	for v in boundary_world:
		polygon_2d.append(Vector2(v.x, v.z))

	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon_2d)
	if indices.size() < 3:
		push_warning("CliffTool: Could not triangulate plain — check that the cliff boundary is a simple closed loop.")
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var i := 0
	while i < indices.size():
		var i0: int = indices[i]
		var i1: int = indices[i + 1]
		var i2: int = indices[i + 2]
		if flip_winding:
			var tmp: int = i1
			i1 = i2
			i2 = tmp

		var va: Vector3 = to_local(boundary_world[i0])
		var vb: Vector3 = to_local(boundary_world[i1])
		var vc: Vector3 = to_local(boundary_world[i2])

		st.add_vertex(va)
		st.add_vertex(vb)
		st.add_vertex(vc)
		i += 3

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var plain_material: Material = _load_biome_material(plain_material_biome)

	var mi := MeshInstance3D.new()
	mi.name = PLAIN_NODE_NAME
	mi.mesh = mesh
	add_child(mi)
	_set_owner(mi)
	if plain_material:
		mi.set_surface_override_material(0, plain_material)

	return mesh


func _generate_cliff_wall(pts: Array, base_y: float, flip_winding: bool) -> ArrayMesh:
	var count: int = pts.size()
	if count < 3:
		return null

	var wall_material: Material = _load_biome_material(cliff_material_biome)
	if wall_material == null:
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(count):
		var bottom_a: Vector3 = pts[i]
		var bottom_b: Vector3 = pts[(i + 1) % count]
		var top_a: Vector3 = Vector3(bottom_a.x, base_y + plain_height, bottom_a.z)
		var top_b: Vector3 = Vector3(bottom_b.x, base_y + plain_height, bottom_b.z)

		var va: Vector3 = to_local(bottom_a)
		var vb: Vector3 = to_local(bottom_b)
		var vc: Vector3 = to_local(top_b)
		var vd: Vector3 = to_local(top_a)

		if flip_winding:
			st.add_vertex(va)
			st.add_vertex(vd)
			st.add_vertex(vc)
			st.add_vertex(va)
			st.add_vertex(vc)
			st.add_vertex(vb)
		else:
			st.add_vertex(va)
			st.add_vertex(vc)
			st.add_vertex(vd)
			st.add_vertex(va)
			st.add_vertex(vb)
			st.add_vertex(vc)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mi := MeshInstance3D.new()
	mi.name = CLIFF_WALL_NODE_NAME
	mi.mesh = mesh
	add_child(mi)
	_set_owner(mi)
	mi.set_surface_override_material(0, wall_material)

	return mesh


func _generate_cliff_collision(wall_mesh: ArrayMesh, plain_mesh: ArrayMesh) -> void:
	if wall_mesh == null and plain_mesh == null:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	if wall_mesh:
		st.append_from(wall_mesh, 0, Transform3D.IDENTITY)
	if plain_mesh:
		st.append_from(plain_mesh, 0, Transform3D.IDENTITY)

	var combined_mesh: ArrayMesh = st.commit()
	var shape: Shape3D = combined_mesh.create_trimesh_shape()
	if shape == null:
		push_warning("CliffTool: could not create collision shape for cliff collision.")
		return

	var body := StaticBody3D.new()
	body.name = COLLISION_NODE_NAME
	add_child(body)
	_set_owner(body)

	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape"
	cs.shape = shape
	body.add_child(cs)
	_set_owner(cs)


func _set_owner(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		node.owner = get_tree().edited_scene_root
