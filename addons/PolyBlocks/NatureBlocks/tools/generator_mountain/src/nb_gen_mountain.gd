# POLYBLOCKS | NATUREBLOCKS | MOUNTAIN RANGE GENERATOR TOOL
# bukkbeek.github.io

@tool
extends Node3D

@export_tool_button("Generate Mountains") var generate_button: Callable = generate_mountains
@export_tool_button("Clear Mountains") var clear_button: Callable = clear_mountains


@export var mountain_path: Path3D

@export_group("Mountain Setup")


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
@export var biome: Biome = Biome.CANYON

@export var use_random_seed: bool = true
@export var random_seed: int = 12345
@export_range(1, 5000, 1) var mountain_amount: int = 20
@export var scale_min: float = 0.8
@export var scale_max: float = 1.6
@export_range(0.0, 360.0, 1.0) var rotation_variance_degrees: float = 360.0
@export var align_to_path_tangent: bool = false
@export var height_scale_min: float = 0.8
@export var height_scale_max: float = 1.0

@export_subgroup("Taper Ends")
@export var taper_ends: bool = true
@export_range(0.0, 0.5, 0.01) var taper_fraction: float = 0.15
@export_range(0.0, 1.0, 0.01) var taper_min_scale: float = 0.3

@export_group("Resource Paths")
var mountain_mesh_paths: Array[String] = [
	"res://PolyBlocks/NatureBlocks/tools/generator_mountain/src/nbmesh_mountain1.mesh",
	"res://PolyBlocks/NatureBlocks/tools/generator_mountain/src/nbmesh_mountain2.mesh",
	"res://PolyBlocks/NatureBlocks/tools/generator_mountain/src/nbmesh_mountain3.mesh",
	"res://PolyBlocks/NatureBlocks/tools/generator_mountain/src/nbmesh_mountain4.mesh",
]
@export_dir var materials_root_path: String = "res://PolyBlocks/NatureBlocks/source_files/materials/terrain"

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

const GENERATED_NAME_PREFIX := "nb_gen_mountain_variant_"

var _rng := RandomNumberGenerator.new()


func generate_mountains() -> void:
	if mountain_path == null or not is_instance_valid(mountain_path):
		push_warning("MountainRangeTool: Assign a Path3D node to 'Mountain Path' first.")
		return
	if mountain_path.curve == null or mountain_path.curve.get_point_count() < 2:
		push_warning("MountainRangeTool: The assigned Path3D needs a Curve3D with at least 2 points.")
		return
	if mountain_mesh_paths.is_empty():
		push_warning("MountainRangeTool: No mountain mesh paths assigned.")
		return
	if scale_min > scale_max:
		push_warning("MountainRangeTool: scale_min is greater than scale_max.")
		return
	if height_scale_min > height_scale_max:
		push_warning("MountainRangeTool: height_scale_min is greater than height_scale_max.")
		return

	if use_random_seed:
		randomize()
		random_seed = randi()

	_rng.seed = random_seed

	clear_mountains()

	var meshes: Array[Mesh] = _load_meshes()
	if meshes.is_empty():
		return

	var material: Material = _load_biome_material()
	if material == null:
		return

	var curve: Curve3D = mountain_path.curve
	var length: float = curve.get_baked_length()
	if length <= 0.0:
		push_warning("MountainRangeTool: Path3D curve has zero baked length.")
		return

	var transforms_by_variant: Array[Array] = []
	for i in range(meshes.size()):
		transforms_by_variant.append([])

	for i in range(mountain_amount):
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

		var base_scale: float = _rng.randf_range(scale_min, scale_max)
		base_scale *= _taper_multiplier(dist, length)
		var height_scale: float = _rng.randf_range(height_scale_min, height_scale_max)
		instance_basis = instance_basis.scaled(Vector3(base_scale, base_scale * height_scale, base_scale))

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
		mmi.name = "%s%d" % [GENERATED_NAME_PREFIX, variant_index + 1]
		mmi.multimesh = mm
		mmi.material_override = material

		add_child(mmi)
		_set_owner(mmi)

		generated_count += xforms.size()

	print(
		"MountainRangeTool: generated %d mountains across %d variants. biome=%s seed=%d"
		% [
			generated_count,
			meshes.size(),
			BIOME_NAMES[biome],
			random_seed
		]
	)


func clear_mountains() -> void:
	for child in get_children():
		if child.name.begins_with(GENERATED_NAME_PREFIX):
			remove_child(child)
			child.free()


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

	var world_pos: Vector3 = mountain_path.global_transform * local_pos
	var world_tangent: Vector3 = (mountain_path.global_transform.basis * tangent_local).normalized()

	return {
		"world_pos": world_pos,
		"world_tangent": world_tangent,
	}


func _taper_multiplier(dist: float, length: float) -> float:
	if not taper_ends or taper_fraction <= 0.0 or length <= 0.0:
		return 1.0

	var taper_dist: float = length * taper_fraction
	if taper_dist <= 0.0:
		return 1.0

	var edge_dist: float = min(dist, length - dist)
	if edge_dist >= taper_dist:
		return 1.0

	var t: float = edge_dist / taper_dist
	var eased: float = t * t * (3.0 - 2.0 * t)
	return lerp(taper_min_scale, 1.0, eased)


func _load_meshes() -> Array[Mesh]:
	var meshes: Array[Mesh] = []
	for path in mountain_mesh_paths:
		var mesh: Mesh = load(path)
		if mesh == null:
			push_warning("MountainRangeTool: could not load mountain mesh at %s" % path)
			continue
		meshes.append(mesh)
	return meshes


func _load_biome_material() -> Material:
	var biome_name: String = BIOME_NAMES[biome]
	var mat_path: String = "%s/nbmat_terrain_%s.tres" % [materials_root_path, biome_name]
	var material: Material = load(mat_path)

	if material == null:
		push_warning("MountainRangeTool: could not load biome material at %s" % mat_path)

	return material


func _set_owner(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
		node.owner = get_tree().edited_scene_root
