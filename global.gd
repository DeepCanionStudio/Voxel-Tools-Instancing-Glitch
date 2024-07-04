extends Node

var camera_transform : Transform3D

var current_planet : Node3D

var shadows_active = true
var bloom_active = true
var ssao_active = true
var ssil_active = true


var is_new_save = true

signal settings_changed(variable, type)

var save_data = {
	"name" : "inengine",
	"mode" : 0,
	"player_position" : Vector3(0, 0, 0),
	"current_planet" : 0,
	"ship_position" : Vector3(0, 0, 0)
	
}

