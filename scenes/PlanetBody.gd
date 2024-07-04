extends Node3D

class_name PlanetBody


@export var mass = 100
@export var planet_radius = 200
@export_enum("Normal","Concave","Flat") var planet_type = 0

@export var parent_planet_node : NodePath
@onready var parent_planet = get_node(parent_planet_node)

@export var has_terrain = false
