# POLYBLOCKS | NATUREBLOCKS | ROAD GENERATOR TOOL
# bukkbeek.github.io

@tool
extends Node3D

@export_tool_button("Generate Road") var generate_button: Callable = generate_road
@export_tool_button("Clear Road") var clear_button: Callable = clear_road

@export var road_path: Path3D

@export_group("Road Setup")
@export var road_width: float = 1.0
@export var road_level: float = 0.2
@export_range(1, 200, 1) var length_subdivisions: int = 40
@export_range(1, 20, 1) var width_subdivisions: int = 4

@export var side_top_width: float = 1.5
@export var side_height: float = 0.25

@export var outer_width: float = 2.4

@export var randomize_width: bool = true
@export var width_random_seed: int = 0
@export_range(0.0, 1.0, 0.01) var width_variance: float = 0.8
@export var width_noise_frequency: float = 0.1

@export_group("Materials")
@export var road_material: Material = preload("res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_sand.tres")
@export var road_side_material: Material = preload("res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_swamp.tres")

const ROAD_NODE_NAME := "Road"
const ROAD_SIDE_NODE_NAME := "RoadSide"

func generate_road() -> void:
	if road_path == null or not is_instance_valid(road_path):
		push_warning("ProceduralRoad: Assign a Path3D node to 'Road Path' first.")
		return
	if road_path.curve == null or road_path.curve.get_point_count() < 2:
		push_warning("ProceduralRoad: The assigned Path3D needs a Curve3D with at least 2 points.")
		return

	clear_road()
	var pts: Array = _sample_path(length_subdivisions)
	_generate_road_mesh(pts)
	_generate_road_side_mesh(pts)

func clear_road() -> void:
	for child_name in [ROAD_NODE_NAME, ROAD_SIDE_NODE_NAME]:
		var n := get_node_or_null(child_name)
		if n:
			remove_child(n)
			n.free()

func _sample_path(subdivisions: int) -> Array:
	var curve: Curve3D = road_path.curve
	var length: float = curve.get_baked_length()
	var count: int = max(subdivisions, 1)
	var result: Array = []

	for i in range(count + 1):
		var t: float = float(i) / float(count)
		var offset: float = t * length

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

		var world_pos: Vector3 = road_path.global_transform * local_pos
		var world_tangent: Vector3 = (road_path.global_transform.basis * tangent_local).normalized()

		var world_right: Vector3 = world_tangent.cross(Vector3.UP)
		if world_right.length() < 0.0001:
			world_right = road_path.global_transform.basis * Vector3.RIGHT
		world_right = world_right.normalized()

		var world_up: Vector3 = world_right.cross(world_tangent).normalized()

		result.append({
			"t": t,
			"world_pos": world_pos,
			"world_tangent": world_tangent,
			"world_right": world_right,
			"world_up": world_up,
			"dist": 0.0,
			"width_mult": 1.0,
		})

	for i in range(1, result.size()):
		var prev_pos: Vector3 = result[i - 1].world_pos
		var cur_pos: Vector3 = result[i].world_pos
		result[i].dist = result[i - 1].dist + prev_pos.distance_to(cur_pos)

	if randomize_width:
		var noise := FastNoiseLite.new()
		noise.seed = width_random_seed
		noise.frequency = max(width_noise_frequency, 0.0001)
		noise.noise_type = FastNoiseLite.NoiseType.TYPE_SIMPLEX_SMOOTH
		for i in range(result.size()):
			var n: float = noise.get_noise_1d(result[i].dist)
			result[i].width_mult = max(1.0 + n * width_variance, 0.05)

	return result

func _row_widths(mult: float) -> Dictionary:
	return {
		"road_hw": road_width * 0.5 * mult,
		"side_top_hw": side_top_width * 0.5 * mult,
		"outer_hw": outer_width * 0.5 * mult,
	}

func _profile_left(w: Dictionary) -> Array:
	return [
		Vector2(-w.outer_hw, 0.0),
		Vector2(-w.side_top_hw, side_height),
		Vector2(-w.road_hw, road_level),
	]

func _profile_right(w: Dictionary) -> Array:
	return [
		Vector2(w.road_hw, road_level),
		Vector2(w.side_top_hw, side_height),
		Vector2(w.outer_hw, 0.0),
	]

func _cross_section_cumulative(profile: Array) -> Array:
	var cum: Array = [0.0]
	for k in range(1, profile.size()):
		cum.append(cum[k - 1] + profile[k - 1].distance_to(profile[k]))
	return cum

func _generate_road_mesh(pts: Array) -> void:
	_generate_flat_strip_mesh(pts, ROAD_NODE_NAME, road_material, road_level,
		func(w: Dictionary) -> float: return w.road_hw)

func _generate_flat_strip_mesh(pts: Array, node_name: String, material: Material, height: float, hw_getter: Callable) -> void:
	var wsub: int = max(width_subdivisions, 1)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var grid: Array = []

	for i in range(pts.size()):
		var p: Dictionary = pts[i]
		var hw: float = hw_getter.call(_row_widths(p.width_mult))
		var row: Array = []
		for j in range(wsub + 1):
			var x: float = -hw + (float(j) / float(wsub)) * (hw * 2.0)
			var world_v: Vector3 = p.world_pos + p.world_right * x + p.world_up * height
			row.append(to_local(world_v))
		grid.append(row)

	for i in range(pts.size() - 1):
		for j in range(wsub):
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i + 1][j]
			var c: Vector3 = grid[i][j + 1]
			var d: Vector3 = grid[i + 1][j + 1]
			_add_quad(st, a, b, c, d)

	_finish_mesh(st, node_name, material)

func _generate_road_side_mesh(pts: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_append_profile_strip(st, pts, _profile_left)
	_append_profile_strip(st, pts, _profile_right)

	_finish_mesh(st, ROAD_SIDE_NODE_NAME, road_side_material)

func _append_profile_strip(st: SurfaceTool, pts: Array, profile_fn: Callable) -> void:
	var grid: Array = []

	for i in range(pts.size()):
		var p: Dictionary = pts[i]
		var profile: Array = profile_fn.call(_row_widths(p.width_mult))
		var row: Array = []
		for k in range(profile.size()):
			var off: Vector2 = profile[k]
			var world_v: Vector3 = p.world_pos + p.world_right * off.x + p.world_up * off.y
			row.append(to_local(world_v))
		grid.append(row)

	var seg_count: int = grid[0].size() - 1
	for i in range(pts.size() - 1):
		for k in range(seg_count):
			var a: Vector3 = grid[i][k]
			var b: Vector3 = grid[i + 1][k]
			var c: Vector3 = grid[i][k + 1]
			var d: Vector3 = grid[i + 1][k + 1]
			_add_quad(st, a, b, c, d)

func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_emit_tri(st, a, b, d)
	_emit_tri(st, a, d, c)

func _emit_tri(st: SurfaceTool, va: Vector3, vb: Vector3, vc: Vector3) -> void:
	st.add_vertex(va)
	st.add_vertex(vb)
	st.add_vertex(vc)

func _finish_mesh(st: SurfaceTool, node_name: String, material: Material) -> void:
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	add_child(mi)
	_set_owner(mi)
	if material:
		mi.set_surface_override_material(0, material)

func _set_owner(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		node.owner = get_tree().edited_scene_root
