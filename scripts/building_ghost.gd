extends Node3D

@export var building : PackedScene
@export var snap_type = ""
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _unhandled_input(event):
	if Input.is_action_just_pressed("make"):
		if get_parent().can_build:
			var bins = building.instantiate()
			bins.global_transform = global_transform
			Global.current_planet.current_building_container.add_child(bins)
			bins.set_owner(Global.current_planet.current_building_container)
			print("Coom")
