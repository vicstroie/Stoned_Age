# POLYBLOCKS | NATUREBLOCKS | LAKE GENERATOR TOOL
# bukkbeek.github.io

@tool
extends Node3D

@export_tool_button("Generate Lake") var generate_button: Callable = generate_lake
@export_tool_button("Clear Lake") var clear_button: Callable = clear_lake

@export var lake_path: Path3D

@export_group("Lake Setup")
@export var water_level: float = 0.8
@export var water_offset: float = -3.0 
@export_range(3, 200, 1) var boundary_subdivisions: int = 64

@export var bed_depth: float = 0.0 

@export var bank_top_width: float = 6.0
@export var bank_height: float = 1.5

@export var outer_width: float = 12.0

@export var randomize_width: bool = true
@export var width_random_seed: int = 0
@export_range(0.0, 1.0, 0.01) var width_variance: float = 0.8
@export var width_noise_frequency: float = 0.1

@export_group("UV Mapping")
@export var uv_tile_size: float = 20.0

@export_group("Materials")
@export var water_material: Material = preload("res://PolyBlocks/NatureBlocks/source_files/materials/water/nbmat_water.tres")
@export var bed_material: Material = preload("res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_cave.tres")
@export var bank_material: Material = preload("res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_river.tres")

const WATER_NODE_NAME := "LakeWater"
const BED_NODE_NAME := "LakeBed"
const BANK_NODE_NAME := "LakeBank"

func generate_lake() -> void:
	if lake_path == null or not is_instance_valid(lake_path):
		push_warning("ProceduralLake: Assign a Path3D node to 'Lake Path' first.")
		return
	if lake_path.curve == null or lake_path.curve.get_point_count() < 3:
		push_warning("ProceduralLake: The assigned Path3D needs a closed Curve3D with at least 3 points.")
		return

	clear_lake()

	var sampled: Dictionary = _sample_boundary(boundary_subdivisions)
	var pts: Array = sampled.points
	var flip_winding: bool = sampled.flip_winding


	var base_y: float = _average_height(pts)

	_generate_water_mesh(pts, base_y, flip_winding)
	_generate_bed_mesh(pts, base_y, flip_winding)
	_generate_bank_mesh(pts, base_y, flip_winding)

func clear_lake() -> void:
	for child_name in [WATER_NODE_NAME, BED_NODE_NAME, BANK_NODE_NAME]:
		var n := get_node_or_null(child_name)
		if n:
			remove_child(n)
			n.free()


func _sample_boundary(subdivisions: int) -> Dictionary:
	var curve: Curve3D = lake_path.curve
	var length: float = curve.get_baked_length()
	var count: int = max(subdivisions, 3)
	var result: Array = []

	for i in range(count):
		var t: float = float(i) / float(count)
		var offset: float = t * length
		var local_pos: Vector3 = curve.sample_baked(offset, true)
		var world_pos: Vector3 = lake_path.global_transform * local_pos
		result.append({
			"world_pos": world_pos,
			"world_tangent": Vector3.FORWARD,
			"world_right": Vector3.RIGHT,
			"world_in": Vector3.RIGHT,
			"dist": 0.0,
			"width_mult": 1.0,
		})


	for i in range(count):
		var prev_pos: Vector3 = result[(i - 1 + count) % count].world_pos
		var next_pos: Vector3 = result[(i + 1) % count].world_pos

		var tangent: Vector3 = next_pos - prev_pos
		if tangent.length() < 0.00001:
			tangent = Vector3.FORWARD
		tangent = tangent.normalized()

		var right: Vector3 = tangent.cross(Vector3.UP)
		if right.length() < 0.0001:
			right = Vector3.RIGHT
		right = right.normalized()

		result[i].world_tangent = tangent
		result[i].world_right = right


	for i in range(1, count):
		result[i].dist = result[i - 1].dist + result[i - 1].world_pos.distance_to(result[i].world_pos)
	var perimeter: float = result[count - 1].dist + result[count - 1].world_pos.distance_to(result[0].world_pos)

	if randomize_width:
		var noise := FastNoiseLite.new()
		noise.seed = width_random_seed
		noise.frequency = max(width_noise_frequency, 0.0001)
		noise.noise_type = FastNoiseLite.NoiseType.TYPE_SIMPLEX_SMOOTH
		for i in range(count):
			var n: float = noise.get_noise_1d(result[i].dist)
			result[i].width_mult = max(1.0 + n * width_variance, 0.05)

	var centroid: Vector3 = Vector3.ZERO
	for p in result:
		centroid += p.world_pos
	centroid /= float(count)

	var vote: float = 0.0
	for p in result:
		vote += (centroid - p.world_pos).dot(p.world_right)
	var inward_sign: float = 1.0 if vote >= 0.0 else -1.0

	for p in result:
		p.world_in = p.world_right * inward_sign

	var area: float = 0.0
	for i in range(count):
		var p0: Vector3 = result[i].world_pos
		var p1: Vector3 = result[(i + 1) % count].world_pos
		area += p0.x * p1.z - p1.x * p0.z
	var flip_winding: bool = area < 0.0

	return {"points": result, "perimeter": perimeter, "flip_winding": flip_winding}

func _average_height(pts: Array) -> float:
	var sum: float = 0.0
	for p in pts:
		sum += p.world_pos.y
	return sum / float(pts.size())

func _widths(mult: float) -> Dictionary:
	return {
		"bank_top_hw": bank_top_width * 0.5 * mult,
		"outer_hw": outer_width * 0.5 * mult,
	}


func _height_pos(p: Dictionary, base_y: float, offset: Vector2) -> Vector3:
	var flat_pos: Vector3 = Vector3(p.world_pos.x, base_y, p.world_pos.z)
	return flat_pos + p.world_in * offset.x + Vector3.UP * offset.y

