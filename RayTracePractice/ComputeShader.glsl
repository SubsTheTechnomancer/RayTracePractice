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

vec3 ray_o;
vec3 ray_d;
vec4 pixel;
vec4 color;

struct IntersectData
{
	float dist;
	vec3 intersection;
	vec3 normal;
	vec4 color;
};

vec4 drawBackground(vec3 r_origin, vec3 r_direction)
{
	bool testBack=true, testLeft=true, testBottom=true;
	vec3 nearest;
	float nearest_dist = 175.0;

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
			nearest_dist = length(r_origin+t*r_direction);
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
			float dist = length(r_origin+t*r_direction);
			if(dist < nearest_dist)
			{
				nearest = r_origin+t*r_direction;
				nearest_dist = dist;
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
			float dist = length(r_origin+t*r_direction);
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
		vec3 p_point = vec3(0.0, 0.0, 100.0);
		vec3 p_normal = vec3(0.0, 0.0, -1.0);
		float denom = dot(p_normal, r_direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - r_origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = length(r_origin+t*r_direction);
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
		vec3 p_point = vec3(-100.0, 0.0, 0.0);
		vec3 p_normal = vec3(1.0, 0.0, 0.0);
		float denom = dot(p_normal, r_direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - r_origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = length(r_origin+t*r_direction);
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
		vec3 p_point = vec3(0.0, -100.0, 0.0);
		vec3 p_normal = vec3(0.0, 1.0, 0.0);
		float denom = dot(p_normal, r_direction);
		if (abs(denom) > 0.0001f) // your favorite epsilon
		{
			float t = dot(p_point - r_origin, p_normal) / denom;
			if (t > 0.0001f) 
			{
				float dist = length(r_origin+t*r_direction);
				if(dist < nearest_dist)
				{
					nearest = r_origin+t*r_direction;
					nearest_dist = dist;
				}
			}
		}
	}
	return texture(skybox, nearest);
}

vec3 normalizeTri(vec3 points[3]){
	return cross(points[1]-points[0],points[2]-points[0]);
}

float triangle(vec3 points[3]){
	vec3 N = normalizeTri(points);
	float d = dot(N,points[0]);
	
	if(abs(dot(N,ray_d))<0.1f) return -1.0f;

	float t = -1*(dot(N,ray_o)+d)/dot(N,ray_d);

	if(t<0) return -1.0f;

	vec3 p = ray_o + t*ray_d;

	if(dot(N,cross(points[1]-points[0],p-points[0]))>0 &&
	   dot(N,cross(points[2]-points[1],p-points[1]))>0 &&
	   dot(N,cross(points[0]-points[2],p-points[2]))>0){
	   
	   float dist = length(ray_d*t);
	   return dist;
	}

	return -1.0f;
}

IntersectData intersectSphere(vec3 ray_origin, vec3 ray_direction, vec3 centre, float radius, vec4 sphere_color)
{
	vec3 omc = ray_origin - centre;
	float a = dot(ray_direction, ray_direction);
	float b = 2.0f * dot(ray_direction, omc);
	float c = dot(omc, omc) - radius*radius;
	float discriminant = b*b-4.0f*a*c;

	if(discriminant < 0.0f)
	{
		return IntersectData(-1.0f, vec3(0.0), vec3(0.0), sphere_color);
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
			return IntersectData(dist, intersection, normal, sphere_color);
		}

		numerator = -b + sqrt(discriminant);
		if (numerator > 0.0)
		{
			float t = numerator/2.0f*a;
			vec3 intersection = ray_origin + t*ray_direction;
			float dist = length(t*ray_direction);
			vec3 normal = normalize(intersection - centre);
			return IntersectData(dist, intersection, normal, sphere_color);
		}
		else
		{
			return IntersectData(-1.0f, vec3(0.0), vec3(0.0), sphere_color);
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

	while(bounces>=0)
	{
		current_intersect = intersectSphere(current_ray_origin, current_ray_direction, vec3(-5.0, 4.0, -30.0), 5.0, vec4(1.0, 1.0, 0.8, 1.0));
		nearest_intersect = current_intersect;
		
//		if(bounces==0)
//				return vec4(nearest_intersect.dist/300.0f, 0.0, 0.0, 1.0);

		current_intersect = intersectSphere(current_ray_origin, current_ray_direction, vec3(5.0, -7.0, -20.0), 7.0, vec4(1.0, 0.8, 1.0, 1.0));
		if(current_intersect.dist > 0.001f && (nearest_intersect.dist > current_intersect.dist || nearest_intersect.dist <= 0.001f))
		{
			nearest_intersect = current_intersect;
		}

		current_intersect = intersectSphere(current_ray_origin, current_ray_direction, vec3(-8.0, -7.0, -20.0), 3.0, vec4(1.0, 1.0, 1.0, 1.0));
		if(current_intersect.dist > 0.001f && (nearest_intersect.dist > current_intersect.dist || nearest_intersect.dist <= 0.001f))
		{
			nearest_intersect = current_intersect;
		}

		if(nearest_intersect.dist > 0.001f)
		{
			final_color *= nearest_intersect.color;
			current_ray_origin = nearest_intersect.intersection;
			current_ray_direction = reflect(current_ray_direction, nearest_intersect.normal);
		}
		else
		{
			final_color *= drawBackground(current_ray_origin, current_ray_direction);
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
	float x = float(pixel_coords.x * 2 - dims.x) / dims.x;
	float y = 0.2 + float(pixel_coords.y * 2 - dims.y) / dims.y;
	ray_o = vec3(x*max_x, y*max_y, 0.0);
	ray_d = vec3(0.0,0.0,-1.0);

	pixel = vec4(abs(x),abs(y),0.0,1.0);

	ray_o = vec3(0.0, 0.2, 10.0);
	ray_d = normalize(vec3(x*max_x,y*max_y,0.0) - ray_o);

	color = rayTrace(5, ray_o, ray_d);
	pixel = color;
	
	imageStore(img_output,pixel_coords,pixel);
}