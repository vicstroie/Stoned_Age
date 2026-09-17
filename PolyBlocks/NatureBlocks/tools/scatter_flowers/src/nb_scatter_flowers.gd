# POLYBLOCKS | NATUREBLOCKS | FLOWER SCATTER TOOL
# bukkbeek.github.io

@tool
extends Node

@export_tool_button("Generate", "Play") var generate_button: Callable = generate
@export_tool_button("Clear", "Clear") var clear_button: Callable = clear

enum FlowerVariant {
	BLUE,
	RED,
	WHITE,
	YELLOW,
}

@export var surface_mesh: MeshInstance3D

@export_group("Scatter Settings")
@export var use_random_seed: bool = true
@export var random_seed: int = 12345
@export_range(-1.0, 1.0, 0.01) var top_facing_threshold: float = 0.8
@export_range(0.0, 360.0, 1.0) var rotation_variance_degrees: float = 360.0
@export var align_to_surface_normal: bool = false

@export_group("Flowers")
@export var spawn_flower_1: bool = true
@export var spawn_flower_2: bool = true
@export_range(1, 100000, 1) var flower_amount: int = 100
@export_range(0.0, 100.0, 1.0) var blue_flowers: float = 25.0
@export_range(0.0, 100.0, 1.0) var red_flowers: float = 25.0
@export_range(0.0, 100.0, 1.0) var white_flowers: float = 25.0
@export_range(0.0, 100.0, 1.0) var yellow_flowers: float = 25.0
@export_range(0.01, 10.0, 0.01) var flower_scale_min: float = 0.4
@export_range(0.01, 10.0, 0.01) var flower_scale_max: float = 0.6
@export var flower_surface_offset: float = -0.02

@export_group("Resource Paths")
var flower_meshes: Array[String] = [
	"res://PolyBlocks/NatureBlocks/tools/scatter_flowers/src/nbmesh_flower1.mesh",
	"res://PolyBlocks/NatureBlocks/tools/scatter_flowers/src/nbmesh_flower2.mesh"
]
@export_dir var flower_materials_root_path: String = "res://PolyBlocks/NatureBlocks/source_files/materials/flowers"

@export_group("Generated Node")
@export var generated_flowers_name: String = "nbgen_flowers"

const FLOWER_VARIANT_NAMES := {
	FlowerVariant.BLUE: "blue",
	FlowerVariant.RED: "red",
	FlowerVariant.WHITE: "white",
	FlowerVariant.YELLOW: "yellow",
}

var _rng := RandomNumberGenerator.new()


func generate() -> void:
	if surface_mesh == null:
		push_warning("FlowerScatterTool: no surface_mesh assigned.")
		return

	if surface_mesh.mesh == null:
		push_warning("FlowerScatterTool: surface_mesh has no Mesh resource.")
		return

	if flower_scale_min > flower_scale_max:
		push_warning("FlowerScatterTool: flower_scale_min is greater than flower_scale_max.")
		return

	if use_random_seed:
		randomize()
		random_seed = randi()

	_rng.seed = random_seed

	_remove_generated_flowers()

	var triangle_data: Dictionary = _build_triangle_distribution(surface_mesh.mesh)

	if triangle_data.is_empty():
		push_warning("FlowerScatterTool: no usable top-facing surface area found.")
		return

	_scatter_flowers(triangle_data)


