# POLYBLOCKS | NATUREBLOCKS | SHRUB SCATTER TOOL
# bukkbeek.github.io

@tool
extends Node

@export_tool_button("Generate", "Play") var generate_button: Callable = generate
@export_tool_button("Clear", "Clear") var clear_button: Callable = clear

enum Vegetation {
	ANIME,
	AUTUMN,
	BLUE,
	FOREST,
	JUNGLE,
	MARS,
	OLIVE,
	SAKURA,
	SAVANNAH,
	SNOW,
	SPOOKY,
	TUNDRA,
}

@export var surface_mesh: MeshInstance3D

@export_group("Scatter Settings")
@export_range(1, 100000, 1) var shrub_amount: int = 20
@export_range(0.01, 10.0, 0.01) var shrub_scale_min: float = 0.8
@export_range(0.01, 10.0, 0.01) var shrub_scale_max: float = 1.2
@export var shrub_surface_offset: float = -0.02

@export var use_random_seed: bool = true
@export var random_seed: int = 12345
@export_range(-1.0, 1.0, 0.01) var top_facing_threshold: float = 0.8
@export_range(0.0, 360.0, 1.0) var rotation_variance_degrees: float = 360.0
@export var align_to_surface_normal: bool = false


@export_group("Shrub Sizes")
@export_range(0.0, 100.0, 0.1) var small_shrubs: float = 50.0
@export_range(0.0, 100.0, 0.1) var large_shrubs: float = 50.0

@export_group("Vegetation")
@export_range(0.0, 100.0, 0.1) var anime: float = 10.0
@export_range(0.0, 100.0, 0.1) var autumn: float = 10.0
@export_range(0.0, 100.0, 0.1) var blue: float = 10.0
@export_range(0.0, 100.0, 0.1) var forest: float = 10.0
@export_range(0.0, 100.0, 0.1) var jungle: float = 10.0
@export_range(0.0, 100.0, 0.1) var mars: float = 10.0
@export_range(0.0, 100.0, 0.1) var olive: float = 10.0
@export_range(0.0, 100.0, 0.1) var sakura: float = 10.0
@export_range(0.0, 100.0, 0.1) var savannah: float = 10.0
@export_range(0.0, 100.0, 0.1) var snow: float = 10.0
@export_range(0.0, 100.0, 0.1) var spooky: float = 10.0
@export_range(0.0, 100.0, 0.1) var tundra: float = 10.0


@export_group("Resource Paths")
@export_file var shrub_mesh_small_path: String = "res://PolyBlocks/NatureBlocks/tools/scatter_shrubs/src/nbmesh_shrub1.mesh"
@export_file var shrub_mesh_large_path: String = "res://PolyBlocks/NatureBlocks/tools/scatter_shrubs/src/nbmesh_shrub2.mesh"
@export_dir var vegetation_materials_root_path: String = "res://PolyBlocks/NatureBlocks/source_files/materials/leaves1"

@export_group("Generated Node")
@export var generated_shrubs_name: String = "nbgen_shrubs"

const VEGETATION_NAMES := {
	Vegetation.ANIME: "anime",
	Vegetation.AUTUMN: "autumn",
	Vegetation.BLUE: "blue",
	Vegetation.FOREST: "forest",
	Vegetation.JUNGLE: "jungle",
	Vegetation.MARS: "mars",
	Vegetation.OLIVE: "olive",
	Vegetation.SAKURA: "sakura",
	Vegetation.SAVANNAH: "savannah",
	Vegetation.SNOW: "snow",
	Vegetation.SPOOKY: "spooky",
	Vegetation.TUNDRA: "tundra",
}

var _rng := RandomNumberGenerator.new()


