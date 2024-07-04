shader_type spatial;
render_mode unshaded, depth_test_disabled;

uniform sampler2D DEPTH_TEXTURE: hint_depth_texture, filter_linear;
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear;
uniform float radius = 500.0;
uniform float cloud_outer_radius = 500.0;
uniform float liquid_layer_radius = 500.0;
uniform float planet_radius;

uniform sampler2D atmosGradient;

uniform vec3 scatteringCol;

uniform float intensity = 1.0;

uniform float density_fallof = 1.0;
uniform vec3 light_color : source_color;
uniform vec3 light_dir = vec3(0.0, 1.0, 0.0);


uniform sampler3D cloud_noise: repeat_enable;
uniform sampler3D cloud_noise_detail: repeat_enable;

uniform sampler2D cloud_color_over_angle;

uniform sampler2D cloud_height_gradient;
uniform float cloud_coverage = 1.0;


uniform float absorbtion_sun = 5.0;
uniform float absorbtion_powder = 5.0;
uniform float absorbtion_cloud = 5.0;
uniform float darkness_treshold = 0.1;

uniform float absorbtion_atmos = 1.0;

uniform vec4 phaseParams;

uniform float cloud_scale = 1.0;
uniform float cloud_detail_scale = 1.0;
uniform vec3 cloud_speed = vec3(1.0, 0.0, 0.0);
uniform vec3 cloud_detail_speed = vec3(1.0, 0.0, 0.0);

uniform sampler2D liquid_color_ramp;
uniform sampler2D liquid_angle_color_ramp;
uniform float liquid_absorbtion;
uniform float liquid_color_scale;
uniform sampler2D refraction_noise;
uniform float liquid_shininess = 0.5;

uniform sampler2D water_normal;
uniform float water_normal_size;

global uniform float cloud_quality;
global uniform int atmos_quality;
global uniform int cloud_shadows;

uint wang_hash(inout uint seed)
{
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4u);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15u);
    return seed;
}
 
float RandomFloat01(inout uint state)
{
    return float(wang_hash(state)) / 4294967296.0;
}
 



            float hg(float a, float g) {
                float g2 = g*g;
                return (1.0-g2) / (4.0*3.1415*pow(1.0+g2-2.0*g*(a), 1.5));
            }

            float phase(float a) {
                float blend = .5;
                float hgBlend = hg(a,phaseParams.x) * (1.0-blend) + hg(a,-phaseParams.y) * blend;
                return phaseParams.z + hgBlend*phaseParams.w;
            }





varying vec3 world_camera;
varying vec3 world_position;


vec2 RaySphereDist(float rad, vec3 rayOrigin, vec3 Raydir) {
		vec3 offset = rayOrigin;
		float a = 1.0; // Set to dot(rayDir, rayDir) if rayDir might not be normalized
		float b = 2.0 * dot(offset, Raydir);
		float c = dot (offset, offset) - rad * rad;
		float d = b * b - 4.0 * a * c; // Discriminant from quadratic formula

		// Number of intersections: 0 when d < 0; 1 when d = 0; 2 when d > 0
		if (d > 0.0) {
			float s = sqrt(d);
			float dstToSphereNear = max(0.0, (-b - s) / (2.0 * a));
			float dstToSphereFar = (-b + s) / (2.0 * a);

			// Ignore intersections that occur behind the ray
			if (dstToSphereFar >= 0.0) {
				return vec2(dstToSphereNear, dstToSphereFar - dstToSphereNear);
			}
		}
		// Ray did not intersect sphere
		return vec2(1000000.0, 0.0);
}


void vertex() {
	world_position = VERTEX;
	world_camera = (inverse(MODELVIEW_MATRIX) * vec4(0, 0, 0, 1)).xyz;
}

float density(vec3 p) {
	float distfromsphere = length(p) - radius;
	float height1 = distfromsphere / (radius - planet_radius) ;
	float localDensity = exp(-height1 * density_fallof) * (1.0 - height1);
	
	return localDensity / radius;
	}

float opticalDepth(vec3 ro, vec3 rd, float rl) {
	vec3 p = ro;
	float opticalDepth = 0.0;
	float pointDist = rl / 2.0;
	for (int x = 0; x < 3; x++) {
		float blockage = density(p);
		
		opticalDepth += blockage * pointDist;
		p += rd * pointDist;
	}
	return opticalDepth;
}