func _build_triangle_distribution(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {}

	var triangles: Array = _get_top_facing_triangles(mesh)

	if triangles.is_empty():
		push_warning("FlowerScatterTool: no top-facing triangles found.")
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
		push_warning("FlowerScatterTool: no valid triangle area found.")
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


func _scatter_flowers(triangle_data: Dictionary) -> void:
	if flower_scale_min > flower_scale_max:
		push_warning("FlowerScatterTool: flower_scale_min is greater than flower_scale_max.")
		return

	var weights := {
		FlowerVariant.BLUE: clamp(blue_flowers, 0.0, 100.0),
		FlowerVariant.RED: clamp(red_flowers, 0.0, 100.0),
		FlowerVariant.WHITE: clamp(white_flowers, 0.0, 100.0),
		FlowerVariant.YELLOW: clamp(yellow_flowers, 0.0, 100.0),
	}

	var total_weight := 0.0

	for w in weights.values():
		total_weight += w

	if total_weight <= 0.0:
		push_warning("FlowerScatterTool: all flower percentages are zero; no flowers placed.")
		return

	var variants: Array[FlowerVariant] = [
		FlowerVariant.BLUE,
		FlowerVariant.RED,
		FlowerVariant.WHITE,
		FlowerVariant.YELLOW
	]

	var cumulative_prob: Array[float] = []
	var acc := 0.0

	for v in variants:
		acc += weights[v] / total_weight
		cumulative_prob.append(acc)

	var counts := {}

	for v in variants:
		counts[v] = 0

	for i in flower_amount:
		var r := _rng.randf()

		for idx in variants.size():
			if r <= cumulative_prob[idx]:
				counts[variants[idx]] += 1
				break

	var variant_pool: Array[FlowerVariant] = []

	for v in variants:
		if counts[v] > 0:
			variant_pool.append(v)

	if variant_pool.is_empty():
		push_warning("FlowerScatterTool: no flower variants selected with current percentages.")
		return

	var meshes_loaded: Array[Mesh] = []
	var paths_to_load: Array[String] = []
	if spawn_flower_1 and flower_meshes.size() > 0:
		paths_to_load.append(flower_meshes[0])
	if spawn_flower_2 and flower_meshes.size() > 1:
		paths_to_load.append(flower_meshes[1])

	var mesh_names: Array[String] = []

	for path in paths_to_load:
		var mesh: Mesh = load(path)
		if mesh != null:
			meshes_loaded.append(mesh)
			# Extract "flower1" from "nbmesh_flower1"
			var m_name := path.get_file().get_basename().replace("nbmesh_", "")
			mesh_names.append(m_name)

	if meshes_loaded.is_empty():
		push_warning("FlowerScatterTool: no flower meshes could be loaded.")
		return

	var flowers_container := Node3D.new()
	flowers_container.name = generated_flowers_name
	surface_mesh.add_child(flowers_container)
	_set_editor_owner(flowers_container)

	var total_placed := 0
	var colors_placed := 0

	for variant in variant_pool:
		var count: int = counts[variant]
		if count <= 0:
			continue

		colors_placed += 1

		# Distribute the count among the available meshes
		var mesh_count := meshes_loaded.size()
		var count_per_mesh := count / mesh_count
		var remainder := count % mesh_count

		for i in mesh_count:
			var m_count := count_per_mesh
			if i < remainder:
				m_count += 1

			if m_count <= 0:
				continue

			var mesh_name := mesh_names[i]
			var material: Material = _load_flower_material(mesh_name, variant)

			if material == null:
				continue

			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = false
			mm.use_custom_data = false
			mm.mesh = meshes_loaded[i]
			mm.instance_count = m_count

			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%s_%s" % [
				generated_flowers_name,
				mesh_name,
				FLOWER_VARIANT_NAMES[variant]
			]
			mmi.multimesh = mm
			mmi.material_override = material

			flowers_container.add_child(mmi)
			_set_editor_owner(mmi)

			# We need to distribute triangle_data properly, but _place_multimesh_instances 
			# just picks random triangles based on total area, so we can just call it 
			# multiple times without issue since positions are randomized.
			_place_multimesh_instances(
				mm,
				triangle_data,
				m_count,
				flower_scale_min,
				flower_scale_max,
				flower_surface_offset
			)

			total_placed += m_count

	print(
		"FlowerScatterTool: scattered %d flowers across %d color(s) on %s."
		% [
			total_placed,
			colors_placed,
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
				"FlowerScatterTool: surface %d has no vertex/normal data, skipping."
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


func _load_flower_material(mesh_name: String, variant: FlowerVariant) -> Material:
	var variant_name: String = FLOWER_VARIANT_NAMES[variant]

	var mat_path: String = (
		"%s/nbmat_%s_%s.tres"
		% [
			flower_materials_root_path,
			mesh_name,
			variant_name
		]
	)

	var material: Material = load(mat_path)

	if material == null:
		push_warning(
			"FlowerScatterTool: could not load flower material at %s"
			% mat_path
		)

	return material


func _remove_generated_flowers() -> void:
	if surface_mesh == null:
		return

	var existing: Node = surface_mesh.get_node_or_null(
		generated_flowers_name
	)

	if existing != null:
		existing.free()


func clear() -> void:
	if surface_mesh == null:
		return

	_remove_generated_flowers()

	print("FlowerScatterTool: cleared.")