func generate() -> void:
	if surface_mesh == null:
		push_warning("ShrubScatterTool: no surface_mesh assigned.")
		return

	if surface_mesh.mesh == null:
		push_warning("ShrubScatterTool: surface_mesh has no Mesh resource.")
		return

	if shrub_scale_min > shrub_scale_max:
		push_warning("ShrubScatterTool: shrub_scale_min is greater than shrub_scale_max.")
		return

	if use_random_seed:
		randomize()
		random_seed = randi()

	_rng.seed = random_seed

	_remove_generated_shrubs()

	var triangle_data: Dictionary = _build_triangle_distribution(surface_mesh.mesh)

	if triangle_data.is_empty():
		push_warning("ShrubScatterTool: no usable top-facing surface area found.")
		return

	_scatter_shrubs(triangle_data)


func _build_triangle_distribution(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}

	var triangles: Array = _get_top_facing_triangles(mesh)

	if triangles.is_empty():
		push_warning("ShrubScatterTool: no top-facing triangles found.")
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
		push_warning("ShrubScatterTool: no valid triangle area found.")
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


func _scatter_shrubs(triangle_data: Dictionary) -> void:
	if shrub_scale_min > shrub_scale_max:
		push_warning("ShrubScatterTool: shrub_scale_min is greater than shrub_scale_max.")
		return

	# --- Type weights ---
	var type_weights: Dictionary = {
		"small": clamp(small_shrubs, 0.0, 100.0),
		"large": clamp(large_shrubs, 0.0, 100.0),
	}
	var total_type_weight: float = type_weights["small"] + type_weights["large"]
	if total_type_weight <= 0.0:
		push_warning("ShrubScatterTool: all shrub type percentages are zero; no shrubs placed.")
		return

	# Build cumulative probabilities for types
	var type_list: Array[String] = ["small", "large"]
	var type_cumulative: Array[float] = []
	var acc_type: float = 0.0
	for t in type_list:
		acc_type += type_weights[t] / total_type_weight
		type_cumulative.append(acc_type)

	# --- Vegetation weights ---
	var vegetation_percents: Dictionary = {
		Vegetation.ANIME: clamp(anime, 0.0, 100.0),
		Vegetation.AUTUMN: clamp(autumn, 0.0, 100.0),
		Vegetation.BLUE: clamp(blue, 0.0, 100.0),
		Vegetation.FOREST: clamp(forest, 0.0, 100.0),
		Vegetation.JUNGLE: clamp(jungle, 0.0, 100.0),
		Vegetation.MARS: clamp(mars, 0.0, 100.0),
		Vegetation.OLIVE: clamp(olive, 0.0, 100.0),
		Vegetation.SAKURA: clamp(sakura, 0.0, 100.0),
		Vegetation.SAVANNAH: clamp(savannah, 0.0, 100.0),
		Vegetation.SNOW: clamp(snow, 0.0, 100.0),
		Vegetation.SPOOKY: clamp(spooky, 0.0, 100.0),
		Vegetation.TUNDRA: clamp(tundra, 0.0, 100.0),
	}
	var total_veg_weight: float = 0.0
	for key in vegetation_percents:
		total_veg_weight += vegetation_percents[key]
	if total_veg_weight <= 0.0:
		push_warning("ShrubScatterTool: all vegetation percentages are zero; no shrubs placed.")
		return

	var veg_list: Array[Vegetation] = []
	for key in vegetation_percents.keys():
		veg_list.append(key)
	var veg_cumulative: Array[float] = []
	var acc_veg: float = 0.0
	for veg in veg_list:
		acc_veg += vegetation_percents[veg] / total_veg_weight
		veg_cumulative.append(acc_veg)

	# --- Count instances for each (type, vegetation) combination ---
	var combo_counts: Dictionary = {}  # key: "type_vegetation" → count
	for i in shrub_amount:
		# pick type
		var r_type: float = _rng.randf()
		var chosen_type_idx: int = 0
		for idx in type_list.size():
			if r_type <= type_cumulative[idx]:
				chosen_type_idx = idx
				break
		var chosen_type: String = type_list[chosen_type_idx]

		# pick vegetation
		var r_veg: float = _rng.randf()
		var chosen_veg_idx: int = 0
		for idx in veg_list.size():
			if r_veg <= veg_cumulative[idx]:
				chosen_veg_idx = idx
				break
		var chosen_veg: Vegetation = veg_list[chosen_veg_idx]

		var key: String = "%s_%s" % [chosen_type, VEGETATION_NAMES[chosen_veg]]
		combo_counts[key] = combo_counts.get(key, 0) + 1

	if combo_counts.is_empty():
		push_warning("ShrubScatterTool: no combinations generated.")
		return

	# --- Create container ---
	var shrubs_container := Node3D.new()
	shrubs_container.name = generated_shrubs_name
	surface_mesh.add_child(shrubs_container)
	_set_editor_owner(shrubs_container)

	var total_placed: int = 0
	var unique_combos: int = 0

	for combo_key in combo_counts:
		var count: int = combo_counts[combo_key]
		if count <= 0:
			continue

		# Split key into type and vegetation name
		var parts: PackedStringArray = combo_key.split("_")
		var type_str: String = parts[0]  # "small" or "large"
		var veg_name: String = parts[1]  # e.g., "anime"

		# Find the Vegetation enum value that corresponds to veg_name
		var veg_enum: Vegetation = Vegetation.ANIME  # dummy default
		var found_vegetation: bool = false
		for enum_val in VEGETATION_NAMES:
			if VEGETATION_NAMES[enum_val] == veg_name:
				veg_enum = enum_val
				found_vegetation = true
				break
		if not found_vegetation:
			push_warning("ShrubScatterTool: unknown vegetation name %s" % veg_name)
			continue

		# Load mesh for this type
		var is_large: bool = (type_str == "large")
		var mesh: Mesh = _load_shrub_mesh(is_large)
		if mesh == null:
			continue

		# Load vegetation material
		var material: Material = _load_vegetation_material(veg_enum)
		if material == null:
			continue

		# Create MultiMesh
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		mm.use_custom_data = false
		mm.mesh = mesh
		mm.instance_count = count

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%s_%s" % [generated_shrubs_name, type_str, veg_name]
		mmi.multimesh = mm
		mmi.material_override = material

		shrubs_container.add_child(mmi)
		_set_editor_owner(mmi)

		_place_multimesh_instances(
			mm,
			triangle_data,
			count,
			shrub_scale_min,
			shrub_scale_max,
			shrub_surface_offset
		)

		total_placed += count
		unique_combos += 1

	print(
		"ShrubScatterTool: scattered %d shrubs across %d (type×material) combinations on %s."
		% [
			total_placed,
			unique_combos,
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
				"ShrubScatterTool: surface %d has no vertex/normal data, skipping."
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


func _load_shrub_mesh(is_large: bool) -> Mesh:
	var path: String = shrub_mesh_large_path if is_large else shrub_mesh_small_path
	var mesh: Mesh = load(path)

	if mesh == null:
		push_warning(
			"ShrubScatterTool: could not load shrub mesh at %s"
			% path
		)
		return null

	return mesh


func _load_vegetation_material(vegetation: Vegetation) -> Material:
	var vegetation_name: String = VEGETATION_NAMES[vegetation]
	var mat_path: String = (
		"%s/nbmat_leaves1_%s.tres"
		% [
			vegetation_materials_root_path,
			vegetation_name
		]
	)

	var material: Material = load(mat_path)

	if material == null:
		push_warning(
			"ShrubScatterTool: could not load vegetation material at %s"
			% mat_path
		)

	return material


func _remove_generated_shrubs() -> void:
	if surface_mesh == null:
		return

	var existing: Node = surface_mesh.get_node_or_null(
		generated_shrubs_name
	)

	if existing != null:
		existing.free()


func clear() -> void:
	if surface_mesh == null:
		return

	_remove_generated_shrubs()

	print("ShrubScatterTool: cleared.")