vec4 get_light(vec3 ro, vec3 rd, float rayLenght, vec3 col_oring) {
	vec3 p = ro;
	vec3 optical_depth = vec3(0.0);
	float pointDist = rayLenght / 3.0;
	float view_blockage;
	for (int x = 0; x <atmos_quality + 1; x++) {
		vec2 dist = RaySphereDist(radius, p, normalize(light_dir));
		float blockage = opticalDepth(p + normalize(light_dir), normalize(light_dir), dist.y);
		view_blockage = opticalDepth(ro, rd, pointDist * float(x));
		vec3 transmittance = exp(-(blockage + view_blockage)* scatteringCol/ 400.0) ;
		float density = density(p);
		
		optical_depth += density * transmittance * scatteringCol / 400.0 * pointDist;
		
		p += rd * pointDist;
		
		
	}
	
	float ocTransmittance = exp(-view_blockage);
	
	return vec4(optical_depth * intensity * pointDist / radius,1.0 - ocTransmittance);
}
float CloudDensity(vec3 p) {
	float d0 = texture(cloud_noise, p / 1000.0 * cloud_scale + TIME / 75.0 * cloud_speed).r - cloud_coverage;
	float d_detail = texture(cloud_noise_detail, p / 130.0 * cloud_detail_scale + TIME / 120.0 * cloud_detail_speed).r;
	float height = (length(p) - radius) / radius;
	
	float weight = (1.0 - d0) *(1.0 - d0);
	
	return d0 * texture(cloud_height_gradient, vec2(height, 0)).r - d_detail * weight;
}

float lightMarch(vec3 p) {
		float total_density = 0.0;
		float dst = RaySphereDist(planet_radius, p, normalize(light_dir)).y;
		if (dst > 0.0) {
		total_density = dst;
		}
		for (int step_ = 0; step_ <3; step_ ++) {
			if (total_density >= 1.0) {
				break;
			}
			p += normalize(light_dir) * 10.0;
			total_density += max(0.01, CloudDensity(p));
		}
		total_density = clamp(total_density, 0.0, 1.0);
		float trans = exp(-total_density * absorbtion_sun);
		float powderness = trans *(1.0 - exp(-total_density * absorbtion_powder * 2.0));
		return darkness_treshold/ 5.0 + powderness * (1.0 - darkness_treshold / 5.0);
}

float CloudShadows(vec3 p){
	float total_density = 0.0;

	for (int step_ = 0; step_ <cloud_shadows; step_ ++) {
		if (total_density >= 1.0) {
			break;
		}
		p += normalize(light_dir) * 10.0;
		total_density += max(0.00, CloudDensity(p)) * 1.6;
	}
	total_density = clamp(total_density, 0.0, 0.8);

	return 1.0 - total_density * clamp(absorbtion_cloud * 2.0, 0.0, 1.0);
}

vec4 rayMarch(vec3 ro,vec3 rd,float depth, float dstToBox,float dstInsideBox) {
	if (cloud_quality == 0.0 || dstToBox > 3000.0) {
		return vec4(0.0);
	}
	float cosAngle = dot(rd, normalize(light_dir));
	float phaseVal = phase(cosAngle);
	float transmittance = 1.0;
	
	
	float limit = min(depth - dstToBox, dstInsideBox);
    float dist = 0.0;
	vec4 atmosColor = vec4(0.0);
	float stepSize = max(max(10.0, limit / 69.0), dstToBox / 50.0);
	bool is_high_quality = false;
	float dstInsCloud = 0.0;
    vec4 color = vec4(0.0);

	while (dist < limit) {
		
		vec3 p =  ro + (dist) * rd;
		
		float density = CloudDensity(p);
		
		
		if (density > 0.0)
        {
			if (is_high_quality == false) {
				dist -= stepSize;
				density = 0.0;
				stepSize = max(max(1.0, (limit / 130.0) / cloud_quality), (dstToBox / 110.0) / cloud_quality);
				is_high_quality = true;
				
			}
			
			if (density > 1.0){
				break;
			}
			
			
			
			float lightTransmittance = lightMarch(p);
			float dstThroughAtmos = RaySphereDist(radius, p, normalize(light_dir)).y / (radius * 2.0);
			vec4 colorOverAngle = texture(cloud_color_over_angle, vec2(dstThroughAtmos, 0.0));
			color += density * stepSize * transmittance * lightTransmittance * phaseVal * colorOverAngle;
			transmittance *= exp(-density * stepSize * absorbtion_cloud);
			color.a = clamp(1.0 -transmittance, 0.0, 1.0);
        }
		else {
			stepSize = max(max(10.0, (limit / 45.0) / cloud_quality), (dstToBox / 85.0) / cloud_quality);
			is_high_quality = false;
		}
		
	dist += stepSize;
	}
	
	color = clamp(color, 0.0, 1.0);
	
	
	return color;
}
vec3 get_triplanar_blend(vec3 world_normal, float sharpness) {
	// TODO `pow` is an expensive function, maybe there should be an alternative
	vec3 blending = pow(abs(world_normal), vec3(sharpness));
	return blending / (blending.x + blending.y + blending.z);
}

