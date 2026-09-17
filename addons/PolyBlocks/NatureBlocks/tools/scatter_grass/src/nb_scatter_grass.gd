# POLYBLOCKS | NATUREBLOCKS | GRASS SCATTER TOOL
# bukkbeek.github.io

@tool
extends Node


@export_tool_button("Generate", "Play") var generate_button: Callable = generate
@export_tool_button("Clear", "Clear") var clear_button: Callable = clear


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


enum GrassType {
	TYPE_1,
	TYPE_2,
}


@export var surface_mesh: MeshInstance3D


@export_group("Scatter Settings")
@export var use_random_seed: bool = true
@export var random_seed: int = 12345
@export_range(-1.0, 1.0, 0.01) var top_facing_threshold: float = 0.8
@export_range(0.0, 360.0, 1.0) var rotation_variance_degrees: float = 360.0
@export var align_to_surface_normal: bool = false


@export_group("Biomes")
@export var biome: Biome = Biome.CANYON

@export_group("Grass")
@export var grass_type: GrassType = GrassType.TYPE_1
@export_range(1, 100000, 1) var grass_amount: int = 1000
@export_range(0.01, 10.0, 0.01) var grass_scale_min: float = 0.8
@export_range(0.01, 10.0, 0.01) var grass_scale_max: float = 1.2
@export var grass_surface_offset: float = -0.02


@export_group("Resource Paths")
@export_file var grass_mesh_path: String = "res://PolyBlocks/NatureBlocks/tools/scatter_grass/src/nbmesh_grass.mesh"
@export_dir var grass_materials_root_path: String = "res://PolyBlocks/NatureBlocks/source_files/materials/grass"


@export_group("Generated Node")
@export var generated_grass_name: String = "nbgen_grass"


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


# New material naming:
# nbmat_grass1_canyon.tres
# nbmat_grass2_canyon.tres
const TYPE_NAMES := {
	GrassType.TYPE_1: "grass1",
	GrassType.TYPE_2: "grass2",
}


var _rng := RandomNumberGenerator.new()


func generate() -> void:
	if surface_mesh == null:
		push_warning("GrassMultiMeshTool: no surface_mesh assigned.")
		return

	if surface_mesh.mesh == null:
		push_warning("GrassMultiMeshTool: surface_mesh has no Mesh resource.")
		return

	if grass_scale_min > grass_scale_max:
		push_warning("GrassMultiMeshTool: scale_min is greater than scale_max.")
		return

	if use_random_seed:
		randomize()
		random_seed = randi()

	_rng.seed = random_seed

	_remove_generated_multimesh()

	var grass_mesh: Mesh = _load_grass_mesh()
	if grass_mesh == null:
		return

	var grass_material: Material = _load_grass_material()
	if grass_material == null:
		return

	var triangle_data: Dictionary = _build_triangle_distribution(surface_mesh.mesh)

	if triangle_data.is_empty():
		push_warning("GrassMultiMeshTool: no usable top-facing surface area found.")
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.mesh = grass_mesh
	mm.instance_count = grass_amount

	var multimesh_instance := MultiMeshInstance3D.new()
	multimesh_instance.name = generated_grass_name
	multimesh_instance.multimesh = mm
	multimesh_instance.material_override = grass_material

	surface_mesh.add_child(multimesh_instance)
	_set_editor_owner(multimesh_instance)

	_place_multimesh_instances(
		mm,
		triangle_data,
		grass_amount,
		grass_scale_min,
		grass_scale_max,
		grass_surface_offset
	)

	print(
		"GrassMultiMeshTool: generated %d instances on %s."
		% [
			grass_amount,
			surface_mesh.name
		]
	)

	print(
		"GrassMultiMeshTool: biome=%s type=%s threshold=%.2f seed=%d"
		% [
			BIOME_NAMES[biome],
			TYPE_NAMES[grass_type],
			top_facing_threshold,
			random_seed
		]
	)


func _build_triangle_distribution(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}

	var triangles: Array = _get_top_facing_triangles(mesh)

	if triangles.is_empty():
		push_warning("GrassMultiMeshTool: no top-facing triangles found.")
		return {}

	var cumulative_areas: Array[float] = []
	var total_area := 0.0

	for triangle in triangles:
		var a: Vector3 = triangle["a"]
		var b: Vector3 = triangle["b"]
		var c: Vector3 = triangle["c"]

		var area: float = _triangle_area(a, b, c)

		if area <= 0.000001:
			continue

		total_area += area
		cumulative_areas.append(total_area)

	if cumulative_areas.is_empty() or total_area <= 0.0:
		push_warning("GrassMultiMeshTool: no valid triangle area found.")
		return {}

	return {
		"triangles": triangles,
		"cumulative_areas": cumulative_areas,
		"total_area": total_area,
	}


