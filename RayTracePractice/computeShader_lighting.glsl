#version 430
layout(local_size_x = 1, local_size_y = 1) in;
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
uniform samplerCube skybox;
uniform float seed;
layout(rgba32f, binding = 0) uniform image2D img_output;

#define MAXMESH 1000

layout(std140, binding = 0) uniform MESH_IN
{
	vec3 verts[MAXMESH];
} vertices;

uniform float size;

vec4 pixel;
vec4 directional_light = vec4(normalize(vec3(-1.0, -1.0, 0.0)).xyz, 1.0f);

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

struct Sphere
{
    vec3 position;
    float radius;
    vec3 albedo;
    vec3 specular;
};

float internal_seed = seed;
float rand(){
    float result = fract(sin(internal_seed/100.0f*dot(pixel.xy ,vec2(12.9898f,78.233f))) * 43758.5453f);
	internal_seed += 1.0f;
	return result;
}

float sdot(vec3 x, vec3 y, float f){
    return clamp(dot(x,y)*f, 0.0, 1.0);
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
 
vec3 SampleHemisphere(vec3 normal, float alpha){
    float cosTheta = pow(rand(), 1.0f / (alpha + 1.0f));
    float sinTheta = sqrt(max(0.0f,1.0f - cosTheta*cosTheta));
    float phi = 2 * 3.141592f * rand();
    vec3 tangentSpaceDir = vec3(cos(phi)*sinTheta,sin(phi)*sinTheta,cosTheta);
 
    return GetTangentSpace(normal)*tangentSpaceDir;
}

vec3 drawBackground(vec3 r_origin, vec3 r_direction)
{
	float halflength = 10000;
	bool testBack=true, testLeft=true, testBottom=true;
	vec3 nearest;
	float nearest_dist = 10000000.0;

	//front face
	vec3 p_point = vec3(0.0, 0.0, -halflength);
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
		}
	}
	else testBottom = false;

	//right face
	p_point = vec3(halflength, 0.0, 0.0);
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
			}
		}
	}
	else testLeft = false;

	//top face
	p_point = vec3(0.0, halflength, 0.0);
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
			}
		}
	}
	else testBottom = false;

	//back face
	if(testBack)
	{
		vec3 p_point = vec3(0.0, 0.0, halflength);
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
				}
			}
		}
	}

	//left face
	if(testLeft)
	{
		vec3 p_point = vec3(-halflength, 0.0, 0.0);
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
				}
			}
		}
	}

	//bottom face
	if(testBottom)
	{
		vec3 p_point = vec3(0.0, -halflength, 0.0);
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
				}
			}
		}
	}
	return vec3(texture(skybox, normalize(nearest)).xyz);
//	return vec3(1.0, 0.0, 0.0);
}

void intersectGroundPlane(Ray ray, inout RayHit bestHit)
{
	float t = (- ray.origin.y - 17.0f ) / ray.direction.y;
	if (t > 0.1f && (t < bestHit.dist || bestHit.dist == -1))
	{
		bestHit.dist = t;
		bestHit.position = ray.origin + t * ray.direction;
		bestHit.normal = vec3(0.0, 1.0, 0.0);
		bestHit.albedo = vec3(1.0);
		bestHit.specular = vec3(1.0);
		bestHit.emission = vec3(0.0);
		bestHit.smoothness = 1.2;
	}
}

void intersectSphere(Ray ray, inout RayHit bestHit, Sphere sphere)
{
	vec3 d = ray.origin - sphere.position;
	float p1 = -dot(ray.direction, d);
    float p2sqr = p1 * p1 - dot(d, d) + sphere.radius * sphere.radius;
    if (p2sqr < 0)
        return;
    float p2 = sqrt(p2sqr);
    float t = p1 - p2 > 0 ? p1 - p2 : p1 + p2;
    if (t > 0.1f && (t < bestHit.dist || bestHit.dist == -1))
    {
        bestHit.dist = t;
        bestHit.position = ray.origin + t * ray.direction;
        bestHit.normal = normalize(bestHit.position - sphere.position);
        bestHit.albedo = sphere.albedo;
        bestHit.specular = sphere.specular;
		bestHit.emission = vec3(0.0);
		bestHit.smoothness = 0.8;
    }
}

