extends CharacterBody3D

var mouse_sensibility = -0.007
const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var current_planet : PlanetBody = null
var current_planet_surface: VoxelLodTerrain= null
var max_accel = Vector3()
var accel = Vector3()

var gravity_speed = Vector3()
var rotation_speed = Vector3()
var base_speed = Vector3()


var last_planet_rotation = Vector3()

var is_in_ship = false
var ship = null
var is_building = false

var _ref_change_info

var wait_for_physics := 0

var bob_fr = 1
var bob_amp = 0.05

var is_in_oxygen := false
var tbob := 0.0

var forward = -global_transform.basis.z
var left = -global_transform.basis.x;
var up = global_transform.basis.y;


func _get_target_transform(target_transform: Transform3D) -> Transform3D:
	var tt := target_transform
	if wait_for_physics > 0:
		# Simulate as if the target managed to switch its transform already (which it didnt)
		tt = _ref_change_info * tt
	return tt

func _ready():
		
		
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func add_terrain():
	if Input.is_action_pressed("make"):
		if $Pivot/Camera3D/TerrainRay.is_colliding():
			if current_planet_surface:
				var tool = current_planet_surface.get_voxel_tool()
				tool.channel = VoxelBuffer.CHANNEL_SDF
				tool.mode = VoxelTool.MODE_ADD
				tool.grow_sphere($Pivot/Camera3D/TerrainRay.get_collision_point(), 4, 2.0)
				print("Balls")
	elif Input.is_action_pressed("destroy"):
		if $Pivot/Camera3D/TerrainRay.is_colliding():
			if current_planet_surface:
				var tool = current_planet_surface.get_voxel_tool()
				tool.channel = VoxelBuffer.CHANNEL_SDF
				tool.mode = VoxelTool.MODE_REMOVE
				tool.grow_sphere($Pivot/Camera3D/TerrainRay.get_collision_point(), 4, 1.0)

func make_gravity():
	max_accel = Vector3()
	accel = Vector3()
	current_planet = null
	for area in $Area3D.get_overlapping_areas():
		if area.get_parent() is PlanetBody:
			current_planet_surface = area.get_parent().get_node("VoxelLodTerrain")
			if area.get_parent().planet_type == 0:
				var sqr = (area.global_position).distance_squared_to(global_position)
				var force = (area.global_position - global_position).normalized()
				accel += (force * area.get_parent().mass *48) / sqr
			elif area.get_parent().planet_type == 1:
				var sqr = (area.global_position).distance_to(global_position)
				var sqr_pow = (area.global_position).distance_squared_to(global_position)
				var force = (area.global_position - global_position).normalized()
				if sqr < area.get_parent().planet_radius:
					force = (global_position - area.global_position).normalized()
				accel += (force * area.get_parent().mass *48) / sqr_pow
			if max_accel.length() <= accel.length():
				max_accel = accel
				current_planet = area.get_parent()
				Global.current_planet = current_planet

func _unhandled_input(event):
	if (!is_in_ship) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_object_local(Vector3.UP,event.relative.x * mouse_sensibility)
			$Pivot/Camera3D.rotate_x(event.relative.y * mouse_sensibility)