func _profile_outer(w: Dictionary) -> Array:
	return [
		Vector2(-w.outer_hw, 0.0),
		Vector2(-w.bank_top_hw, bank_height),
	]

func _profile_inner(w: Dictionary) -> Array:

	return [
		Vector2(-w.bank_top_hw, bank_height),
		Vector2(0.0, -bed_depth),
	]

func _cross_section_cumulative(profile: Array) -> Array:
	var cum: Array = [0.0]
	for k in range(1, profile.size()):
		cum.append(cum[k - 1] + profile[k - 1].distance_to(profile[k]))
	return cum

func _generate_water_mesh(pts: Array, base_y: float, flip_winding: bool) -> void:
	_generate_flat_polygon_mesh(pts, base_y, flip_winding, WATER_NODE_NAME, water_material,
		func(p: Dictionary) -> float: return water_offset * p.width_mult,
		water_level)

func _generate_bed_mesh(pts: Array, base_y: float, flip_winding: bool) -> void:
	_generate_flat_polygon_mesh(pts, base_y, flip_winding, BED_NODE_NAME, bed_material,
		func(_p: Dictionary) -> float: return 0.0,
		-bed_depth)


func _generate_flat_polygon_mesh(pts: Array, base_y: float, flip_winding: bool, node_name: String, material: Material, inward_offset_fn: Callable, height_offset: float) -> void:
	var tile: float = max(uv_tile_size, 0.0001)

	var boundary_world: Array = []
	for p in pts:
		var inward_offset: float = inward_offset_fn.call(p)
		boundary_world.append(_height_pos(p, base_y, Vector2(inward_offset, height_offset)))

	var polygon_2d := PackedVector2Array()
	for v in boundary_world:
		polygon_2d.append(Vector2(v.x, v.z))

	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon_2d)
	if indices.size() < 3:
		push_warning("ProceduralLake: Could not triangulate %s — check that the lake boundary is a simple closed loop." % node_name)
		return

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

		var va: Vector3 = boundary_world[i0]
		var vb: Vector3 = boundary_world[i1]
		var vc: Vector3 = boundary_world[i2]

		_emit_tri(st,
			to_local(va), Vector2(va.x, va.z) / tile,
			to_local(vb), Vector2(vb.x, vb.z) / tile,
			to_local(vc), Vector2(vc.x, vc.z) / tile)
		i += 3

	_finish_mesh(st, node_name, material)

func _generate_bank_mesh(pts: Array, base_y: float, flip_winding: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tile: float = max(uv_tile_size, 0.0001)

	_append_profile_ring(st, pts, base_y, tile, flip_winding, _profile_outer)
	_append_profile_ring(st, pts, base_y, tile, flip_winding, _profile_inner)

	_finish_mesh(st, BANK_NODE_NAME, bank_material)


func _append_profile_ring(st: SurfaceTool, pts: Array, base_y: float, tile: float, flip_winding: bool, profile_fn: Callable) -> void:
	var count: int = pts.size()

	var grid: Array = []
	var cum_rows: Array = []
	for i in range(count):
		var w: Dictionary = _widths(pts[i].width_mult)
		var profile: Array = profile_fn.call(w)
		var row: Array = []
		for k in range(profile.size()):
			row.append(to_local(_height_pos(pts[i], base_y, profile[k])))
		grid.append(row)
		cum_rows.append(_cross_section_cumulative(profile))

	var seg_count: int = grid[0].size() - 1
	for i in range(count):
		var i_next: int = (i + 1) % count
		var seg_len: float = pts[i].world_pos.distance_to(pts[i_next].world_pos)
		var v_i: float = pts[i].dist / tile
		var v_next: float = (pts[i].dist + seg_len) / tile

		var row_a: Array = grid[i]
		var row_b: Array = grid[i_next]
		var cum_a: Array = cum_rows[i]
		var cum_b: Array = cum_rows[i_next]
		var va_v: float = v_i
		var vb_v: float = v_next
		if flip_winding:
			row_a = grid[i_next]
			row_b = grid[i]
			cum_a = cum_rows[i_next]
			cum_b = cum_rows[i]
			va_v = v_next
			vb_v = v_i

		for k in range(seg_count):
			var a: Vector3 = row_a[k]
			var b: Vector3 = row_b[k]
			var c: Vector3 = row_a[k + 1]
			var d: Vector3 = row_b[k + 1]
			var uva: Vector2 = Vector2(cum_a[k] / tile, va_v)
			var uvb: Vector2 = Vector2(cum_b[k] / tile, vb_v)
			var uvc: Vector2 = Vector2(cum_a[k + 1] / tile, va_v)
			var uvd: Vector2 = Vector2(cum_b[k + 1] / tile, vb_v)
			_add_quad(st, a, uva, b, uvb, c, uvc, d, uvd)

func _add_quad(st: SurfaceTool, a: Vector3, uva: Vector2, b: Vector3, uvb: Vector2, c: Vector3, uvc: Vector2, d: Vector3, uvd: Vector2) -> void:
	_emit_tri(st, a, uva, b, uvb, d, uvd)
	_emit_tri(st, a, uva, d, uvd, c, uvc)

func _emit_tri(st: SurfaceTool, va: Vector3, uva: Vector2, vb: Vector3, uvb: Vector2, vc: Vector3, uvc: Vector2) -> void:
	st.set_uv(uva)
	st.add_vertex(va)
	st.set_uv(uvb)
	st.add_vertex(vb)
	st.set_uv(uvc)
	st.add_vertex(vc)

func _finish_mesh(st: SurfaceTool, node_name: String, material: Material) -> void:
	st.generate_normals()
	st.generate_tangents()
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
