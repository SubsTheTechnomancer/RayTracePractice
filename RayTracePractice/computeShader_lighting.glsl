#version 430
layout(local_size_x = 1, local_size_y = 1) in;
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
uniform samplerCube skybox;
layout(rgba32f, binding = 0) uniform image2D img_output;

#define MAXMESH 1000

layout(std140, binding = 0) uniform MESH_IN
{
	vec3 verts[MAXMESH];
} vertices;

uniform float size;

vec4 pixel;

struct Ray{
    vec3 origin;
    vec3 direction;
    vec3 energy;
};

struct RayHit{
    vec3 position;
    float dist;
    vec3 normal;
    vec3 albedo;
    vec3 specular;
    float smoothness;
    vec3 emission;
};

RayHit CreateRayHit(){
    RayHit hit;
    hit.position = vec3(0.0f,0.0f,0.0f);
    hit.dist = -1;
    hit.normal = vec3(0.0f,0.0f,0.0f);
    hit.albedo = vec3(0.0f,0.0f,0.0f);
    hit.specular = vec3(0.0f,0.0f,0.0f);
    hit.smoothness = 0.0f;
    hit.emission = vec3(0,0,0);
    return hit;
}

float rand(){
    return fract(sin(dot(pixel.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float sdot(vec3 x, vec3 y, float f){
    return clamp(vec3(dot(x,y)*f), 0.0, 1.0);
}
 

float energy(vec3 colour){
    return dot(colour,vec3(1.0f/3.0f));
}

float SmoothnessToPhongAlpha(float s){
    return pow(1000.0f,s*s);
}

mat3 GetTangentSpace(vec3 normal){
 
    vec3 helper = vec3(1,0,0);
    if(abs(normal.x)>0.99f)
        helper = vec3(0,0,1);
    
    vec3 tangent = normalize(cross(normal,helper));
    vec3 binormal = normalize(cross(normal,tangent));
 
    return mat3(tangent,binormal,normal);
}
 
vec3 SampleHemisphere(vec3 normal,float alpha){
    float cosTheta = pow(rand(),1.0f/(alpha+1.0f));
    float sinTheta = sqrt(max(0.0f,1.0f - cosTheta*cosTheta));
    float phi = 2 * 3.141592f * rand();
    vec3 tangentSpaceDir = vec3(cos(phi)*sinTheta,sin(phi)*sinTheta,cosTheta);
 
    return tangentSpaceDir*GetTangentSpace(normal);
}

RayHit intersectRoom(vec3 r_origin, vec3 r_direction)
{
	bool testBack=true, testLeft=true, testBottom=true;
	vec3 nearest;
	float nearest_dist = 175.0;
	vec3 normal;
	vec4 color = vec4(1.0, 1.0, 1.0, 1.0);

	//front face
	vec3 p_point = vec3(0.0, 0.0, -100.0);
	vec3 p_normal = vec3(0.0, 0.0, 1.0);
	float denom = dot(p_normal, r_direction);
	if (abs(denom) > 0.0001f) // your favorite epsilon
	{
		float t = dot(p_point - r_origin, p_normal) / denom;
		if (t > 0.0001f) 
		{
			testBottom = false;
			nearest = r_origin+t*r_direction;
			nearest_dist = length(t*r_direction);
			normal = p_normal;
		}
	}
	else testBottom = false;

	//right face
	p_point = vec3(100.0, 0.0, 0.0);
	p_normal = vec3(-1.0, 0.0, 0.0);
	denom = dot(p_normal, r_direction);
	if (abs(denom) > 0.0001f) // your favorite epsilon
	{
		float t = dot(p_point - r_origin, p_normal) / denom;
		if (t > 0.0001f) 
		{
			testLeft = false;
			float dist = length(t*r_direction);
			if(dist < nearest_dist)
			{
				nearest = r_origin+t*r_direction;
				nearest_dist = dist;
				normal = p_normal;
			}
		}
	}
	else testLeft = false;

	//top face
	p_point = vec3(0.0, 100.0, 0.0);
	p_normal = vec3(0.0, -1.0, 0.0);
	denom = dot(p_normal, r_direction);
	if (abs(denom) > 0.0001f) // your favorite epsilon
	{
		float t = dot(p_point - r_origin, p_normal) / denom;
		if (t > 0.0001f) 
		{
			testBottom = false;
			float dist = length(t*r_direction);
			if(dist < nearest_dist)
			{
				nearest = r_origin+t*r_direction;
				nearest_dist = dist;
				normal = p_normal;
			}
		}
	}
	else testBottom = false;

	//back face
	if(testBack)
	{
		vec3 p_point = vec3(0.0, 0.0, 100.0);
		vec3 p_normal = vec3(0.0, 0.0, -1.0);
		float denom = dot(p_normal, r_direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - r_origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = length(t*r_direction);
				if(dist < nearest_dist)
				{
					nearest = r_origin+t*r_direction;
					nearest_dist = dist;
					normal = p_normal;
				}
			}
		}
	}

	//left face
	if(testLeft)
	{
		vec3 p_point = vec3(-100.0, 0.0, 0.0);
		vec3 p_normal = vec3(1.0, 0.0, 0.0);
		float denom = dot(p_normal, r_direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - r_origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = length(t*r_direction);
				if(dist < nearest_dist)
				{
					nearest = r_origin+t*r_direction;
					nearest_dist = dist;
					normal = p_normal;
				}
			}
		}
	}

	//bottom face
	if(testBottom)
	{
		vec3 p_point = vec3(0.0, -100.0, 0.0);
		vec3 p_normal = vec3(0.0, 1.0, 0.0);
		float denom = dot(p_normal, r_direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - r_origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = length(t*r_direction);
				if(dist < nearest_dist)
				{
					nearest = r_origin+t*r_direction;
					nearest_dist = dist;
					normal = p_normal;
				}
			}
		}
	}
	return RayHit(nearest, nearest_dist, normal, vec3(0.0),  vec3(0.0), 0.0,  vec3(0.0));
}

RayHit intersectSphere(vec3 ray_origin, vec3 ray_direction, vec3 centre, float radius)
{
	vec3 omc = ray_origin - centre;
	float a = dot(ray_direction, ray_direction);
	float b = 2.0f * dot(ray_direction, omc);
	float c = dot(omc, omc) - radius*radius;
	float discriminant = b*b-4.0f*a*c;

	if(discriminant < 0.0f)
	{
		return CreateRayHit();
	}
	else
	{
		float numerator = -b - sqrt(discriminant);
		if (numerator > 0.0)
		{
			float t = numerator/2.0f*a;
			vec3 intersection = ray_origin + t*ray_direction;
			float dist = length(t*ray_direction);
			vec3 normal = normalize(intersection - centre);
			return RayHit(intersection, dist, normal, vec3(0.0), vec3(0.0), 0.0, vec3(1.0));
		}

		numerator = -b + sqrt(discriminant);
		if (numerator > 0.0)
		{
			float t = numerator/2.0f*a;
			vec3 intersection = ray_origin + t*ray_direction;
			float dist = length(t*ray_direction);
			vec3 normal = normalize(intersection - centre);
			return RayHit(intersection, dist, normal, vec3(0.0), vec3(0.0), 0.0, vec3(1.0));
		}
		else
		{
			return CreateRayHit();
		}
	}
}

RayHit Trace(Ray ray){
    RayHit current_intersect;
	RayHit hit;
	vec3 current_ray_origin = ray.origin;
	vec3 current_ray_direction = ray.direction;

	current_intersect = intersectRoom(current_ray_origin, current_ray_direction);
	hit = current_intersect;
		
	current_intersect = intersectSphere(current_ray_origin, current_ray_direction, vec3(-5.0, 4.0, -30.0), 5.0);
	if(current_intersect.dist > 0.001f && (hit.dist > current_intersect.dist || hit.dist <= 0.001f))
	{
		hit = current_intersect;
	}

	current_intersect = intersectSphere(current_ray_origin, current_ray_direction, vec3(5.0, -7.0, -20.0), 7.0);
	if(current_intersect.dist > 0.001f && (hit.dist > current_intersect.dist || hit.dist <= 0.001f))
	{
		hit = current_intersect;
	}

	current_intersect = intersectSphere(current_ray_origin, current_ray_direction, vec3(-8.0, -7.0, -20.0), 3.0);
	if(current_intersect.dist > 0.001f && (hit.dist > current_intersect.dist || hit.dist <= 0.001f))
	{
		hit = current_intersect;
	}
 
    return hit;
}

vec3 Shade(inout Ray ray, RayHit hit)
{
	if(hit.dist > 0.001f)
	{
 
		hit.albedo = min(1.0f - hit.specular, hit.albedo);
		float specChance = energy(hit.specular);
		float diffChance = energy(hit.albedo);
 
		float roulette = rand();
		if (roulette < specChance)
		{
			ray.origin = hit.position + hit.normal * 0.001f;
			float alpha = SmoothnessToPhongAlpha(hit.smoothness);
			ray.direction = SampleHemisphere(reflect(ray.direction, hit.normal), alpha);
			float f = (alpha+2)/(alpha+1);
			ray.energy *= (1.0f / specChance) * hit.specular * sdot(hit.normal, ray.direction,f);
		}
		else if((diffChance > 0 && roulette < specChance + diffChance))
		{
			ray.origin = hit.position + hit.normal * 0.001f;
			ray.direction = SampleHemisphere(hit.normal,1.0f);
			ray.energy *= (1.0f / diffChance) * 2 * hit.albedo * sdot(hit.normal, ray.direction, 1.0);
		}
		else
		{
			ray.energy = vec3(0.0f);
		}
 
		return hit.emission;
 
	}
	else
	{
		ray.energy = vec3(0.0f);
		float theta = acos(ray.direction.y)/(3.141592f)+(3.141592f/16);
		float phi = atan(ray.direction.x, ray.direction.z)/(3.141592f);
		return vec3(0,0,0);
	}
	return vec3(0,0,0);
}

void main(){
	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

	float max_x = 5.0;
	float max_y = 5.0;
	ivec2 dims = imageSize(img_output);
	float x = float(pixel_coords.x * 2 - dims.x) / dims.x;
	float y = 0.2 + float(pixel_coords.y * 2 - dims.y) / dims.y;

	Ray ray;
	ray.origin = vec3(0.0, 0.2, 10.0);
	ray.direction = normalize(vec3(x*max_x,y*max_y,0.0) - ray.origin);

	vec3 result;
	for(int i = 0; i <= 2; i++){
        RayHit hit = Trace(ray);
        result += ray.energy * Shade(ray,hit);
    
        if(ray.energy.x==0.0 || ray.energy.y==0.0 ||ray.energy.y==0.0) break;
    }

	pixel = vec4(result, 1.0);
	
	imageStore(img_output,pixel_coords,pixel);
}