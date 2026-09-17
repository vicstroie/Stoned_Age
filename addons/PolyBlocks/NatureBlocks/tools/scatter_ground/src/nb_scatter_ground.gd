# POLYBLOCKS | NATUREBLOCKS | GROUND SCATTER TOOL
# bukkbeek.github.io

@tool
extends Node

@export_tool_button("Generate Ground", "Play") var generate_ground_button: Callable = generate_ground
@export_tool_button("Clear Ground", "Clear") var clear_ground_button: Callable = clear_ground

@export var surface_mesh: MeshInstance3D

@export_group("Rocks")
@export_tool_button("Add Rocks", "Add") var add_rocks_button: Callable = add_rocks
@export_tool_button("Clear Rocks", "Clear") var clear_rocks_button: Callable = clear_rocks
@export_range(0, 10, 1) var rocks_amount: int = 10

@export_group("Boulders")
@export_tool_button("Add Boulders", "Add") var add_boulders_button: Callable = add_boulders
@export_tool_button("Clear Boulders", "Clear") var clear_boulders_button: Callable = clear_boulders
@export_range(0, 10, 1) var boulders_amount: int = 10

@export_group("Pebbles")
@export_tool_button("Add Pebbles", "Add") var add_pebbles_button: Callable = add_pebbles
@export_tool_button("Clear Pebbles", "Clear") var clear_pebbles_button: Callable = clear_pebbles
@export_range(0, 10, 1) var pebbles_amount: int = 10

@export_group("Scatter Settings")
@export var use_random_seed: bool = true
@export var random_seed: int = 0
@export_range(-1.0, 1.0, 0.01) var top_facing_threshold: float = 0.8
@export var surface_offset: float = 0.01
@export var align_to_surface_normal: bool = false
@export var auto_spacing: bool = true
@export var min_spacing: float = 2.5:
	set(value):
		min_spacing = max(0.05, value)
@export_range(4, 60, 1) var max_sample_attempts: int = 30
@export var density: float = 0.05
@export var max_items: int = 0
@export_range(0, 360, 1) var rotation_variance_degrees: float = 360.0
@export_range(0.0, 1.0, 0.01) var scale_min: float = 0.8
@export_range(1.0, 2.0, 0.01) var scale_max: float = 1.2

@export_group("Biomes")
@export_range(0.0, 100.0, 1.0) var biome_canyon: float = 100.0
@export_range(0.0, 100.0, 1.0) var biome_cave: float = 100.0
@export_range(0.0, 100.0, 1.0) var biome_desert: float = 100.0
@export_range(0.0, 100.0, 1.0) var biome_grey: float = 100.0
@export_range(0.0, 100.0, 1.0) var biome_ice: float = 100.0
@export_range(0.0, 100.0, 1.0) var biome_moss: float = 100.0
@export_range(0.0, 100.0, 1.0) var biome_river: float = 100.0
@export_range(0.0, 100.0, 1.0) var biome_sand: float = 100.0
@export_range(0.0, 100.0, 1.0) var biome_swamp: float = 100.0
@export_range(0.0, 100.0, 1.0) var biome_verdant: float = 100.0

@export_group("Resource Paths")
@export_dir var rocks_path: String = "res://PolyBlocks/NatureBlocks/assets/ground/rocks"
@export_dir var boulders_path: String = "res://PolyBlocks/NatureBlocks/assets/ground/boulders"
@export_dir var pebbles_path: String = "res://PolyBlocks/NatureBlocks/assets/ground/pebbles"


const GENERATED_META := "flat_scatter_generated"
const CONTAINER_ROCKS := "Rocks"
const CONTAINER_BOULDERS := "Boulders"
const CONTAINER_PEBBLES := "Pebbles"

const ROCK_COUNT := 6
const BOULDER_COUNT := 4
const PEBBLE_COUNT := 3

var _rng := RandomNumberGenerator.new()


func generate_ground() -> void:
	clear_ground()
	_scatter([CONTAINER_ROCKS, CONTAINER_BOULDERS, CONTAINER_PEBBLES])


func clear_ground() -> void:
	clear_rocks()
	clear_boulders()
	clear_pebbles()


