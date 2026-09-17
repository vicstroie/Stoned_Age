# POLYBLOCKS | NATUREBLOCKS | BUILDER
# bukkbeek.github.io

@tool
extends Node
class_name NatureBlocks

enum GroundMaterial {
	DEFAULT,
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

@export var surface_mesh: MeshInstance3D

@export_group("Terrain Material")
@export var ground_material: GroundMaterial = GroundMaterial.DEFAULT
@export_range(0, 32, 1) var surface_index: int = 0

@export_tool_button("Apply Material", "Play") var apply_button: Callable = _apply_material
@export_tool_button("Clear Override", "Clear") var clear_button: Callable = _clear_material

@export_group("Tool Setup")
@export var auto_instantiate_tools: bool = true
@export_tool_button("Instantiate Tools", "Add") var instantiate_tools_button: Callable = instantiate_tools


const GROUND_MATERIAL_PATHS := {
	GroundMaterial.CANYON: "res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_canyon.tres",
	GroundMaterial.CAVE: "res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_cave.tres",
	GroundMaterial.DESERT: "res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_desert.tres",
	GroundMaterial.GREY: "res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_grey.tres",
	GroundMaterial.ICE: "res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_ice.tres",
	GroundMaterial.MOSS: "res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_moss.tres",
	GroundMaterial.RIVER: "res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_river.tres",
	GroundMaterial.SAND: "res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_sand.tres",
	GroundMaterial.SWAMP: "res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_swamp.tres",
	GroundMaterial.VERDANT: "res://PolyBlocks/NatureBlocks/source_files/materials/terrain/nbmat_terrain_verdant.tres",
}

const GENERATOR_SCENE_PATHS: Array[String] = [
	"res://PolyBlocks/NatureBlocks/tools/generator_cliff/nb_gen_cliff.tscn",
	"res://PolyBlocks/NatureBlocks/tools/generator_lake/nb_gen_lake.tscn",
	"res://PolyBlocks/NatureBlocks/tools/generator_mountain/nb_gen_mountain.tscn",
	"res://PolyBlocks/NatureBlocks/tools/generator_river/nb_gen_river.tscn",
	"res://PolyBlocks/NatureBlocks/tools/generator_road/nb_gen_road.tscn",
]

const SCATTER_VEGETATION_SCENE_PATHS: Array[String] = [
	"res://PolyBlocks/NatureBlocks/tools/scatter_boardleaf/nb_scatter_boardleaf.tscn",
	"res://PolyBlocks/NatureBlocks/tools/scatter_ferns/nb_scatter_fern.tscn",
	"res://PolyBlocks/NatureBlocks/tools/scatter_flowers/nb_scatter_flowers.tscn",
	"res://PolyBlocks/NatureBlocks/tools/scatter_grass/nb_scatter_grass.tscn",
	"res://PolyBlocks/NatureBlocks/tools/scatter_ground/nb_scatter_ground.tscn",
	"res://PolyBlocks/NatureBlocks/tools/scatter_reeds/nb_scatter_reeds.tscn",
	"res://PolyBlocks/NatureBlocks/tools/scatter_shrubs/nb_scatter_shrubs.tscn",
]

const SCATTER_TREES_SCENE_PATHS: Array[String] = [
	"res://PolyBlocks/NatureBlocks/tools/scatter_trees/nb_scatter_birch.tscn",
	"res://PolyBlocks/NatureBlocks/tools/scatter_trees/nb_scatter_palm.tscn",
	"res://PolyBlocks/NatureBlocks/tools/scatter_trees/nb_scatter_pine.tscn",
	"res://PolyBlocks/NatureBlocks/tools/scatter_trees/nb_scatter_tree.tscn",
	"res://PolyBlocks/NatureBlocks/tools/scatter_trees/nb_scatter_willow.tscn",
]


func _apply_material() -> void:
	if auto_instantiate_tools:
		instantiate_tools()

	if surface_mesh == null:
		push_warning("TerrainMaterialTool: no surface_mesh assigned.")
		return

	if surface_mesh.mesh == null:
		push_warning("TerrainMaterialTool: surface_mesh has no mesh.")
		return

	if surface_index < 0 or surface_index >= surface_mesh.mesh.get_surface_count():
		push_warning(
			"TerrainMaterialTool: invalid surface index %d. Mesh has %d surfaces."
			% [surface_index, surface_mesh.mesh.get_surface_count()]
		)
		return

	if ground_material == GroundMaterial.DEFAULT:
		surface_mesh.set_surface_override_material(surface_index, null)
		print("TerrainMaterialTool: surface override cleared (DEFAULT).")
		return

	var mat_path: String = GROUND_MATERIAL_PATHS.get(ground_material, "")

	if mat_path.is_empty():
		push_warning("TerrainMaterialTool: no material path for enum value.")
		return

	var material: Material = load(mat_path)

	if material == null:
		push_warning(
			"TerrainMaterialTool: failed to load material at: %s"
			% mat_path
		)
		return

	surface_mesh.set_surface_override_material(surface_index, material)

	print(
		"TerrainMaterialTool: applied '%s' to surface %d of %s."
		% [ground_material, surface_index, surface_mesh.name]
	)


func _clear_material() -> void:
	if surface_mesh == null:
		return

	if surface_mesh.mesh == null:
		return

	if surface_index < 0 or surface_index >= surface_mesh.mesh.get_surface_count():
		return

	surface_mesh.set_surface_override_material(surface_index, null)

	print(
		"TerrainMaterialTool: surface override cleared on surface %d."
		% surface_index
	)


func instantiate_tools() -> void:
	var gen_node := _get_or_create_group_node("ProceduralGeneration", true)
	_instantiate_tool_scenes(gen_node, GENERATOR_SCENE_PATHS)

	var veg_node := _get_or_create_group_node("ScatterVegetation", false)
	_instantiate_tool_scenes(veg_node, SCATTER_VEGETATION_SCENE_PATHS)

	var trees_node := _get_or_create_group_node("ScatterTrees", false)
	_instantiate_tool_scenes(trees_node, SCATTER_TREES_SCENE_PATHS)


func _get_or_create_group_node(group_name: String, is_3d: bool = false) -> Node:
	var group_node: Node = get_node_or_null(group_name)
	if group_node == null:
		if is_3d:
			group_node = Node3D.new()
		else:
			group_node = Node.new()
		group_node.name = group_name
		add_child(group_node)
		_set_node_owner(group_node)
	return group_node


func _instantiate_tool_scenes(group_node: Node, scene_paths: Array[String]) -> void:
	for path in scene_paths:
		var scene: PackedScene = load(path)
		if scene == null:
			push_warning("TerrainMaterialTool: failed to load tool scene at: %s" % path)
			continue

		var existing_node: Node = null
		for child in group_node.get_children():
			if child.scene_file_path == path:
				existing_node = child
				break

		if existing_node != null:
			if surface_mesh != null and "surface_mesh" in existing_node:
				existing_node.set("surface_mesh", surface_mesh)
			continue

		var instance: Node = scene.instantiate()
		group_node.add_child(instance)
		_set_node_owner(instance)

		if surface_mesh != null and "surface_mesh" in instance:
			instance.set("surface_mesh", surface_mesh)


func _set_node_owner(node: Node) -> void:
	if not Engine.is_editor_hint():
		return
	var root: Node = get_tree().edited_scene_root if get_tree() else null
	if root == null:
		root = owner
	if root == null:
		root = self
	if node != root:
		node.owner = root
