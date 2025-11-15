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

 //Yellow directional light
DirectionalLight sun = DirectionalLight(vec3(1.0, -1.0, 1.0), vec4(1.0, 0.9, .3, 1.0)*.5);
   


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


//samples 2d noise volume 
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

vec3 point_from_depth( in Ray ray, in float depth)
{
    return ray.pos + ray.dir * depth;
}

vec4 sky()
{
    //TODO - add day/night cycle 
    return vec4(66.0/255.0, 135.0/255.0,  245.0/255.0, 1.0);
}

void move_camera(out Camera cam)
{
    //TODO - add camera movement from keyboard

    //currently moves cam in a circle around origin
    cam.pos = vec3(cos(iTime), 0.0, sin(iTime)) * 5.0;
    //look at origin    
    cam.forward = normalize(-cam.pos);
}


vec4 draw_ground(in Ray ray)
{
    //TODO - draw all cubes based on some height/noise map here
    
    Cube cubes[3];
    //RGB cubes
    cubes[0] = Cube(vec3(-1.5, 0.0, 0.0), vec4(0.8, 0.0, 0.0, 1.0));
    cubes[1] = Cube(vec3(0.0, 0.0, 0.0), vec4(0.0, 0.8, 0.0, 1.0));
    cubes[2] = Cube(vec3(1.5, 0.0, 0.0), vec4(0.0, 0.0, 0.8, 1.0));

    float min_depth = 100000000.0;
    bool hit = false;
    vec4 color = vec4(-1.0, 0.0, 0.0, 1.0);

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
            hit = true;
        }  
    } 
    return color;
}


vec4 draw_clouds(in Ray ray)
{
    //TODO - draw clouds here

    return vec4(0.0, 0.0, 0.0, 1.0);
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
    move_camera(cam);


    vec3 right = normalize(cross( cam.up, cam.forward));
    vec3 pixel_pos = cam.pos + cam.forward + (right * uv.x) + (cam.up * uv.y);
        
    Sphere sphere = Sphere(vec3(0.0, 0.0, 0.0), 0.5);  
    Ray ray = Ray(cam.pos, normalize(pixel_pos - cam.pos)); 
    
    vec4 color = draw_ground(ray);
    color += draw_clouds(ray);    
    
    //nothing was hit
    if(color.x == -1.0)
    {
        color = sky();
    }
    
    // Output to screen
    fragColor = color;
}