# POLYBLOCKS | NATUREBLOCKS | TREE [GENERIC] SCATTER TOOL
# bukkbeek.github.io

@tool
extends Node

@export_tool_button("Generate", "Play") var generate_button: Callable = generate
@export_tool_button("Add Trees", "Add") var add_trees_button: Callable = add_trees
@export_tool_button("Clear Trees", "Clear") var clear_trees_button: Callable = clear_trees

@export var surface_mesh: MeshInstance3D

@export_group("Scatter Settings")
@export var use_random_seed: bool = true
@export var random_seed: int = 0
@export_range(-1.0, 1.0, 0.01) var top_facing_threshold: float = 0.8
@export var surface_offset: float = 0.01
@export var align_to_surface_normal: bool = false
@export var density: float = 0.05
@export var max_trees: int = 100
@export_range(0, 360, 1) var rotation_variance_degrees: float = 360.0
@export_range(0.0, 1.0, 0.01) var scale_min: float = 0.8
@export_range(1.0, 2.0, 0.01) var scale_max: float = 1.2
@export_range(0.0, 1.0, 0.01) var cluster: float = 0.0

@export_group("Biomes")
@export_range(0.0, 100.0, 1.0) var snow: float = 100.0
@export_range(0.0, 100.0, 1.0) var tundra: float = 100.0
@export_range(0.0, 100.0, 1.0) var forest: float = 100.0
@export_range(0.0, 100.0, 1.0) var jungle: float = 100.0
@export_range(0.0, 100.0, 1.0) var savannah: float = 100.0
@export_range(0.0, 100.0, 1.0) var olive: float = 100.0
@export_range(0.0, 100.0, 1.0) var mars: float = 100.0
@export_range(0.0, 100.0, 1.0) var sakura: float = 100.0
@export_range(0.0, 100.0, 1.0) var autumn: float = 100.0
@export_range(0.0, 100.0, 1.0) var blue: float = 100.0
@export_range(0.0, 100.0, 1.0) var spooky: float = 100.0
@export_range(0.0, 100.0, 1.0) var anime: float = 100.0

@export_group("Resource Paths")
@export_dir var trees_root_path: String = "res://PolyBlocks/NatureBlocks/assets/trees"
var tree_base_names: PackedStringArray = ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5"]

const GENERATED_META := "flat_scatter_generated"
const GENERIC_NODE_NAME := "GenericTrees"
var _rng := RandomNumberGenerator.new()


func generate() -> void:
	clear_trees()
	_scatter()


func add_trees() -> void:
	_scatter()


func _scatter() -> void:
	if surface_mesh == null or surface_mesh.mesh == null:
		push_warning("MeshTreeScatter: no target_mesh (with a Mesh) assigned")
		return

	_rng.seed = randi() if use_random_seed else random_seed

	var mesh: Mesh = surface_mesh.mesh
	var aabb: AABB = mesh.get_aabb()
	var triangles := _get_top_facing_triangles(mesh)

	print("MeshTreeScatter: aabb=%s, top-facing triangles=%d" % [aabb, triangles.size()])

	if triangles.is_empty():
		push_warning("MeshTreeScatter: no triangles on target mesh meet top_facing_threshold")
		return

	var area := aabb.size.x * aabb.size.z
	var n: int = maxi(1, int(density * area))
	if max_trees > 0:
		n = mini(n, max_trees)

	var points := _generate_scatter_points(n, aabb)

	print("MeshTreeScatter: candidates=%d, cluster=%.2f" % [points.size(), cluster])

	var placed := 0
	var misses := 0

	for p in points:
		var hit := _raycast_down(p.x, p.y, aabb, triangles)
		if hit.is_empty():
			misses += 1
			continue
		_place_tree_at(hit["position"], hit["normal"])
		placed += 1

	print("MeshTreeScatter: placed=%d, raycast misses=%d" % [placed, misses])