RayHit Trace(Ray ray)
{
	RayHit bestHit = CreateRayHit();

	intersectGroundPlane(ray, bestHit);

	intersectSphere(ray, bestHit, Sphere(vec3(8.0f, -11.0, -40.0f), 5.0, vec3(0.0, 0.0, 0.0), vec3(1.0, 1.0, 0.0)));
	intersectSphere(ray, bestHit, Sphere(vec3(-5.0f, -11.0, -40.0f), 5.0, vec3(1.0, 1.0, 0.0), vec3(0.4)));
//	for(int i=-2; i<3; i++)
//	{
//		for(int j=0; j<5; j++)
//		{
//			intersectSphere(ray, bestHit, Sphere(vec3(i*13.0f, -11.0, -j*20.0f-40.0f), 5.0, vec3(1.0), vec3(0.6)));
//		}
//	}
 
    return bestHit;
}

vec3 Shade(inout Ray ray, RayHit hit)
{
	if(hit.dist > 0.01f)
	{
 
		hit.albedo = min(1.0f - hit.specular, hit.albedo);
		float specChance = energy(hit.specular);
		float diffChance = energy(hit.albedo);
		float sum = specChance + diffChance;
		specChance /= sum;
		diffChance /= sum;

		float roulette = rand();
		if (roulette < specChance)
		{
//			float alpha = 3000.0f;
			ray.origin = hit.position + hit.normal * 0.001f;
			float alpha = SmoothnessToPhongAlpha(hit.smoothness);
			ray.direction = SampleHemisphere(reflect(ray.direction, hit.normal), alpha);
			float f = (alpha+2)/(alpha+1);
			ray.energy *= (1.0f / specChance) * hit.specular * sdot(hit.normal, ray.direction, f);
//			return vec3(1.0, 0.0, 0.0);
		}
		else
		{
			ray.origin = hit.position + hit.normal * 0.001f;
			ray.direction = SampleHemisphere(hit.normal, 1.0f);
			ray.energy *= (1.0f / diffChance) * hit.albedo;
		}
//			
		return hit.emission;

//		vec3 specular = vec3(1.0f, 0.78f, 0.34f);
//		vec3 albedo = vec3(0.8f, 0.8f, 0.8f);
//        // Reflect the ray and multiply energy with specular reflection
//        ray.origin = hit.position + hit.normal * 0.01f;
//        ray.direction = reflect(ray.direction, hit.normal);
//        ray.energy *= specular;
//		bool shadow = false;
//		Ray shadowRay = Ray(hit.position + hit.normal * 0.001f, -1 * directional_light.xyz, vec3(1.0));
//		RayHit shadowHit = Trace(shadowRay);
//		if (shadowHit.dist != -1)
//		{
//			return vec3(0.0f, 0.0f, 0.0f);
//		}
//        return clamp(dot(hit.normal, directional_light.xyz) * -1, 0, 1) * 0.0 * albedo;
//		return vec3(1.0, 1.0, 1.0);

//		ray.origin = hit.position + hit.normal * 0.001f;
//		vec3 reflected = reflect(ray.direction, hit.normal);
//		ray.direction = SampleHemisphere(hit.normal);
//		vec3 diffuse = 2 * min(1.0f - hit.specular, hit.albedo);
//		float alpha = 15.0f;
//		vec3 specular = hit.specular * (alpha + 2) * pow(sdot(ray.direction, reflected, 1.0), alpha);
//		ray.energy *= (diffuse + specular) * sdot(hit.normal, ray.direction, 1.0);
//		return vec3(0.0f);
 
	}
	else
	{
		ray.energy = vec3(0.2f);
		return drawBackground(ray.origin, ray.direction);
	}
}

void main(){
	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

	float max_x = 5.0;
	float max_y = 5.0;
	ivec2 dims = imageSize(img_output);
	float x = float(pixel_coords.x * 2 - dims.x) / dims.x;
	float y = float(pixel_coords.y * 2 - dims.y) / dims.y;
	pixel = vec4(pixel_coords.x, pixel_coords.y, 0.0, 1.0);
	Ray ray;
	ray.origin = vec3(0.0, 0.0, 10.0);
	ray.direction = normalize(vec3(x*max_x,y*max_y,0.0) - ray.origin);
	ray.energy = vec3(1.0f);

	vec3 result = vec3(0.0, 0.0, 0.0);
	for(int i = 0; i <= 4; i++){
        RayHit hit = Trace(ray);
        result += ray.energy * Shade(ray,hit);
    
        if(ray.energy.x==0.0 || ray.energy.y==0.0 ||ray.energy.y==0.0) break;
    }

	pixel = vec4(result, 1.0);
//	pixel = vec4(vec3(seed), 1.0);
	
	imageStore(img_output,pixel_coords,pixel);
}