vec4 texture_triplanar(sampler2D tex, vec3 world_pos, vec3 blend) {
	vec4 xaxis = texture(tex, world_pos.yz);
	vec4 yaxis = texture(tex, world_pos.xz);
	vec4 zaxis = texture(tex, world_pos.xy);
	// blend the results of the 3 planar projections.
	return xaxis * blend.x + yaxis * blend.y + zaxis * blend.z;
}


void fragment() {
	
	vec3 ro = world_camera;
	vec3 rd =  normalize(world_position - ro);
	
	vec2 dist = RaySphereDist(radius, ro, rd);
	if (dist.y < 1.0) {
		discard;
	}
	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3((SCREEN_UV * 2.0) - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec4 world_coords = INV_VIEW_MATRIX * view;
	vec3 pos_world = world_coords.xyz / world_coords.w;
	vec3 cam_pos_world = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// I wonder if there is a faster way to get to that distance...
	float linear_depth = distance(cam_pos_world, pos_world);
	
	float dst2 = min(dist.y,(linear_depth - dist.x));
	ALPHA = 0.0;
	if (dst2 > 0.0) {
		float pixelIndex = FRAGCOORD.y * VIEWPORT_SIZE.x + FRAGCOORD.x;
		uint rngState = uint(pixelIndex + TIME * 8000.0);
		float rand = RandomFloat01(rngState);
		vec2 cloud_dist = RaySphereDist(cloud_outer_radius, ro, rd);
		vec2 liquid_dist = RaySphereDist(liquid_layer_radius, ro, rd);
		float dstwater = min(liquid_dist.y ,(linear_depth - liquid_dist.x));
		vec3 st = texture(SCREEN_TEXTURE,SCREEN_UV).rgb;
		vec3 liquid_col = vec3(0.0);
		float waterdist = clamp((dstwater) / liquid_absorbtion, 0.0, 1.0);
		if (dstwater > 0.0) {
		vec2 liquid_light_dist = RaySphereDist(liquid_layer_radius, ro + liquid_dist.x * rd, normalize(light_dir));
		
		vec3 liquid_specular = vec3(0.0);
		
		vec3 liquid_normal = normalize((ro + rd * liquid_dist.x));
		vec2 refraction = texture_triplanar(refraction_noise,(ro  + TIME / 1.0+ rd * liquid_dist.x) / 50.0,get_triplanar_blend(liquid_normal, 0.8)).xy / 5.0 * waterdist;
		liquid_col = texture(liquid_color_ramp, vec2(clamp((min(dstwater, liquid_dist.y)/ liquid_color_scale) * 2.0+ refraction.y, 0.0, 0.9), 0.0)).rgb;
		vec3 liquid_normal_map = texture_triplanar(water_normal,(ro  + TIME / 3.0+ rd * liquid_dist.x) / 50.0,get_triplanar_blend(liquid_normal, 0.8) ).rgb;
		
		float liquid_dir_light = max(dot(normalize(liquid_normal), normalize(light_dir)), 0.0);
		liquid_col *= liquid_dir_light;
		
		if (liquid_dist.x > 0.0) {
		liquid_specular = pow(max(0.0, dot(reflect(normalize(light_dir), normalize(liquid_normal * liquid_normal_map)), normalize(rd))),liquid_shininess) * light_color;
		
		liquid_col = liquid_col + liquid_specular;
		}
		dst2 = min(dist.y,(min(linear_depth, liquid_dist.x) - dist.x));
		st = texture(SCREEN_TEXTURE,SCREEN_UV + refraction / 3.0).rgb;
		}
		vec4 cloud_color = vec4(0.0);
		if (cloud_dist.y > 0.0 ) {
		cloud_color = rayMarch(ro + rd * (cloud_dist.x + rand * 5.0), rd, min(linear_depth, liquid_dist.x), cloud_dist.x, cloud_dist.y);
		st = mix(st, cloud_color.rgb, cloud_color.a);
		}
		vec3 col = vec3(0.0);
		vec3 p = ro + rd * dist.x;
		vec4 light = get_light(p + rd * rand * 2.0, rd, min(dst2, liquid_dist.x), st);
		st = mix(st, liquid_col, waterdist);
		
		if (dist.y >= linear_depth || dist.x > dst2) {
		float cloud_shadow = CloudShadows(ro + rd * min(linear_depth,liquid_dist.x));
			
		st *= vec3(cloud_shadow);
		}
		
		
		
		ALPHA = clamp(light.a + waterdist, 0.0, 1.0);
		
		
		
		col = mix(max(st, light.rgb),st * (1.0 * max(st.x, max(st.y, st.z))- light.xyz) + light.xyz, 0.94);

		if (cloud_color.a > 0.0) {
			vec4 cloud_light = get_light(p, rd, 180.0 * absorbtion_atmos, st);
			col = mix(col, (cloud_light.rgb + cloud_color.rgb), cloud_color.a);
		}
		
		ALBEDO = col;
		
		
	}
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}
