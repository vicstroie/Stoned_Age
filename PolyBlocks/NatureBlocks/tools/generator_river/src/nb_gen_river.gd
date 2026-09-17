# POLYBLOCKS | NATUREBLOCKS | RIVER GENERATOR TOOL
# bukkbeek.github.io

@tool
extends Node3D

@export_tool_button("Generate River") var generate_button: Callable = generate_river
@export_tool_button("Clear River") var clear_button: Callable = clear_river

@export var river_path: Path3D

@export_group("River Setup")
@export var water_width: float = 6.0
@export var water_level: float = 0.8
@export_range(1, 200, 1) var length_subdivisions: int = 40
@export_range(1, 20, 1) var width_subdivisions: int = 4

@export var bed_width: float = 4.0
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
@export var water_material: Material = preload("res://PolyBlocks/NatureBlocks/source_files/materials/water/nbmat_water_flow.tres")
@export var bed_material: Material = preload("res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_cave.tres")
@export var bank_material: Material = preload("res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_river.tres")

@export_group("Splashes")
@export var splash_scene: PackedScene = preload("res://PolyBlocks/NatureBlocks/source_files/fx/nbfx_water_splash.tscn")
@export var splash_width: float = 2.0
@export_range(0.0, 90.0, 0.1) var splash_angle_threshold_deg: float = 60.0
@export var splash_offset: Vector3 = Vector3.ZERO
@export var splash_scale_min: float = 0.7
@export var splash_scale_max: float = 1.15

const WATER_NODE_NAME := "RiverWater"
const BED_NODE_NAME := "RiverBed"
const BANK_NODE_NAME := "RiverBank"
const SPLASHES_NODE_NAME := "splashes"

func generate_river() -> void:
	if river_path == null or not is_instance_valid(river_path):
		push_warning("ProceduralRiver: Assign a Path3D node to 'River Path' first.")
		return
	if river_path.curve == null or river_path.curve.get_point_count() < 2:
		push_warning("ProceduralRiver: The assigned Path3D needs a Curve3D with at least 2 points.")
		return

	clear_river()
	var pts: Array = _sample_path(length_subdivisions)
	_generate_water_mesh(pts)
	_generate_bed_mesh(pts)
	_generate_bank_mesh(pts)
	_generate_splash_effects(pts)

func clear_river() -> void:
	for child_name in [WATER_NODE_NAME, BED_NODE_NAME, BANK_NODE_NAME, SPLASHES_NODE_NAME]:
		var n := get_node_or_null(child_name)
		if n:
			remove_child(n)
			n.free()

func _sample_path(subdivisions: int) -> Array:
	var curve: Curve3D = river_path.curve
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

		var world_pos: Vector3 = river_path.global_transform * local_pos
		var world_tangent: Vector3 = (river_path.global_transform.basis * tangent_local).normalized()

		var world_right: Vector3 = world_tangent.cross(Vector3.UP)
		if world_right.length() < 0.0001:
			world_right = river_path.global_transform.basis * Vector3.RIGHT
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
		"water_hw": water_width * 0.5 * mult,
		"bed_hw": bed_width * 0.5 * mult,
		"bank_top_hw": bank_top_width * 0.5 * mult,
		"outer_hw": outer_width * 0.5 * mult,
	}

func _profile_inner_left(w: Dictionary) -> Array:
	var bed_y: float = -bed_depth
	return [
		Vector2(-w.bank_top_hw, bank_height),
		Vector2(-w.bed_hw, bed_y),
	]

func _profile_inner_right(w: Dictionary) -> Array:
	var bed_y: float = -bed_depth
	return [
		Vector2(w.bed_hw, bed_y),
		Vector2(w.bank_top_hw, bank_height),
	]

func _profile_outer_left(w: Dictionary) -> Array:
	return [
		Vector2(-w.outer_hw, 0.0),
		Vector2(-w.bank_top_hw, bank_height),
	]

func _profile_outer_right(w: Dictionary) -> Array:
	return [
		Vector2(w.bank_top_hw, bank_height),
		Vector2(w.outer_hw, 0.0),
	]

func _cross_section_cumulative(profile: Array) -> Array:
	var cum: Array = [0.0]
	for k in range(1, profile.size()):
		cum.append(cum[k - 1] + profile[k - 1].distance_to(profile[k]))
	return cum

func _generate_water_mesh(pts: Array) -> void:
	_generate_flat_strip_mesh(pts, WATER_NODE_NAME, water_material, water_level,
		func(w: Dictionary) -> float: return w.water_hw)

func _generate_bed_mesh(pts: Array) -> void:
	_generate_flat_strip_mesh(pts, BED_NODE_NAME, bed_material, -bed_depth,
		func(w: Dictionary) -> float: return w.bed_hw)