func _physics_process(delta):
	make_gravity()
	var gravityUp = Vector3(0, 1, 0)
	if current_planet:
		gravityUp =-(max_accel).normalized()
		var direction = Quaternion(transform.basis.y, gravityUp) * global_transform.basis.get_rotation_quaternion()
		rotation = global_transform.basis.get_rotation_quaternion().slerp(direction, delta * 2).get_euler()
		
	forward = -global_transform.basis.z
	left = -global_transform.basis.x;
	up = global_transform.basis.y;
	
	up_direction = up
	var run_speed = 1
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_pressed("shift"):
			bob_fr = 0.8
			run_speed = 1.1
		else:
			run_speed = 0.8
			bob_fr = 0.5

		var move_speed = Vector3.ZERO
		if Input.is_action_pressed("w"):
			move_speed += forward * 2
		if Input.is_action_pressed("s"):
			move_speed += -forward * 2
		if Input.is_action_pressed("a"):
			move_speed += left * 2
		if Input.is_action_pressed("d"):
			move_speed += -left * 2
		base_speed = base_speed.move_toward(move_speed, delta * 650)
		base_speed = base_speed.normalized()
	if is_on_floor():
		gravity_speed = Vector3.ZERO
		#var radius = (current_planet.global_position).distance_to(global_position)
		#var angle = current_planet.rotation_velocity.normalized().angle_to(up)
		#var R = cos(angle) * radius
		#var vel_multiplyer = 2 * PI * R
		#rotation_speed = -up.cross(current_planet.rotation_velocity.normalized()) * R * current_planet.rotation_velocity.length()
		#rotation_speed = current_planet.rotation - last_planet_rotation
		#last_planet_rotation = current_planet.rotation_velocity
		#rotate_object_local(Vector3.UP,current_planet.rotation_velocity.length()* (current_planet.rotation_velocity.normalized().dot(up)) * delta) 
		if Input.is_action_just_pressed("space"):
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				gravity_speed += up * 18
	else :
		gravity_speed += accel
	Global.camera_transform = $Pivot/Camera3D.global_transform
	$Label.text = str(Engine.get_frames_per_second())
	if !is_in_ship:
		velocity = gravity_speed + base_speed * 10.0 * run_speed + rotation_speed
		tbob += delta * base_speed.length() * 26.0 * float(is_on_floor())
		move_and_slide()
		$Pivot/Camera3D.transform.origin = bob()
	else:
		global_transform = _get_target_transform(ship.global_transform )
		$Pivot/Camera3D.rotation = Vector3.ZERO
		if Input.is_action_just_pressed("q"):
			is_in_ship = false
			ship.get_parent().is_mounted = false
			$CollisionShape3D.disabled = false
	add_terrain()
	Global.save_data["player_position"] = global_position
	if wait_for_physics > 0:
		wait_for_physics -= 1
		if wait_for_physics == 0:
			_ref_change_info = null

func bob() -> Vector3:
	var pos = Vector3()
	pos.y = sin(tbob * bob_fr) * bob_amp
	pos.x = (sin(tbob * bob_fr / 2.0) * bob_amp / 1.5)
	return pos
func use_tools():
	if Input.is_action_just_pressed("make"):
		if $Pivot/Camera3D/ToolRay.tool_type != 0:
			if $Pivot/Camera3D/ToolRay.is_colliding():
				if $Pivot/Camera3D/ToolRay.get_collider().tool_type == $Pivot/Camera3D/ToolRay.tool_type:
					$Pivot/Camera3D/ToolRay.get_collider().hit($Pivot/Camera3D/ToolRay.tool_power)
			


func get_structure_gravity(pos):
	match current_planet.planet_type:
		0:
			return (current_planet.global_position - pos).normalized()
		1:
			var sqr = (current_planet.global_position).distance_to(pos)
			if sqr < current_planet.planet_radius:
				return -(current_planet.global_position - pos).normalized()
			return (current_planet.global_position - pos).normalized()


func get_structure_position() -> Vector3:
	if $Pivot/Camera3D/SnapRay.get_overlapping_areas().size() != 0:
		for x in $Pivot/Camera3D/SnapRay.get_overlapping_areas():
			if x.snap_type == $Building.get_child(0).snap_type:
				var col = x
				var dst = col.get_parent().global_position.distance_to(current_planet.global_position)
				var force = -(current_planet.global_position - col.global_position).normalized()
				return dst * force
	return $Pivot/Camera3D/TerrainRay.get_collision_point() + $Pivot/Camera3D/TerrainRay.get_collision_normal() * 0.5
	


func build_structures():
	if current_planet and is_building:
		if $Building.get_child_count() != 0:
			var pos = get_structure_position()
			
			$Building.global_rotation = Vector3(0, 0, 0)
			$Building.global_position = pos
			for x in $Pivot/Camera3D/SnapRay.get_overlapping_areas():
				if x.snap_type == $Building.get_child(0).snap_type:
					$Building.global_rotation = x.global_rotation
			
			
			var force = get_structure_gravity(pos)
			var gravityUpObj = -force
			
			
			var Objdirection : Quaternion= Quaternion($Building.transform.basis.y, gravityUpObj).normalized() * $Building.transform.basis.get_rotation_quaternion().normalized()
			
			$Building.global_rotation = Objdirection.get_euler()
			
			$Building.can_build = $Pivot/Camera3D/TerrainRay.is_colliding() or $Pivot/Camera3D/SnapRay.get_overlapping_areas().size() != 0
			
		if $Building.get_child_count() == 0:
			var ins = $Building.structure.instantiate()
			$Building.add_child(ins)
			print("Balls")
	else:
		if $Building.get_child_count() != 0:
			$Building.get_child(0).queue_free()



func _on_solar_system_reference_body_changed(info):
	# We'll do that in `_integrate_forces`,
	wait_for_physics = 1
	_ref_change_info = info
	#transform = info.inverse_transform * transform
	#_linear_velocity = info.inverse_transform.basis * _linear_velocity