func add_rocks() -> void:
	_scatter([CONTAINER_ROCKS])


func add_boulders() -> void:
	_scatter([CONTAINER_BOULDERS])


func add_pebbles() -> void:
	_scatter([CONTAINER_PEBBLES])


func _scatter(enabled_types: Array[String]) -> void:
	if surface_mesh == null or surface_mesh.mesh == null:
		push_warning("MeshRockScatter: no surface_mesh (with a Mesh) assigned")
		return

	if enabled_types.is_empty():
		push_warning("MeshRockScatter: no rock types selected")
		return

	_rng.seed = randi() if use_random_seed else random_seed

	var spacing := min_spacing
	if auto_spacing:
		spacing = _spacing_from_density(density)

	var mesh: Mesh = surface_mesh.mesh
	var aabb: AABB = mesh.get_aabb()
	var triangles := _get_top_facing_triangles(mesh)
	print("MeshRockScatter: aabb=%s, top-facing triangles=%d" % [aabb, triangles.size()])
	if triangles.is_empty():
		push_warning("MeshRockScatter: no triangles on target mesh meet top_facing_threshold")
		return

	var points := _generate_poisson_points(spacing, aabb)
	print("MeshRockScatter: candidate points=%d, spacing=%.3f" % [points.size(), spacing])
	var placed := 0
	var misses := 0
	for p in points:
		var hit := _raycast_down(p.x, p.y, aabb, triangles)
		if hit.is_empty():
			misses += 1
			continue
		_place_rock_at(hit["position"], hit["normal"], enabled_types)
		placed += 1
		if max_items > 0 and placed >= max_items:
			break
	print("MeshRockScatter: placed=%d, raycast misses=%d" % [placed, misses])


func _spacing_from_density(d: float) -> float:
	var safe_density: float = max(d, 0.0001)
	var packing_factor := 0.7
	return sqrt(1.0 / (safe_density * PI / packing_factor))


func _get_top_facing_triangles(mesh: Mesh) -> Array:
	var triangles: Array = []
	for surface_idx in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_idx)
		if arrays.is_empty():
			continue

		var verts_v: Variant = arrays[Mesh.ARRAY_VERTEX]
		var normals_v: Variant = arrays[Mesh.ARRAY_NORMAL]
		var indices_v: Variant = arrays[Mesh.ARRAY_INDEX]

		if verts_v == null or normals_v == null:
			push_warning("MeshRockScatter: surface %d has no vertex/normal data, skipping" % surface_idx)
			continue

		var verts: PackedVector3Array = verts_v
		var normals: PackedVector3Array = normals_v

		if indices_v == null:
			var i := 0
			while i < verts.size():
				_try_add_triangle(triangles, verts[i], verts[i + 1], verts[i + 2],
						normals[i], normals[i + 1], normals[i + 2])
				i += 3
		else:
			var indices: PackedInt32Array = indices_v
			var i := 0
			while i < indices.size():
				var i0 := indices[i]
				var i1 := indices[i + 1]
				var i2 := indices[i + 2]
				_try_add_triangle(triangles, verts[i0], verts[i1], verts[i2],
						normals[i0], normals[i1], normals[i2])
				i += 3
	return triangles


