#version 430
layout(local_size_x = 1, local_size_y = 1) in;
layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
uniform samplerCube skybox;
uniform vec4 aperture;
uniform mat4 rotation = mat4(1.0);
layout(rgba32f, binding = 0) uniform image2D img_output;

#define MAXMESH 1000

layout(std140, binding = 0) uniform MESH_IN
{
	vec3 verts[MAXMESH];
} vertices;

uniform float size;

vec4 ray_o;
vec4 ray_d;
vec4 pixel;
vec4 color;

struct IntersectData
{
	float dist;
	vec3 intersection;
	vec3 normal;
	vec4 color;
	float brightness;
};

IntersectData intersectRoom(vec3 r_origin, vec3 r_direction)
{
	float halflength = 100;
	bool testBack=true, testLeft=true, testBottom=true;
	vec3 nearest;
	float nearest_dist = 10000.0;
	vec3 normal;

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
			normal = p_normal;
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
				normal = p_normal;
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
				normal = p_normal;
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
					normal = p_normal;
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
					normal = p_normal;
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
					normal = p_normal;
				}
			}
		}
	}
	return IntersectData(nearest_dist, nearest, normal, texture(skybox, nearest), 0.0);
}

IntersectData intersectSphere(vec3 ray_origin, vec3 ray_direction, vec3 centre, float radius, vec4 sphere_color, float brightness)
{
	vec3 omc = ray_origin - centre;
	float a = dot(ray_direction, ray_direction);
	float b = 2.0f * dot(ray_direction, omc);
	float c = dot(omc, omc) - radius*radius;
	float discriminant = b*b-4.0f*a*c;

	if(discriminant < 0.0f)
	{
		return IntersectData(-1.0f, vec3(0.0), vec3(0.0), sphere_color, brightness);
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
			return IntersectData(dist, intersection, normal, sphere_color, brightness);
		}

		numerator = -b + sqrt(discriminant);
		if (numerator > 0.0)
		{
			float t = numerator/2.0f*a;
			vec3 intersection = ray_origin + t*ray_direction;
			float dist = length(t*ray_direction);
			vec3 normal = normalize(intersection - centre);
			return IntersectData(dist, intersection, normal, sphere_color, brightness);
		}
		else
		{
			return IntersectData(-1.0f, vec3(0.0), vec3(0.0), sphere_color, brightness);
		}
	}
}

vec4 rayTrace(int bounces, vec3 origin, vec3 direction)
{
	IntersectData current_intersect;
	IntersectData nearest_intersect;
	vec3 current_ray_origin = origin;
	vec3 current_ray_direction = direction;
	vec4 final_color = vec4(1.0, 1.0, 1.0, 1.0);
	bool room = true;

	while(bounces>=0)
	{
		current_intersect = intersectRoom(current_ray_origin, current_ray_direction);
		nearest_intersect = current_intersect;
		room = true;

		current_intersect = intersectSphere(current_ray_origin, current_ray_direction, vec3(-5.0, 4.0, -30.0), 5.0, vec4(1.0, 1.0, 0.8, 1.0), 0.5f);
		if(current_intersect.dist > 0.001f && (nearest_intersect.dist > current_intersect.dist || nearest_intersect.dist <= 0.001f))
		{
			nearest_intersect = current_intersect;
			room = false;
		}

		current_intersect = intersectSphere(current_ray_origin, current_ray_direction, vec3(5.0, -7.0, -20.0), 7.0, vec4(1.0, 0.8, 1.0, 1.0), 0.0);
		if(current_intersect.dist > 0.001f && (nearest_intersect.dist > current_intersect.dist || nearest_intersect.dist <= 0.001f))
		{
			nearest_intersect = current_intersect;
			room = false;
		}

		current_intersect = intersectSphere(current_ray_origin, current_ray_direction, vec3(-8.0, -7.0, -20.0), 3.0, vec4(1.0, 1.0, 1.0, 1.0), 0.0);
		if(current_intersect.dist > 0.001f && (nearest_intersect.dist > current_intersect.dist || nearest_intersect.dist <= 0.001f))
		{
			nearest_intersect = current_intersect;
			room = false;
		}

		if(nearest_intersect.dist > 0.001f && room == false)
		{
				final_color *= nearest_intersect.color;
				current_ray_origin = nearest_intersect.intersection;
				current_ray_direction = reflect(current_ray_direction, nearest_intersect.normal);
		}
		else
		{
			final_color *= nearest_intersect.color;
			break;
		}
		bounces--;
	}
	return final_color;
}

void main(){
	ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

	float max_x = 5.0;
	float max_y = 5.0;
	ivec2 dims = imageSize(img_output);
	float x = max_x * (pixel_coords.x * 2 - dims.x) / dims.x;
	float y = max_y * (pixel_coords.y * 2 - dims.y) / dims.y;
	float z = 0.0;

	vec4 viewing_plane = vec4(x, y, z, 1.0) * rotation;
	ray_o = vec4(0.0, 0.0, 10.0, 1.0);
	ray_d = normalize(viewing_plane - ray_o);

	color = rayTrace(5, vec3(ray_o.x, ray_o.y, ray_o.z), vec3(ray_d.x, ray_d.y, ray_d.z));
	pixel = color;
	
	imageStore(img_output,pixel_coords,pixel);
}