extends Node3D

class_name PlanetBody


@export var mass = 100
@export var planet_radius = 200

var current_building_container

@export_enum("Normal","Concave","Flat") var planet_type = 0

@export var distance_to_parent := 0.0

@export var orbit_speed := 1.0
@export var orbit_revolution_progress := 0.0
@export var orbit_tilt := 0.0

@export var self_speed := 1.0
@export var self_revolution_progress := 0.0
@export var self_tilt := 0.0

@export var parent_planet_node : NodePath
@onready var parent_planet = get_node(parent_planet_node)

@export var has_terrain = false

@export var entry_radius = 100.0

var actual_transform = Transform3D()

func _ready():
	if Global.save_data.get("name") != "inengine":
		if has_terrain:
			var str = VoxelStreamSQLite.new()
			str.save_generator_output = true
			str.database_path = "saves/" + Global.save_data.get("name") + "/" + name + ".sqlite"
			str.set_key_cache_enabled(true) 
			$VoxelLodTerrain.stream = str
	var scene = load("res://saves/" + Global.save_data.get("name")+ "/" + name + "_builds.tscn")
	if scene:
		var ins = scene.instantiate()
		$BuildingContainer.queue_free()
		ins.name = "BuildingContainer"
		add_child(ins)
		current_building_container = ins
	else:
		current_building_container = $BuildingContainer

func _exit_tree():
	if has_terrain:
		$VoxelLodTerrain.save_modified_blocks()
	var Dir = DirAccess
	Dir.make_dir_absolute("res://saves/"+ Global.save_data.get("name"))
	var scene = PackedScene.new()
	var s = scene.pack(current_building_container)
	if s != OK:
		print("CAZZZIOOOO")
	var error = ResourceSaver.save(scene,"res://saves/" + Global.save_data.get("name")+ "/" + name + "_builds.tscn")
	if error != OK:
		print("PALLLLEEEEEEE")
