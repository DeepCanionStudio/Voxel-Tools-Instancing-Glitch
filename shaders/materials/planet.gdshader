shader_type spatial;
#include "res://addons/zylann.voxel/shaders/transvoxel.gdshaderinc"
#include "res://addons/zylann.voxel/shaders/virtual_texturing.gdshaderinc"
#include "res://addons/zylann.voxel/shaders/triplanar.gdshaderinc"
#include "res://addons/zylann.voxel/shaders/lod_fade.gdshaderinc"
varying vec3 v_world_pos;
varying vec3 v_vertex_pos_model;
varying vec3 v_local_pos;

uniform vec3 global_pos;

uniform float topness_mid_level = 0.5;
uniform float height_range = 200.0;

uniform sampler2D top_gradient;
uniform sampler2D side_gradient;


uniform mat4 u_block_local_transform;


varying vec3 v_up_planet;
varying float v_planet_height;
varying vec3 v_normal_model;




void vertex() {
	
	
	VERTEX = get_transvoxel_position(VERTEX, CUSTOM0);
	
	mat4 planet_transform = u_block_local_transform;
	vec3 local_pos = (planet_transform * vec4(VERTEX, 1.0)).xyz;
	//vec3 local_pos = VERTEX + u_block_local_position;

	v_up_planet = normalize(local_pos);
	v_normal_model = NORMAL;
	v_planet_height = length(local_pos);
	
	
	v_vertex_pos_model = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_local_pos = VERTEX;
}

void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	NORMAL = get_voxel_normal_view(v_vertex_pos_model, NORMAL, VIEW_MATRIX * MODEL_MATRIX);
	vec3 normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 wpos = v_world_pos * 0.2;
	
	vec3 normal_model;
	vec3 normal_view = get_voxel_normal_view_model(v_vertex_pos_model, 
		NORMAL, VIEW_MATRIX * MODEL_MATRIX,
		v_normal_model, normal_model);
	normal_model = normalize(normal_model);
	
	float topness_midlevel = topness_mid_level;
	float topness_smoothness = 0.0;
	float topness_min = topness_midlevel - topness_smoothness;
	float topness_max = topness_midlevel + topness_smoothness;
	float topness = smoothstep(topness_min, topness_max, dot(normal_model, v_up_planet));
	
	vec3 albedo_top = texture(top_gradient, vec2(clamp(v_planet_height / height_range, 0.0, 1.0), 0)).rgb;
	vec3 albedo_side = texture(side_gradient, vec2(clamp(v_planet_height/ height_range, 0.0, 1.0), 0)).rgb;
	
	ALBEDO = mix(albedo_side, albedo_top, topness);
	
	
}