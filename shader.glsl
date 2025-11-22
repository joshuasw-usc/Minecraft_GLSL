#iChannel0 'file://noise.png'
#include "helper.glsl"


//above is local only variables^^^ - do not add to shadertoy
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

struct Cube
{
    int type;
    vec3 pos;
    vec4 color;
};

struct RaycastHit
{
    Cube cube;
    float distance;
    vec3 point;
    vec3 normal;
    bool hit;
};


//Yellow directional light
DirectionalLight sun = DirectionalLight(vec3(0.333, -0.333, 0.333), vec4(1.0, 0.9, .3, 1.0)*1.0f);
DirectionalLight moon = DirectionalLight(vec3(0.333, -0.333, 0.333), vec4(145.0/255.0,163.0/255.0,176.0/255.0, 1.0));
bool is_day = false;
float sky_brightness = 0.0;
float max_terrain_height = 120.0f;
float terrain_frequency = 0.01f;
float water_height = 55.0f;
float reflection_strength = 0.66f;
int max_voxel_steps = 1024;

float cloud_base_height = 150.0;
float cloud_thickness  = 5.0;
float cloud_noise_scale = 0.008;
float cloud_threshold   = 0.6;
float cloud_wind_speed  = 5.0;

//test a ray against a cube
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
vec3 normal_cube(in Cube cube, in vec3 world_point)
{
    //translates to [-1, 1] range 
    vec3 p = world_point - cube.pos;        
    
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
vec4 sample_cube(in RaycastHit hit)
{
    //map to [-.5, .5] range
    vec3 p = hit.point - hit.cube.pos;

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

vec3 world_point_from_intersection( in Ray ray, in float depth)
{
    return ray.pos + ray.dir * depth;
}

// combines different colors for the sky (makes it look like sunrise/sunset)
vec3 getSkyColor(vec3 rd)
{
    float t = clamp(rd.y * 0.5 + 0.5, 0.0, 1.0);

    vec3 horizon = vec3(0.90, 0.55, 0.30);
    vec3 midSky = vec3(0.30, 0.50, 0.90);
    vec3 topSky = vec3(0.05, 0.05, 0.15);

    return mix(mix(horizon, midSky, smoothstep(0.0, 0.5, t)), topSky, smoothstep(0.5, 1.0, t));
}


// adds tiny little stars
float getStarIntensity(vec3 dir)
{
    vec3 d = normalize(dir);

    float gridSize = 300.0; // increase for higher density
    vec3 cell = floor(d * gridSize);

    float h = hash13(cell);
    float threshold = 0.995; // controls how many stars there are
    float starMask = step(threshold, h);

    float intensity = max(0.0, (h - threshold) * (1.0 / (1.0 - threshold)));

    // tried adding some 'blurring' and angeling so the stars look better. In the futur I may add flickering
    vec3 cellDir = (cell + 0.5) / gridSize;
    cellDir = normalize(cellDir);
    float angular = max(0.0, dot(d, cellDir)); // 1.0 when aligned
    float shape = pow(angular, 80.0);

    return starMask * intensity * shape * 2.0;
}

vec4 color_sky(vec3 rd)
{
    vec3 base = getSkyColor(rd);
    base *= sky_brightness; // adjusts the brightness so it blends together

    float starIntensity = getStarIntensity(rd);

    // get rid of the stars during the day
    float starFade = 1.0 - smoothstep(0.2, 0.8, sky_brightness);

    base += vec3(starIntensity) * starFade;
    return vec4(base, 1.0);
}

void move_camera(inout Camera cam)
{
    //TODO - add camera movement from keyboard

    //moves cam forward constant atm to test terrain
    cam.pos = vec3(0.0f, max_terrain_height * 0.66f, iTime * 8.0f);
    cam.forward = vec3(-0.5, 0.0, 0.5);    
    cam.up = vec3(0.0, 1.0, 0.0);
}

//tests if voxel is a terrain voxel
bool hit_terrain(inout RaycastHit hit, vec3 voxel)
{
    //samples "infinite" perlin noise atm using helper function
    //will prob choose a different noise to use  
    float height = floor(perlin2D(vec2(voxel.xz) * terrain_frequency) * max_terrain_height);
    
    if(float(voxel.y) < height)
    {
        //TODO - determine biome to set type, color, etc.
        hit.cube.type = 0;
        hit.cube.color = vec4(74.0/255.0, 23.0/255.0, 0.0, 1.0); 
        return true;    
    }

    return false;
}

bool hit_clouds(inout RaycastHit hit, vec3 voxel)
{
    // only add clouds to the sky
    if(voxel.y < cloud_base_height - cloud_thickness || voxel.y > cloud_base_height + cloud_thickness)
    {
        return false;
    }

    vec2 p = voxel.xz * cloud_noise_scale + iTime * 0.02 * cloud_wind_speed;
    float n = perlin2D(p); // uses perlin but may want to consider other methods

    if(n > cloud_threshold)
    {
        hit.cube.type = 1;
        hit.cube.color = vec4(0.75, 0.75, 0.80, 0.55); // can be adjsuted (would be cool to add different kinds of weather)
        return true;
    }

    return false;
}


bool hit_water(inout RaycastHit hit, vec3 voxel)
{
    if(hit.cube.type == -1 && voxel.y >= 0.0f && voxel.y <= water_height)
    {
        hit.cube.type = 2;
        hit.cube.color = vec4(0.235, 0.718, 1.0, 1.0) / 2.0f; 
        return true;
    }
    return false;
}


//Uses Amanatides/Woo algorithm for voxel traversal along a ray
//Returns a RaycastHit struct similar to Unity
//https://www.cs.yorku.ca/~amana/research/grid.pdf
RaycastHit raycast_voxels(in Ray ray)
{
    RaycastHit hit;
    hit.hit = false;
    hit.cube.type = -1;

    float t = 0.0f;
    

    //initialization phase: described on page 2
    //---
    //get our starting voxel
    ivec3 voxel = ivec3(floor(ray.pos));
    //set step as +1/-1 for each axis
    ivec3 step = ivec3(sign(ray.dir));
    vec3 inv_dir = 1.0 / ray.dir;

    //voxel bounds
    vec3 voxelMin = vec3(voxel);
    vec3 voxelMax = voxelMin + vec3(1.0);

    //initialize tMax according to page 2
    vec3 tMax;
    //voxel = ray.pos + ray.dir * t, so t = (voxel - ray.pos) / ray.dir
    //if axis is +1 dir: max bound - ray pos
    //else if axis is -1 dir: ray pos - min bound
    tMax.x = (step.x > 0 ? (voxelMax.x - ray.pos.x) : (ray.pos.x - voxelMin.x)) * abs(inv_dir.x);
    tMax.y = (step.y > 0 ? (voxelMax.y - ray.pos.y) : (ray.pos.y - voxelMin.y)) * abs(inv_dir.y);
    tMax.z = (step.z > 0 ? (voxelMax.z - ray.pos.z) : (ray.pos.z - voxelMin.z)) * abs(inv_dir.z);
    
    // delta to move to next voxel
    vec3 tDelta = abs(inv_dir);

    //set a max steps in case nothing is hit
    for(int i = 0; i < max_voxel_steps; i++)
    {
        bool terrain = hit_terrain(hit, vec3(voxel));
        bool clouds = hit_clouds(hit, vec3(voxel));      
        bool water = hit_water(hit, vec3(voxel));

        if(terrain || clouds || water)
        {
            //set the required fields of RaycastHit structs
            hit.cube.pos = vec3(voxel) + vec3(0.5);
            hit.distance = intersect_cube(ray, hit.cube);
            hit.point = world_point_from_intersection(ray, hit.distance);
            hit.normal = normal_cube(hit.cube, hit.point);
            hit.hit = true;
            return hit;
        }

        // incremental phase, page 3:
        if (tMax.x < tMax.y && tMax.x < tMax.z)
        {
            t = tMax.x;
            tMax.x += tDelta.x;
            voxel.x += step.x;
        }
        else if (tMax.y < tMax.z)
        {
            t = tMax.y;
            tMax.y += tDelta.y;
            voxel.y += step.y;
        }
        else
        {
            t = tMax.z;
            tMax.z += tDelta.z;
            voxel.z += step.z;
        }
    }

    return hit;
}

vec4 color_cube(in Ray ray)
{
    RaycastHit hit = raycast_voxels(ray);
    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);

    if(hit.hit)
    { 
        //default ground is type0 

        //COLOR + TEXTURES
        if(hit.cube.type == 0)
        {
            float value = sample_cube(hit).r;
            vec4 ambient = hit.cube.color * value;
            color += ambient;           
        }
        //clouds = 1
        else if(hit.cube.type == 1)
        {
            // since the clouds are transpareent we need to blend the cloud color and sky color together
            vec4 sky = color_sky(ray.dir);
            float a = hit.cube.color.a;
            vec3 col = mix(sky.rgb, hit.cube.color.rgb, a);

            return vec4(col, 1.0);
        }

        //water = 2
        else if (hit.cube.type == 2)
        {
            color += hit.cube.color;
        }

        //LIGHTS + SHADOWS
        if(hit.cube.type == 0 
        || hit.cube.type == 2)
        {
            DirectionalLight light;
            if(is_day)            
            {
                light = sun;
            }
            else
            {
                light = moon;
            }
            //shadows
            Ray shadow_ray = Ray(hit.point - light.dir * 0.001, -light.dir);
            RaycastHit shadow_hit = raycast_voxels(shadow_ray);          
            if(!shadow_hit.hit)
            {
                //no lighting    
                vec4 diffuse = light.color * max(0.0, dot(hit.normal, -light.dir));
                color += diffuse;        
            }        
        }
        

        //REFLECTION
        if(hit.cube.type == 2)
        {
            //basic reflection that supports 1 bounce only
            vec3 reflected = normalize((ray.dir - (2.0f * dot(ray.dir, hit.normal) * hit.normal)));
            Ray reflected_ray = Ray(hit.point + reflected * 0.001f, reflected);
            RaycastHit reflected_hit = raycast_voxels(reflected_ray);

            //can't do recursion, can cleanup code later for better reflection
            if(reflected_hit.hit)
            {
                if(reflected_hit.cube.type == 0)
                {
                    float value = sample_cube(reflected_hit).r;
                    vec4 ambient = reflected_hit.cube.color * value;
                    color += ambient * reflection_strength;           
                }
                else
                {
                    color += reflected_hit.cube.color * reflection_strength;
                }                
            }           
        }

        return color;
    }

    return vec4(-1.0, 0.0, 0.0, 1.0);
}



void day_night_cycle()
{
    // move the sun/moon around xy unit circle
    vec3 sun_position = vec3(cos(1.57 + iTime * 0.25), sin(1.57 + iTime * 0.25), 0.0);
    sun.dir = -sun_position;
    sun.dir.z = 1.0;

    sun.dir = normalize(sun.dir);
    moon.dir = -sun.dir;

    is_day = sun_position.y > 0.0;

    // for the sky colors
    sky_brightness = clamp(sun_position.y * 0.5 + 0.5, 0.0, 1.0);
}


void mainImage( out vec4 fragColor, in vec2 fragCoord )
{    

    //1. update the day/night day_night_cycle
    day_night_cycle();
    
    //2.Convert to ndc 
    vec2 uv_og = fragCoord/iResolution.xy;
    vec2 uv = fragCoord/iResolution.xy;
    
    //Map from [0,1] to [-1, 1]
    uv *= 2.0;
    uv -= 1.0;    
    //multiply width by aspect ratio
    uv.x *= (iResolution.x/iResolution.y);
    
    //3. Move camera    
    Camera cam = Camera(vec3(0.0, 30.0f, 0.0f), vec3(-0.5, 0.0, 0.5), vec3(0.0, 1.0, 0.0));
    move_camera(cam);
    vec3 right = normalize(cross( cam.up, cam.forward));
    vec3 pixel_pos = cam.pos + cam.forward + (right * uv.x) + (cam.up * uv.y);

    //4. Create ray based on camera struct
    Ray ray = Ray(cam.pos, normalize(pixel_pos - cam.pos)); 
    
    //5. Get pixel color
    vec4 color = color_cube(ray);

    //nothing was hit
    if(color.x == -1.0)
    {
        color = color_sky(ray.dir);
    }

    
    // Output to screen
     fragColor = color;
}