func _generate_flat_strip_mesh(pts: Array, node_name: String, material: Material, height: float, hw_getter: Callable) -> void:
	var wsub: int = max(width_subdivisions, 1)
	var tile: float = max(uv_tile_size, 0.0001)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var grid: Array = []
	var xs_rows: Array = []

	for i in range(pts.size()):
		var p: Dictionary = pts[i]
		var hw: float = hw_getter.call(_row_widths(p.width_mult))
		var row: Array = []
		var xs: Array = []
		for j in range(wsub + 1):
			var x: float = -hw + (float(j) / float(wsub)) * (hw * 2.0)
			xs.append(x)
			var world_v: Vector3 = p.world_pos + p.world_right * x + p.world_up * height
			row.append(to_local(world_v))
		grid.append(row)
		xs_rows.append(xs)

	for i in range(pts.size() - 1):
		var v0: float = pts[i].dist / tile
		var v1: float = pts[i + 1].dist / tile
		for j in range(wsub):
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i + 1][j]
			var c: Vector3 = grid[i][j + 1]
			var d: Vector3 = grid[i + 1][j + 1]
			var uva: Vector2 = Vector2(xs_rows[i][j] / tile, v0)
			var uvb: Vector2 = Vector2(xs_rows[i + 1][j] / tile, v1)
			var uvc: Vector2 = Vector2(xs_rows[i][j + 1] / tile, v0)
			var uvd: Vector2 = Vector2(xs_rows[i + 1][j + 1] / tile, v1)
			_add_quad(st, a, uva, b, uvb, c, uvc, d, uvd)

	_finish_mesh(st, node_name, material)

func _generate_bank_mesh(pts: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tile: float = max(uv_tile_size, 0.0001)

	_append_profile_strip(st, pts, tile, _profile_outer_left)
	_append_profile_strip(st, pts, tile, _profile_inner_left)
	_append_profile_strip(st, pts, tile, _profile_inner_right)
	_append_profile_strip(st, pts, tile, _profile_outer_right)

	_finish_mesh(st, BANK_NODE_NAME, bank_material)

func _append_profile_strip(st: SurfaceTool, pts: Array, tile: float, profile_fn: Callable) -> void:
	var grid: Array = []
	var cum_rows: Array = []

	for i in range(pts.size()):
		var p: Dictionary = pts[i]
		var profile: Array = profile_fn.call(_row_widths(p.width_mult))
		var cum: Array = _cross_section_cumulative(profile)
		var row: Array = []
		for k in range(profile.size()):
			var off: Vector2 = profile[k]
			var world_v: Vector3 = p.world_pos + p.world_right * off.x + p.world_up * off.y
			row.append(to_local(world_v))
		grid.append(row)
		cum_rows.append(cum)

	var seg_count: int = grid[0].size() - 1
	for i in range(pts.size() - 1):
		var v0: float = pts[i].dist / tile
		var v1: float = pts[i + 1].dist / tile
		for k in range(seg_count):
			var a: Vector3 = grid[i][k]
			var b: Vector3 = grid[i + 1][k]
			var c: Vector3 = grid[i][k + 1]
			var d: Vector3 = grid[i + 1][k + 1]
			var uva: Vector2 = Vector2(cum_rows[i][k] / tile, v0)
			var uvb: Vector2 = Vector2(cum_rows[i + 1][k] / tile, v1)
			var uvc: Vector2 = Vector2(cum_rows[i][k + 1] / tile, v0)
			var uvd: Vector2 = Vector2(cum_rows[i + 1][k + 1] / tile, v1)
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

func _generate_splash_effects(pts: Array) -> void:
	if splash_scene == null:
		push_warning("ProceduralRiver: Assign a Splash Scene to spawn waterfall splashes.")
		return
	if pts.size() < 3:
		return

	var splashes_node := Node3D.new()
	splashes_node.name = SPLASHES_NODE_NAME
	add_child(splashes_node)
	_set_owner(splashes_node)

	var threshold_rad: float = deg_to_rad(splash_angle_threshold_deg)

	for i in range(1, pts.size() - 1):
		var pitch_prev: float = _tangent_pitch(pts[i - 1].world_tangent)
		var pitch_next: float = _tangent_pitch(pts[i + 1].world_tangent)

		if abs(pitch_next - pitch_prev) >= threshold_rad:
			_spawn_splash_row(splashes_node, pts[i])

func _tangent_pitch(tangent: Vector3) -> float:
	var horiz_len: float = Vector2(tangent.x, tangent.z).length()
	return atan2(tangent.y, horiz_len)

func _spawn_splash_row(parent: Node3D, p: Dictionary) -> void:
	var full_width: float = water_width * p.width_mult
	var w: float = max(splash_width, 0.01)
	var count: int = max(int(ceil(full_width / w)), 1)
	var spacing: float = full_width / float(count)

	for j in range(count):
		var x: float = -full_width * 0.5 + spacing * (float(j) + 0.5)
		var center_ratio: float = 1.0 - abs(x / (full_width * 0.5))
		var world_pos: Vector3 = p.world_pos + p.world_right * x + p.world_up * water_level
		world_pos += p.world_right * splash_offset.x + p.world_up * splash_offset.y + p.world_tangent * splash_offset.z

		var inst: Node = splash_scene.instantiate()
		parent.add_child(inst)
		_set_owner(inst)

		if inst is Node3D:
			var look_basis: Basis = Basis.looking_at(p.world_tangent, p.world_up)
			var s: float = lerp(splash_scale_min, splash_scale_max, center_ratio)
			look_basis = look_basis.scaled(Vector3(s, s, s))
			(inst as Node3D).global_transform = Transform3D(look_basis, world_pos)

func _set_owner(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		node.owner = get_tree().edited_scene_root
