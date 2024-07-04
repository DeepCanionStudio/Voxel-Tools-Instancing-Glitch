extends Node3D

@export var planets = []

var _reference_body_id := 1

@onready var ship = $Ship
@onready var system = $PlanetContainer
@onready var _environment = $WorldEnvironment.environment

@onready var sun_light = $SunLight

signal reference_body_changed(info)

@export var time_speed = 1.0

var _physics_count := 0
var _physics_count_on_last_reference_change := 0

func _physics_process(delta):
		
	if _physics_count > 0 and _physics_count - _physics_count_on_last_reference_change > 10:
		if _reference_body_id == 0:
			for i in len(system.get_children()):
				var body : PlanetBody = system.get_children()[i]
				if body.name == "Sun":
					# Ignore sun, no point landing there
					continue
				if body.has_node("VoxelLodTerrain"):
					body.get_node("VoxelLodTerrain").generate_collisions = false
				var body_pos = body.global_transform.origin
				var d = body_pos.distance_to(ship.global_transform.origin)
				if d <body.entry_radius:
					print("Close to ", body.name, " which is at ", body_pos)
					set_reference_body(i)
					break
		else:
			var ref_body := system.get_children()[_reference_body_id]
			var body_pos = ref_body.global_transform.origin
			var d = body_pos.distance_to(ship.global_transform.origin)
			if d > 1.1 * ref_body.entry_radius:
				set_reference_body(0)
	
	var ref_trans_inverse := Transform3D()
	sun_light.global_position = system.get_child(0).global_position
	if _reference_body_id != 0:
		var ref_body := system.get_children()[_reference_body_id]
		var ref_trans := _compute_absolute_body_transform(ref_body, ref_body.parent_planet)
		ref_trans_inverse = ref_trans.affine_inverse()
		sun_light.global_position = system.get_child(0).global_position
		sun_light.look_at(ref_body.global_position)
	else:
		sun_light.look_at(ship.global_position)
	
	for planet in len(system.get_children()):
		if system.get_child(planet) is PlanetBody:
			var body: PlanetBody = system.get_children()[planet]
			body.orbit_revolution_progress += body.orbit_speed * delta * time_speed
			body.self_revolution_progress += body.self_speed * delta * time_speed
			var absolute_transform = _compute_absolute_body_transform(body, body.parent_planet)
			body.actual_transform = absolute_transform
			
			if _reference_body_id == planet:
			# Don't touch the reference body
				continue
		
			var trans := _compute_absolute_body_transform(body, body.parent_planet)
		
			if _reference_body_id != 0:
				trans = ref_trans_inverse * trans
		
			body.transform = trans
	# Update sky rotation.
	if _reference_body_id != 0:
		# When we are on a planet, the sky is no longer in world space,
		# so we must simulate its motion relative to us
		_environment.sky_rotation = ref_trans_inverse.basis.get_euler()
	else:
		_environment.sky_rotation = Vector3()
	
	_physics_count += 1

func set_reference_body(ref_id: int):
	if _reference_body_id == ref_id:
		return
	
	var previous_body := system.get_children()[_reference_body_id]
	
	_reference_body_id = ref_id
	var body := system.get_children()[_reference_body_id]
	if body.has_node("VoxelLodTerrain"):
		body.get_node("VoxelLodTerrain").generate_collisions = true
	print("Setting reference to ", ref_id, " (", body.name, ")")
	var trans = body.transform
	body.transform = Transform3D()
	
	var info = trans.affine_inverse() * body.transform
	_physics_count_on_last_reference_change = _physics_count
	Global.save_data["current_planet"] = _reference_body_id
	reference_body_changed.emit(info)



func _compute_absolute_body_transform(planet, parent_planet) -> Transform3D:
	var parent_transform := Transform3D()
	if parent_planet:
		var parent_body = parent_planet
		parent_transform = _compute_absolute_body_transform(parent_body, null)
		
		
	var orbit_angle = planet.orbit_revolution_progress * TAU
	# TODO Elliptic orbits
	var pos = Vector3(cos(orbit_angle), 0, sin(orbit_angle)) * planet.distance_to_parent
	pos = pos.rotated(Vector3(0, 0, 1), planet.orbit_tilt)
	var self_angle = planet.self_revolution_progress * TAU
	var basis := Basis.from_euler(Vector3(0, self_angle, planet.self_tilt))
	var local_transform := Transform3D(basis, pos)
	return parent_transform * local_transform