func _place_multimesh_instances(
	mm: MultiMesh,
	triangle_data: Dictionary,
	count: int,
	instance_scale_min: float,
	instance_scale_max: float,
	offset: float
) -> void:
	var triangles: Array = triangle_data["triangles"]
	var cumulative_areas: Array[float] = triangle_data["cumulative_areas"]
	var total_area: float = triangle_data["total_area"]

	for instance_index in count:
		var triangle_index: int = _pick_triangle(
			_rng.randf_range(0.0, total_area),
			cumulative_areas
		)

		var triangle: Dictionary = triangles[triangle_index]

		var a: Vector3 = triangle["a"]
		var b: Vector3 = triangle["b"]
		var c: Vector3 = triangle["c"]

		var surface_normal: Vector3 = triangle["normal"]

		var r1 := _rng.randf()
		var r2 := _rng.randf()

		if r1 + r2 > 1.0:
			r1 = 1.0 - r1
			r2 = 1.0 - r2

		var local_position: Vector3 = (
			a
			+ (b - a) * r1
			+ (c - a) * r2
		)

		var target_normal: Vector3 = surface_normal.normalized()
		var target_position: Vector3 = local_position

		var instance_basis := Basis.IDENTITY

		if align_to_surface_normal:
			instance_basis = _basis_from_up(target_normal, 0.0)

		var max_spin: float = deg_to_rad(rotation_variance_degrees)
		var spin: float = _rng.randf_range(0.0, max_spin)

		if align_to_surface_normal:
			instance_basis = instance_basis.rotated(target_normal, spin)
		else:
			instance_basis = Basis(Vector3.UP, spin)

		var scale_value: float = _rng.randf_range(
			instance_scale_min,
			instance_scale_max
		)

		instance_basis = instance_basis.scaled(
			Vector3.ONE * scale_value
		)

		target_position += target_normal * offset

		mm.set_instance_transform(
			instance_index,
			Transform3D(
				instance_basis,
				target_position
			)
		)


func _set_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return

	var scene_root := get_tree().edited_scene_root

	if scene_root != null:
		node.owner = scene_root


func _get_top_facing_triangles(mesh: Mesh) -> Array:
	var triangles: Array = []

	for surface_idx in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface_idx)

		if arrays.is_empty():
			continue

		var verts_v: Variant = arrays[Mesh.ARRAY_VERTEX]
		var normals_v: Variant = arrays[Mesh.ARRAY_NORMAL]
		var indices_v: Variant = arrays[Mesh.ARRAY_INDEX]

		if verts_v == null or normals_v == null:
			push_warning(
				"GrassMultiMeshTool: surface %d has no vertex/normal data, skipping."
				% surface_idx
			)
			continue

		var verts: PackedVector3Array = verts_v
		var normals: PackedVector3Array = normals_v

		if indices_v == null:
			var i := 0

			while i + 2 < verts.size():
				_try_add_triangle(
					triangles,
					verts[i],
					verts[i + 1],
					verts[i + 2],
					normals[i],
					normals[i + 1],
					normals[i + 2]
				)

				i += 3
		else:
			var indices: PackedInt32Array = indices_v
			var i := 0

			while i + 2 < indices.size():
				var i0: int = indices[i]
				var i1: int = indices[i + 1]
				var i2: int = indices[i + 2]

				if (
					i0 < verts.size()
					and i1 < verts.size()
					and i2 < verts.size()
					and i0 < normals.size()
					and i1 < normals.size()
					and i2 < normals.size()
				):
					_try_add_triangle(
						triangles,
						verts[i0],
						verts[i1],
						verts[i2],
						normals[i0],
						normals[i1],
						normals[i2]
					)

				i += 3

	return triangles


func _try_add_triangle(
	triangles: Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	na: Vector3,
	nb: Vector3,
	nc: Vector3
) -> void:
	var avg_normal: Vector3 = (
		na + nb + nc
	).normalized()

	if avg_normal.dot(Vector3.UP) >= top_facing_threshold:
		triangles.append({
			"a": a,
			"b": b,
			"c": c,
			"normal": avg_normal
		})


func _triangle_area(
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> float:
	return (b - a).cross(c - a).length() * 0.5


func _pick_triangle(
	value: float,
	cumulative_areas: Array[float]
) -> int:
	var low := 0
	var high := cumulative_areas.size() - 1

	while low < high:
		@warning_ignore("integer_division")
		var middle: int = (low + high) / 2

		if value <= cumulative_areas[middle]:
			high = middle
		else:
			low = middle + 1

	return low


func _basis_from_up(
	up: Vector3,
	spin: float
) -> Basis:
	up = up.normalized()

	var arbitrary := Vector3.RIGHT

	if abs(up.dot(arbitrary)) > 0.95:
		arbitrary = Vector3.FORWARD

	var right: Vector3 = arbitrary.cross(up).normalized()
	var forward: Vector3 = right.cross(up).normalized()

	var result_basis := Basis(
		right,
		up,
		forward
	)

	return result_basis.rotated(up, spin)


func _load_grass_mesh() -> Mesh:
	var mesh: Mesh = load(grass_mesh_path)

	if mesh == null:
		push_warning(
			"GrassMultiMeshTool: could not load grass mesh at %s"
			% grass_mesh_path
		)
		return null

	return mesh


func _load_grass_material() -> Material:
	var biome_name: String = BIOME_NAMES[biome]
	var type_name: String = TYPE_NAMES[grass_type]

	var mat_path: String = (
		"%s/nbmat_%s_%s.tres"
		% [
			grass_materials_root_path,
			type_name,
			biome_name
		]
	)

	var material: Material = load(mat_path)

	if material == null:
		push_warning(
			"GrassMultiMeshTool: could not load material at %s"
			% mat_path
		)

	return material


func _remove_generated_multimesh() -> void:
	if surface_mesh == null:
		return

	var existing: Node = surface_mesh.get_node_or_null(
		generated_grass_name
	)

	if existing != null:
		existing.free()


func clear() -> void:
	if surface_mesh == null:
		return

	_remove_generated_multimesh()

	print("GrassMultiMeshTool: cleared.")
