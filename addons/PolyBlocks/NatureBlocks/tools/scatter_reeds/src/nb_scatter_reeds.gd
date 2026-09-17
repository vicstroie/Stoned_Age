# POLYBLOCKS | NATUREBLOCKS | REED SCATTER TOOL
# bukkbeek.github.io

@tool
extends Node

@export_tool_button("Generate", "Play") var generate_button: Callable = generate
@export_tool_button("Clear", "Clear") var clear_button: Callable = clear

@export var surface_mesh: MeshInstance3D

@export_group("Scatter Settings")
@export var use_random_seed: bool = true
@export var random_seed: int = 12345
@export_range(-1.0, 1.0, 0.01) var top_facing_threshold: float = 0.8
@export_range(0.0, 360.0, 1.0) var rotation_variance_degrees: float = 360.0
@export var align_to_surface_normal: bool = false

@export_group("Reeds")
@export_range(1, 100000, 1) var reed_amount: int = 100
@export_range(0.0, 100.0, 1.0) var reeds_1: float = 50.0
@export_range(0.0, 100.0, 1.0) var reeds_2: float = 50.0
@export_range(0.01, 10.0, 0.01) var reed_scale_min: float = 0.8
@export_range(0.01, 10.0, 0.01) var reed_scale_max: float = 1.2
@export var reed_surface_offset: float = -0.02

@export_group("Resource Paths")
@export_file var reed_mesh_path: String = "res://PolyBlocks/NatureBlocks/tools/scatter_reeds/src/nbmesh_reeds1.mesh"
@export_dir var reed_materials_root_path: String = "res://PolyBlocks/NatureBlocks/source_files/materials/reeds"

@export_group("Generated Node")
@export var generated_reeds_name: String = "nbgen_reeds"

var _rng := RandomNumberGenerator.new()


func generate() -> void:
	if surface_mesh == null:
		push_warning("ReedScatterTool: no surface_mesh assigned.")
		return

	if surface_mesh.mesh == null:
		push_warning("ReedScatterTool: surface_mesh has no Mesh resource.")
		return

	if reed_scale_min > reed_scale_max:
		push_warning("ReedScatterTool: reed_scale_min is greater than reed_scale_max.")
		return

	if use_random_seed:
		randomize()
		random_seed = randi()

	_rng.seed = random_seed

	_remove_generated_reeds()

	var triangle_data: Dictionary = _build_triangle_distribution(surface_mesh.mesh)

	if triangle_data.is_empty():
		push_warning("ReedScatterTool: no usable top-facing surface area found.")
		return

	_scatter_reeds(triangle_data)


func _build_triangle_distribution(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}

	var triangles: Array = _get_top_facing_triangles(mesh)

	if triangles.is_empty():
		push_warning("ReedScatterTool: no top-facing triangles found.")
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
		push_warning("ReedScatterTool: no valid triangle area found.")
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


func _scatter_reeds(triangle_data: Dictionary) -> void:
	if reed_scale_min > reed_scale_max:
		push_warning("ReedScatterTool: reed_scale_min is greater than reed_scale_max.")
		return

	var weights: Dictionary = {
		"reeds1": clamp(reeds_1, 0.0, 100.0),
		"reeds2": clamp(reeds_2, 0.0, 100.0),
	}

	var total_weight: float = weights["reeds1"] + weights["reeds2"]

	if total_weight <= 0.0:
		push_warning("ReedScatterTool: all reed material percentages are zero; no reeds placed.")
		return

	var variants: Array[String] = ["reeds1", "reeds2"]
	var cumulative_prob: Array[float] = []
	var acc := 0.0

	for v in variants:
		acc += weights[v] / total_weight
		cumulative_prob.append(acc)

	var counts: Dictionary = {
		"reeds1": 0,
		"reeds2": 0,
	}

	for i in reed_amount:
		var r := _rng.randf()
		for idx in variants.size():
			if r <= cumulative_prob[idx]:
				counts[variants[idx]] += 1
				break

	var reed_mesh: Mesh = _load_reed_mesh()
	if reed_mesh == null:
		return

	var reeds_container := Node3D.new()
	reeds_container.name = generated_reeds_name
	surface_mesh.add_child(reeds_container)
	_set_editor_owner(reeds_container)

	var total_placed := 0
	var variants_placed := 0

	for v in variants:
		var count: int = counts[v]
		if count <= 0:
			continue

		var material: Material = _load_reed_material(v)
		if material == null:
			continue

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		mm.use_custom_data = false
		mm.mesh = reed_mesh
		mm.instance_count = count

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%s" % [generated_reeds_name, v]
		mmi.multimesh = mm
		mmi.material_override = material

		reeds_container.add_child(mmi)
		_set_editor_owner(mmi)

		_place_multimesh_instances(
			mm,
			triangle_data,
			count,
			reed_scale_min,
			reed_scale_max,
			reed_surface_offset
		)

		total_placed += count
		variants_placed += 1

	print(
		"ReedScatterTool: scattered %d reeds across %d material(s) on %s."
		% [
			total_placed,
			variants_placed,
			surface_mesh.name
		]
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
				"ReedScatterTool: surface %d has no vertex/normal data, skipping."
				% surface_idx
			)
			continue

		var verts: PackedVector3Array = verts_v
		var normals: PackedVector3Array = normals_v
		var indices = indices_v

		if indices == null:
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


func _load_reed_mesh() -> Mesh:
	var mesh: Mesh = load(reed_mesh_path)
	if mesh == null:
		push_warning(
			"ReedScatterTool: could not load reed mesh at %s"
			% reed_mesh_path
		)
		return null

	return mesh


func _load_reed_material(variant: String) -> Material:
	var mat_path: String = (
		"%s/nbmat_%s.tres"
		% [
			reed_materials_root_path,
			variant
		]
	)

	var material: Material = load(mat_path)
	if material == null:
		push_warning(
			"ReedScatterTool: could not load reed material at %s"
			% mat_path
		)

	return material


func _remove_generated_reeds() -> void:
	if surface_mesh == null:
		return

	var existing: Node = surface_mesh.get_node_or_null(
		generated_reeds_name
	)

	if existing != null:
		existing.free()


func clear() -> void:
	if surface_mesh == null:
		return

	_remove_generated_reeds()

	print("ReedScatterTool: cleared.")
