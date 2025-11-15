#iChannel0 'file://noise.png'


//above is local only variables^^^ - do not paste in shadertoy
//copy&paste from here down to view in shadertoy
//To view locally press 'ctrl + shift + p' then search for 'ShaderToy: Show GLSL Preview'
struct Ray
{
    vec3 pos;
    vec3 dir;
};

struct DirectionalLight
{
    vec3 dir;
    vec4 color;
};

struct Camera
{
    vec3 pos;
    vec3 forward;
    vec3 up;
};

struct Sphere
{
    vec3 center;
    float radius;
};

struct Cube
{
    vec3 pos;
    vec4 color;
};


//based on wiki slab method: https://en.wikipedia.org/wiki/Slab_method
float intersect_cube(in Ray ray, in Cube cube)
{
    vec3 lo = cube.pos.xyz - 0.5;
    vec3 hi = cube.pos.xyz + 0.5;
    
    float t1 = (lo.x - ray.pos.x)/ray.dir.x;
    float t2 = (hi.x - ray.pos.x)/ray.dir.x;
    float t3 = (lo.y - ray.pos.y)/ray.dir.y;
    float t4 = (hi.y - ray.pos.y)/ray.dir.y;
    float t5 = (lo.z - ray.pos.z)/ray.dir.z;
    float t6 = (hi.z - ray.pos.z)/ray.dir.z;
    
    float tclose = max(max(min(t1, t2), min(t3, t4)), min(t5, t6));
    float tfar   = min(min(max(t1, t2), max(t3, t4)), max(t5, t6));
    
    
    if(tfar < 0.0 || tclose > tfar)
    {
        return -1.0;
    }
    
    return tclose;
}


//gets the cube normal vec
vec3 normal_cube(in vec3 point, in Cube cube)
{
    //translates to [-1, 1] range 
    vec3 p = point - cube.pos;    
    
    
    if (abs(p.x) > abs(p.y) && abs(p.x) > abs(p.z))
    {
        return vec3(sign(p.x), 0.0, 0.0);
    }       
    else if (abs(p.y) > abs(p.x) && abs(p.y) > abs(p.z))
    {
        return vec3(0.0, sign(p.y), 0.0);
    }       
    else
    {
        return vec3(0.0, 0.0, sign(p.z));
    }       
}


//samples 3d noise volume 
vec4 rgb_cube(in vec3 point, in Cube cube)
{
    //map to [-.5, .5] range
    vec3 p = point - cube.pos;

    if(abs(p.z) <= 0.50001 && abs(p.z) >= 0.4999)
    {
        return texture(iChannel0, p.xy);
    }
    else if(abs(p.x) <= 0.50001 && abs(p.x) >= 0.4999)
    {
        return texture(iChannel0, p.yz);
    }
    else 
    {
        return texture(iChannel0, p.xz);
    }
}


// Profs. intersect function: https://www.shadertoy.com/view/ttV3Rt
float intersect_sphere(in Ray ray, in Sphere sphere) {
	// Sphere center to ray origin
	vec3 co = ray.pos - sphere.center;

	// The discriminant is negative for a miss, or a postive value
	// used to calcluate the distance from the ray origin to point of intersection
    //bear in mind that there may be more than one solution
	float discriminant = dot(co, ray.dir) * dot(co, ray.dir)
			- (dot(co, co) - sphere.radius * sphere.radius);

	// If answer is not negative, get ray intersection depth
	if (discriminant >= 0.0)
		return -dot(ray.dir, co) - sqrt(discriminant);
	else
		return -1.; // Any negative number to indicate no intersect
}


vec3 point_from_depth( in Ray ray, in float depth)
{
    return ray.pos + ray.dir * depth;
}

vec3 normal_sphere( in vec3 point, in Sphere sphere)
{
    return normalize(point - sphere.center);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv_og = fragCoord/iResolution.xy;
    vec2 uv = fragCoord/iResolution.xy;
    
    //Map from [0,1] to [-1, 1]
    uv *= 2.0;
     uv -= 1.0;
    
    //multiply width by aspect ratio
    uv.x *= (iResolution.x/iResolution.y);
    
    //vec3 pixel_pos = vec3(uv, 1.0);
    
    Camera cam = Camera(vec3(0.0, 0.0, -4.0), vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 0.0));
    //moves cam in a circle around origin
    cam.pos = vec3(cos(iTime), 0.0, sin(iTime)) * 5.0;
    //look at origin    
    cam.forward = normalize(-cam.pos);
    vec3 right = normalize(cross( cam.up, cam.forward));
    vec3 pixel_pos = cam.pos + cam.forward + (right * uv.x) + (cam.up * uv.y);
        
    Sphere sphere = Sphere(vec3(0.0, 0.0, 0.0), 0.5);      
    Cube cubes[3];
    //RGB cubes
    cubes[0] = Cube(vec3(-1.5, 0.0, 0.0), vec4(0.8, 0.0, 0.0, 1.0));
    cubes[1] = Cube(vec3(0.0, 0.0, 0.0), vec4(0.0, 0.8, 0.0, 1.0));
    cubes[2] = Cube(vec3(1.5, 0.0, 0.0), vec4(0.0, 0.0, 0.8, 1.0));

    Ray ray = Ray(cam.pos, normalize(pixel_pos - cam.pos)); 
    
    //Yellow directional light
    DirectionalLight sun = DirectionalLight(vec3(1.0, -1.0, 1.0), vec4(1.0, 0.9, .3, 1.0)*.5);
    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    
    float min_depth = 100000000.0;
    
    for(int i = 0; i < 3; i++)
    {
        float intersect_depth = intersect_cube(ray, cubes[i]);
        //check ray against sphere
        if(intersect_depth > 0.0 && intersect_depth < min_depth)
        {
            min_depth = intersect_depth;            
            vec3 point = point_from_depth(ray, intersect_depth);
            vec4 ambient = cubes[i].color * rgb_cube(point, cubes[i]).r;
            vec3 normal = normal_cube(point, cubes[i]);       
            vec4 diffuse = sun.color * max(0.0, dot(normal, -sun.dir));

            //basic red sphere
            color = ambient + diffuse;
        }   
    }    
    
    // Output to screen
    fragColor = color;
}