func _try_add_triangle(triangles: Array, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var avg_normal := (na + nb + nc).normalized()
	if avg_normal.dot(Vector3.UP) >= top_facing_threshold:
		triangles.append({"a": a, "b": b, "c": c, "normal": avg_normal})

func _raycast_down(x: float, z: float, aabb: AABB, triangles: Array) -> Dictionary:
	var margin := 1.0
	var from := Vector3(x, aabb.end.y + margin, z)
	var dir := Vector3.DOWN

	var best_y := -INF
	var best_normal := Vector3.UP
	var found := false

	for tri in triangles:
		var hit = Geometry3D.ray_intersects_triangle(from, dir, tri["a"], tri["b"], tri["c"])
		if hit != null and hit.y > best_y:
			best_y = hit.y
			best_normal = tri["normal"]
			found = true

	if not found:
		return {}
	return {"position": Vector3(x, best_y, z), "normal": best_normal}

func _generate_poisson_points(spacing: float, aabb: AABB) -> Array[Vector2]:
	var size_x: float = max(aabb.size.x, 0.01)
	var size_z: float = max(aabb.size.z, 0.01)
	var cell_size: float = spacing / sqrt(2.0)
	var grid_cols: int = max(1, int(ceil(size_x / cell_size)))
	var grid_rows: int = max(1, int(ceil(size_z / cell_size)))

	var grid: Array[int] = []
	grid.resize(grid_cols * grid_rows)
	grid.fill(-1)

	var points: Array[Vector2] = []
	var active: Array[int] = []

	var first := Vector2(_rng.randf_range(0.0, size_x), _rng.randf_range(0.0, size_z))
	points.append(first)
	active.append(0)
	_grid_mark(grid, grid_cols, grid_rows, cell_size, 0, first)

	while active.size() > 0:
		var active_slot: int = _rng.randi_range(0, active.size() - 1)
		var point_index: int = active[active_slot]
		var origin: Vector2 = points[point_index]
		var found_candidate := false

		for attempt in max_sample_attempts:
			var candidate := _sample_annulus(origin, spacing)
			if candidate.x < 0.0 or candidate.x > size_x:
				continue
			if candidate.y < 0.0 or candidate.y > size_z:
				continue

			if _is_valid_point(candidate, spacing, points, grid, grid_cols, grid_rows, cell_size):
				var new_index := points.size()
				points.append(candidate)
				active.append(new_index)
				_grid_mark(grid, grid_cols, grid_rows, cell_size, new_index, candidate)
				found_candidate = true
				break

		if not found_candidate:
			active.remove_at(active_slot)

	for idx in points.size():
		points[idx] += Vector2(aabb.position.x, aabb.position.z)

	return points


func _sample_annulus(origin: Vector2, spacing: float) -> Vector2:
	var angle: float = _rng.randf_range(0.0, TAU)
	var dist: float = _rng.randf_range(spacing, spacing * 2.0)
	return Vector2(origin.x + cos(angle) * dist, origin.y + sin(angle) * dist)


func _is_valid_point(candidate: Vector2, spacing: float, points: Array[Vector2], grid: Array[int],
		grid_cols: int, grid_rows: int, cell_size: float) -> bool:
	var gx: int = clampi(int(candidate.x / cell_size), 0, grid_cols - 1)
	var gy: int = clampi(int(candidate.y / cell_size), 0, grid_rows - 1)

	for dy in range(-2, 3):
		var ny := gy + dy
		if ny < 0 or ny >= grid_rows:
			continue
		for dx in range(-2, 3):
			var nx := gx + dx
			if nx < 0 or nx >= grid_cols:
				continue
			var idx: int = grid[ny * grid_cols + nx]
			if idx == -1:
				continue
			var other: Vector2 = points[idx]
			if candidate.distance_squared_to(other) < spacing * spacing:
				return false
	return true


func _grid_mark(grid: Array[int], grid_cols: int, grid_rows: int, cell_size: float, index: int, p: Vector2) -> void:
	var gx: int = clampi(int(p.x / cell_size), 0, grid_cols - 1)
	var gy: int = clampi(int(p.y / cell_size), 0, grid_rows - 1)
	grid[gy * grid_cols + gx] = index


func _place_rock_at(local_pos: Vector3, surface_normal: Vector3, enabled_types: Array[String]) -> void:
	var normal := surface_normal if align_to_surface_normal else Vector3.UP

	var biome := _pick_weighted_biome()
	if biome.is_empty():
		push_warning("MeshRockScatter: all biome weights are zero, skipping rock placement")
		return

	var type_name: String = _pick_type(enabled_types)
	if type_name.is_empty():
		return
	var scene_path := _random_scene_path(type_name, biome)
	if scene_path.is_empty():
		push_warning("MeshRockScatter: no scene path resolved for type %s" % type_name)
		return

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_warning("MeshRockScatter: could not load %s" % scene_path)
		return

	var container := _get_or_create_container(type_name)

	var instance := packed.instantiate()
	container.add_child(instance)
	if Engine.is_editor_hint():
		var edited_root := get_tree().edited_scene_root
		if edited_root:
			instance.owner = edited_root

	instance.set_meta(GENERATED_META, true)

	var max_spin := deg_to_rad(rotation_variance_degrees)
	var spin := _rng.randf_range(0.0, max_spin)
	instance.transform.basis = _basis_from_up(normal, spin)
	instance.transform.origin = local_pos + normal * surface_offset

	var s_scale := _rng.randf_range(scale_min, scale_max)
	instance.scale *= s_scale


func _random_scene_path(type_name: String, biome: String) -> String:
	var root_path: String
	var singular: String
	var count: int

	match type_name:
		CONTAINER_ROCKS:
			root_path = rocks_path
			singular = "rock"
			count = ROCK_COUNT
		CONTAINER_BOULDERS:
			root_path = boulders_path
			singular = "boulder"
			count = BOULDER_COUNT
		CONTAINER_PEBBLES:
			root_path = pebbles_path
			singular = "pebble"
			count = PEBBLE_COUNT
		_:
			return ""

	var index := _rng.randi_range(1, count)
	return "%s/%s/nb_%s%d_%s.tscn" % [root_path, biome, singular, index, biome]


func _amount_for_type(type_name: String) -> float:
	match type_name:
		CONTAINER_ROCKS:
			return rocks_amount
		CONTAINER_BOULDERS:
			return boulders_amount
		CONTAINER_PEBBLES:
			return pebbles_amount
	return 0.0


func _pick_type(enabled_types: Array[String]) -> String:
	if enabled_types.size() == 1:
		return enabled_types[0]

	var weights: Dictionary = {}
	var total := 0.0
	for t in enabled_types:
		var w := _amount_for_type(t)
		weights[t] = w
		total += w

	if total <= 0.0:
		return enabled_types[_rng.randi_range(0, enabled_types.size() - 1)]

	var roll := _rng.randf_range(0.0, total)
	var cumulative := 0.0
	for t in enabled_types:
		cumulative += weights[t]
		if roll <= cumulative:
			return t

	return enabled_types[enabled_types.size() - 1]


func _get_or_create_container(type_name: String) -> Node3D:
	var container := surface_mesh.get_node_or_null(type_name) as Node3D
	if container == null:
		container = Node3D.new()
		container.name = type_name
		surface_mesh.add_child(container)
		if Engine.is_editor_hint():
			var edited_root := get_tree().edited_scene_root
			if edited_root:
				container.owner = edited_root
	return container


func _basis_from_up(up: Vector3, spin: float) -> Basis:
	up = up.normalized()
	var arbitrary := Vector3.RIGHT
	if abs(up.dot(arbitrary)) > 0.95:
		arbitrary = Vector3.FORWARD
	var right := arbitrary.cross(up).normalized()
	var forward := right.cross(up).normalized()
	var result_basis := Basis(right, up, forward)
	return result_basis.rotated(up, spin)


func _biome_weights() -> Dictionary:
	return {
		"canyon": biome_canyon,
		"cave": biome_cave,
		"desert": biome_desert,
		"grey": biome_grey,
		"ice": biome_ice,
		"moss": biome_moss,
		"river": biome_river,
		"sand": biome_sand,
		"swamp": biome_swamp,
		"verdant": biome_verdant,
	}


func _pick_weighted_biome() -> String:
	var weights := _biome_weights()
	var total := 0.0
	for biome in weights:
		total += weights[biome]

	if total <= 0.0:
		return ""

	var roll := _rng.randf_range(0.0, total)
	var cumulative := 0.0
	for biome in weights:
		cumulative += weights[biome]
		if roll <= cumulative:
			return biome

	return weights.keys()[weights.size() - 1]


func _clear_container(type_name: String) -> void:
	if surface_mesh == null:
		return
	var container := surface_mesh.get_node_or_null(type_name)
	if container == null:
		return
	for child in container.get_children():
		if child.has_meta(GENERATED_META):
			child.queue_free()


func clear_rocks() -> void:
	_clear_container(CONTAINER_ROCKS)


func clear_boulders() -> void:
	_clear_container(CONTAINER_BOULDERS)


func clear_pebbles() -> void:
	_clear_container(CONTAINER_PEBBLES)