func _generate_scatter_points(n: int, aabb: AABB) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var sx := aabb.size.x
	var sz := aabb.size.z
	var ox := aabb.position.x
	var oz := aabb.position.z

	if cluster <= 0.0:
		for i in n:
			points.append(Vector2(ox + _rng.randf() * sx, oz + _rng.randf() * sz))
		return points

	var num_centers: int = maxi(1, int(n * (1.0 - cluster) * 0.4 + 1))
	var centers: Array[Vector2] = []
	for i in num_centers:
		centers.append(Vector2(ox + _rng.randf() * sx, oz + _rng.randf() * sz))

	var radius := lerpf(maxf(sx, sz), minf(sx, sz) * 0.08, cluster)

	for i in n:
		var c := centers[_rng.randi() % centers.size()]
		var angle := _rng.randf() * TAU
		var dist := _rng.randf() * radius
		points.append(Vector2(
			clampf(c.x + cos(angle) * dist, ox, ox + sx),
			clampf(c.y + sin(angle) * dist, oz, oz + sz)
		))

	return points


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
			push_warning("MeshTreeScatter: surface %d has no vertex/normal data, skipping" % surface_idx)
			continue

		var verts: PackedVector3Array = verts_v
		var normals: PackedVector3Array = normals_v

		if indices_v == null:
			var i := 0
			while i + 2 < verts.size():
				_try_add_triangle(triangles, verts[i], verts[i+1], verts[i+2],
						normals[i], normals[i+1], normals[i+2])
				i += 3
		else:
			var indices: PackedInt32Array = indices_v
			var i := 0
			while i + 2 < indices.size():
				_try_add_triangle(triangles, verts[indices[i]], verts[indices[i+1]], verts[indices[i+2]],
						normals[indices[i]], normals[indices[i+1]], normals[indices[i+2]])
				i += 3

	return triangles


func _try_add_triangle(triangles: Array, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var avg_normal := (na + nb + nc).normalized()
	if avg_normal.dot(Vector3.UP) >= top_facing_threshold:
		triangles.append({"a": a, "b": b, "c": c, "normal": avg_normal})


func _raycast_down(x: float, z: float, aabb: AABB, triangles: Array) -> Dictionary:
	var from := Vector3(x, aabb.end.y + 1.0, z)
	var best_y := -INF
	var best_normal := Vector3.UP
	var found := false

	for tri in triangles:
		var hit = Geometry3D.ray_intersects_triangle(from, Vector3.DOWN, tri["a"], tri["b"], tri["c"])
		if hit != null and hit.y > best_y:
			best_y = hit.y
			best_normal = tri["normal"]
			found = true

	if not found:
		return {}
	return {"position": Vector3(x, best_y, z), "normal": best_normal}


func _place_tree_at(local_pos: Vector3, surface_normal: Vector3) -> void:
	var normal := surface_normal if align_to_surface_normal else Vector3.UP
	var biome := _pick_weighted_biome()

	if biome.is_empty():
		push_warning("MeshTreeScatter: all biome weights are zero, skipping tree placement")
		return

	var base_name: String = tree_base_names[_rng.randi() % tree_base_names.size()]
	var number := base_name.split("_")[1]
	var scene_path := "%s/generic/%s/nb_tree%s_%s.tscn" % [trees_root_path, biome, number, biome]

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_warning("MeshTreeScatter: could not load %s" % scene_path)
		return

	var instance := packed.instantiate()

	var generic_node: Node3D = surface_mesh.get_node_or_null(GENERIC_NODE_NAME)
	if generic_node == null:
		generic_node = Node3D.new()
		generic_node.name = GENERIC_NODE_NAME
		surface_mesh.add_child(generic_node)
		if Engine.is_editor_hint():
			var root := get_tree().edited_scene_root
			if root:
				generic_node.owner = root

	generic_node.add_child(instance)

	if Engine.is_editor_hint():
		var root := get_tree().edited_scene_root
		if root:
			instance.owner = root

	instance.set_meta(GENERATED_META, true)
	instance.transform.basis = _basis_from_up(normal, _rng.randf_range(0.0, deg_to_rad(rotation_variance_degrees)))
	instance.transform.origin = local_pos + normal * surface_offset
	instance.scale *= _rng.randf_range(scale_min, scale_max)


func _basis_from_up(up: Vector3, spin: float) -> Basis:
	up = up.normalized()
	var arbitrary := Vector3.RIGHT
	if abs(up.dot(arbitrary)) > 0.95:
		arbitrary = Vector3.FORWARD
	var right := arbitrary.cross(up).normalized()
	return Basis(right, up, right.cross(up).normalized()).rotated(up, spin)


func _biome_weights() -> Dictionary:
	return {
		"snow": snow, "tundra": tundra, "forest": forest,
		"jungle": jungle, "savannah": savannah, "olive": olive,
		"mars": mars, "sakura": sakura, "autumn": autumn,
		"blue": blue, "spooky": spooky, "anime": anime
	}


func _pick_weighted_biome() -> String:
	var weights := _biome_weights()
	var total := 0.0
	for w in weights.values():
		total += w

	if total <= 0.0:
		return ""

	var roll := _rng.randf_range(0.0, total)
	var cumulative := 0.0
	for biome in weights:
		cumulative += weights[biome]
		if roll <= cumulative:
			return biome

	return weights.keys()[weights.size() - 1]


func clear_trees() -> void:
	if surface_mesh == null:
		return
	var generic_node: Node = surface_mesh.get_node_or_null(GENERIC_NODE_NAME)
	if generic_node == null:
		return
	generic_node.free()
