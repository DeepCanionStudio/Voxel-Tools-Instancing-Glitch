extends RigidBody3D

var mouse_sensibility = -0.01

var current_planet = null
var accel = Vector3()
var max_accel = Vector3()

var rotation_vel = Vector3()
var move_speed = Vector3.ZERO

var forward = -global_transform.basis.z
var left = -global_transform.basis.x;
var up  = global_transform.basis.y;

var is_mounted = false


var _ref_change_info

func _integrate_forces(state):
	if _ref_change_info != null:
		
		state.transform = _ref_change_info * state.transform
		state.linear_velocity = _ref_change_info.basis  * state.linear_velocity
		_ref_change_info = null



	accel = Vector3()
	for area in $Area3D.get_overlapping_areas():
		if area.get_parent() is PlanetBody:
			if area.get_parent().planet_type == 0:
				var sqr = abs((area.global_position).distance_squared_to(global_position) - area.get_parent().planet_radius)
				var force = (area.global_position - global_position).normalized()
				apply_central_impulse((force * area.get_parent().mass * 150) / sqr)
			elif area.get_parent().planet_type == 1:
				var sqr = (area.global_position).distance_to(global_position)
				var sqr_pow = (area.global_position).distance_squared_to(global_position)
				var force = (area.global_position - global_position).normalized()
				if sqr < area.get_parent().planet_radius:
					force = (global_position - area.global_position).normalized()
				apply_central_impulse((force * area.get_parent().mass * 150) / sqr_pow)
			if max_accel.length() <= accel.length():
				max_accel = accel
				current_planet = area.get_parent()

	if is_mounted:
		forward = -global_transform.basis.z
		left = -global_transform.basis.x;
		up = global_transform.basis.y;

		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if Input.is_action_pressed("d"):
				apply_central_impulse(-left * 4)
			if Input.is_action_pressed("a"):
				apply_central_impulse(left * 4)
			if Input.is_action_pressed("w"):
				apply_central_impulse(forward * 4)
			if Input.is_action_pressed("s"):
				apply_central_impulse(-forward * 4)
			if Input.is_action_pressed("shift"):
				apply_central_impulse(up * 4)
			if Input.is_action_pressed("ctrl"):
				apply_central_impulse(-up * 4)
			apply_torque_impulse(rotation_vel * 50.0)
	Global.save_data["ship_position"] = global_position

func _unhandled_input(event):
	if is_mounted:
		rotation_vel = Vector3.ZERO
		if event is InputEventMouseMotion:
			if !Input.is_action_pressed("r"):
				rotation_vel += up * event.relative.x * mouse_sensibility
			else:
				rotation_vel -= forward * event.relative.x * mouse_sensibility * 0.8
			rotation_vel -= left * event.relative.y * mouse_sensibility

func _on_solar_system_reference_body_changed(info):
	# We'll do that in `_integrate_forces`,
	# because Godot can't be bothered to do such override for us.
	_ref_change_info = info
	#transform = info.inverse_transform * transform
	#_linear_velocity = info.inverse_transform.basis * _linear_velocity
