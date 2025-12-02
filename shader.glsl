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
    bool maxed_out;
};

int DEFAULT = 0;
int CLOUDS = 1;
int WATER = 2;
int DESERT = 3;
int TUNDRA = 4;
int CAVE = 5;
int TREE_TRUNK = 6;
int TREE_LEAVES = 7;

bool enable_clouds = true;
bool enable_terrain = true;
bool enable_water = true;
bool enable_reflections = true;
bool enable_shadows = false;
bool test_caves = false;

//Yellow directional light
DirectionalLight sun = DirectionalLight(vec3(0.333, -0.333, 0.333), vec4(1.0, 0.9, .3, 1.0)*0.5f);
DirectionalLight moon = DirectionalLight(vec3(0.333, -0.333, 0.333), vec4(145.0/255.0,163.0/255.0,176.0/255.0, 1.0));
bool is_day = false;
float sky_brightness = 0.0;
float max_terrain_height = 45.0f;
float terrain_frequency = 0.02f;
float water_height = 20.0f;
float water_depth = 5.0f;
float reflection_strength = 0.1f;
int max_voxel_steps = 1025;
vec4 water_color = vec4(.1, .3, .42, 1.0);
float temp_frequency = 0.005f;
float wet_frequency = 0.005f;
float cave_frequency = 0.01f;


vec4 fog = vec4(0.8, 0.8, 1.0, 1.0);
float fog_start = 25.0f;
float fog_end = 75.0f;
float day_night_speed = 0.05f;
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
vec4 sample_cube(in sampler2D sampler, in RaycastHit hit)
{

    // same check from move_camera to test if we are in shader toy
    vec3 camPos = texelFetch(iChannel1, ivec2(0, 0), 0).xyz;
    bool is_shader_toy = (length(camPos) > 0.0001);

   
    float max_distance = 100.0f;
    //return vec4(1.0, 0.0, 0.0, 1.0);
    //map to [-.5, .5] range

    float scale = 1.0 - clamp(hit.distance / max_distance, 0.0, 1.0);
    scale = 1.0; //clamp(scale, 0.01, 1.0);
    vec3 p = hit.point - hit.cube.pos;

    vec2 uv;
   
    if(abs(p.z) <= 0.50001 && abs(p.z) >= 0.4999)
    {
        uv = p.xy;
    }
    else if(abs(p.x) <= 0.50001 && abs(p.x) >= 0.4999)
    {
        uv = p.yz;
    }
    else 
    {
        uv = p.xz;
    }

    uv += 0.5;
    
    if(is_shader_toy)
    {
        //map from 64x64 to 16x16
        uv *= 0.25;
    }

    //quick lods    
    if(hit.distance > fog_start)
    {
        //
        uv *= 0.5;
    }
    if(hit.distance > 100.0f)
    {
        uv *= 0.5;
    }
    ivec2 texture_size = textureSize(sampler, 0);
    ivec2 coord = ivec2(floor(uv * vec2(texture_size)));
    
    return texelFetch(sampler, coord, 0);
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

//fog based on sky color
float getFogAmount(float distance)
{
    return clamp((distance - fog_start) / (fog_end - fog_start), 0.0, 1.0); 
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

//sample the height map with an xz pos
float height_map(vec2 pos)
{
    return floor(perlin2D(vec2(pos) * terrain_frequency) * max_terrain_height);
}

void move_camera(inout Camera cam)
{
    // Try to read persistent position from Buffer A (iChannel1)
    vec3 camPos = texelFetch(iChannel1, ivec2(0, 0), 0).xyz;

    bool valid = (length(camPos) > 0.0001);

   
    // Fallback to panning camera (VS Code)
    if (!valid)
    {
        
        if(test_caves)
        {
            cam.pos     = vec3(0.0f, -500.5f, iTime * 6.0f);
        }
        else
        {
            cam.pos     = vec3(0.0f, max_terrain_height * 0.66f, iTime * 6.0f);
        }        
        cam.forward = normalize(vec3(-0.5, 0.0, 0.5));
        cam.up      = vec3(0.0, 1.0, 0.0);
        return;
    }

    vec2 m = iMouse.xy / iResolution.xy;

    float yaw   = (m.x - 0.5) * 6.2831853;   // [-π, π]
    float pitch = (m.y - 0.5) * 1.2;

    vec3 forward;
    forward.x = cos(pitch) * sin(yaw);
    forward.y = sin(pitch);
    forward.z = cos(pitch) * cos(yaw);

    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(up, forward));
    up = normalize(cross(forward, right));

    cam.pos     = camPos;
    cam.forward = normalize(forward);
    cam.up      = up;
}
int get_biome(vec2 xz)
{
    //also sample for temp/wet noise w/ some arbitrary offset
    float temp = perlin2D(xz * temp_frequency + vec2(105.0));
    float wet = perlin2D(xz * wet_frequency + vec2(-943.0));
    if(temp >= 0.5 && wet >= 0.5)
    {
        //default biome
        return DEFAULT;
    }
    else if(temp >= 0.5 && wet < 0.5)
    {
        //desert biome
        return DESERT;
    }
    else if(temp < 0.5)
    {
        return TUNDRA;
    }

    return DEFAULT;
}

bool hit_tree(inout RaycastHit hit, vec3 voxel)
{
    float trees_height = 3.0;
    //copy&pasted from hit_terrain
    //add 1 unit for the crate
  

    int biome = get_biome(voxel.xz);

    if(biome != TUNDRA)
    {
        return false;
    }

    //trees can occupy nxn space
    float tree_cell_size = 8.0;

    vec2 xz = floor(voxel.xz);
    vec2 cell = floor(xz / tree_cell_size);
    float noise = whiteNoise2D(cell);
    float tree_threshold = 0.9f;
    if(noise < tree_threshold)
    {
        return false;
    }

    float leaves_radius = 2.0f;
    vec2 cell_origin = cell * tree_cell_size;
    vec2 offset = vec2(hash21(cell+ 3.14) , hash21(cell+ 9.72));
    vec2 trunk_xz = vec2(leaves_radius) +
         floor(cell_origin + offset * (tree_cell_size - leaves_radius * 2.0));

    float tree_base_height = floor(height_map(trunk_xz)); 
    if(tree_base_height <= water_height)
    {
        return false;
    }
    vec3 trunk_top = floor(vec3(trunk_xz.x, tree_base_height + trees_height, trunk_xz.y));
    
    //a tree is in this nxn space
    if(xz == trunk_xz 
        && voxel.y >= tree_base_height 
        && voxel.y <= tree_base_height + trees_height)
    {
        hit.hit = true;
        hit.cube.type = TREE_TRUNK; 
        return true;
    }
    else if(distance(voxel, trunk_top) < leaves_radius)
    {
         hit.hit = true;
        hit.cube.type = TREE_LEAVES; 
        return true;
    }
    

    return false;
}

//tests if voxel is a terrain voxel
bool hit_terrain(inout RaycastHit hit, vec3 voxel)
{
    //samples "infinite" perlin noise atm using helper function
    //will prob choose a different noise to use  
    float height = height_map(voxel.xz);
    if(float(voxel.y) < height && voxel.y >= 0.0) 
    {
        hit.cube.type = get_biome(voxel.xz);
        hit.cube.color = vec4(74.0/255.0, 23.0/255.0, 0.0, 1.0); 
        return true;    
    }
    return false;
}

//test if voxel hit cave
bool hit_cave (inout RaycastHit hit, vec3 voxel)
{
  
    float value = perlin3D(voxel * cave_frequency);

    if(voxel.y < 0.0 && value > 0.5)
    {
        hit.cube.type = CAVE;
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
        hit.cube.color = water_color;
        return true;
    }
    return false;
}


//Uses Amanatides/Woo algorithm for voxel traversal along a ray
//Returns a RaycastHit struct similar to Unity
//https://www.cs.yorku.ca/~amana/research/grid.pdf
RaycastHit raycast_voxels(in Ray ray, int ignoreMask)
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
        bool terrain = enable_terrain && (ignoreMask & DEFAULT) == 0 ? hit_terrain(hit, vec3(voxel)) : false;
        bool clouds = enable_clouds && hit.cube.type == -1 && (ignoreMask & CLOUDS) == 0  ? hit_clouds(hit, vec3(voxel)) : false;    
        bool water = enable_water && hit.cube.type == -1 && (ignoreMask & WATER) == 0 ? hit_water(hit, vec3(voxel)) : false;
        bool cave = test_caves && hit.cube.type == -1 && (ignoreMask & WATER) == 0 ? hit_cave(hit, vec3(voxel)) : false;
        bool crate = (ignoreMask & TREE_TRUNK) == 0 ? hit_tree(hit, vec3(voxel)) : false;
        if(terrain || clouds || water || cave || crate)
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

    hit.maxed_out = true;
    return hit;
}

vec4 color_dark_trunk(float value)
{
    vec4 brown_0 = vec4(44.0/255.0, 29.0/255.0, 15.0/255.0, 1.0);
    vec4 brown_1 = vec4(24.0/255.0, 14.0/255.0, 5.0/255.0, 1.0);
    vec4 brown_2 = vec4(39.0/255.0, 25.0/255.0, 11.0/255.0, 1.0);
    return value < .33f ? brown_0 : value < 0.66f ? brown_1 : brown_2;
}
//maps white noise value to a snow color
vec4 color_snow(float value)
{
    //colors picked from official snow cube
    vec4 snow_0 = vec4(222.0/255.0, 238.0/255.0, 238.0/255.0, 1.0);
    vec4 snow_1 = vec4(233.0/255.0, 250.0/255.0, 250.0/255.0, 1.0);
    vec4 snow_2 = vec4(250.0/255.0, 250.0/255.0, 250.0/255.0, 1.0);
    return value < 0.33f ? snow_0 : (value < 0.66f ? snow_1 : snow_2);
}

vec4 color_dark_leaves(float value)
{
    vec4 leaves_0 = vec4(33.0/255.0, 52.0/255.0, 32.0/255.0, 1.0);
    vec4 leaves_1 = vec4(21.0/255.0, 34.0/255.0, 21.0/255.0, 1.0);

    return value < 0.5f ? leaves_0 : leaves_1;   
}

//maps green noise value to a grass color
vec4 color_grass(float value)
{
    //colors picked from official grass cube
    vec4 grass_0 = vec4(0.22, 0.30, 0.14, 1.0);
    vec4 grass_1 = vec4(0.30, 0.42, 0.20, 1.0);
    vec4 grass_2 = vec4(0.42, 0.55, 0.30, 1.0);
    return value < 0.33f ? grass_0 : (value < 0.66f ? grass_1 : grass_2);
}

//maps white noise value to a snow color
vec4 color_ground(float value)
{
    vec4 stone = vec4(108.0/255.0, 108.0/255.0, 108.0/255.0, 1.0);
    vec4 brown_0 = vec4(54.0/255.0, 37.0/255.0, 25.0/255.0, 1.0);
    vec4 brown_1 = vec4(74.0/255.0, 52.0/255.0, 35.0/255.0, 1.0);
    vec4 brown_2 = vec4(148.0/255.0, 106.0/255.0, 74.0/255.0, 1.0);
    vec4 brown_3 = vec4(120.0/255.0, 86.0/255.0, 59.0/255.0, 1.0);
    return value < 0.05 ? stone : value < .25 ? brown_0 : value < 0.50 ? brown_1 : value < 0.75 ? brown_2 : brown_3;
}

vec4 color_desert(float value)
{
    vec4 sand_0 = vec4(0.76, 0.70, 0.58, 1.0);
    vec4 sand_1 = vec4(0.83, 0.78, 0.64, 1.0);
    vec4 sand_2 = vec4(0.90, 0.85, 0.67, 1.0);
    vec4 sand_3 = vec4(0.93, 0.90, 0.73, 1.0);
    vec4 sand_4 = vec4(0.96, 0.94, 0.80, 1.0);
    return value < 0.05 ? sand_0 : value < 0.25 ? sand_1 :value < 0.50 ? sand_2 : value < 0.75 ? sand_3 : sand_4;

}

vec4 color_tundra(in RaycastHit hit)
{
    //begin snow at local_y > snow_begin
    float snow_begin = .25f;
    float mix = 0.05f;

    float value = sample_cube(iChannel0, hit).r;    
    float local_y = (hit.point - hit.cube.pos).y;

    if(local_y > snow_begin)
    {
        return color_snow(value);
    }
    else if(local_y > snow_begin - mix)
    {
        //quick mix
        return value > 0.66f ? color_ground(value) : color_snow(value);
    }
    else{
        return color_ground(value);
    }
}
vec4 color_tundra_tree_leaves(in RaycastHit hit)
{
    //begin snow at local_y > snow_begin
    float snow_begin = .25f;
    float mix = 0.05f;

    float value = sample_cube(iChannel0, hit).r;    
    float local_y = (hit.point - hit.cube.pos).y;

    if(local_y > snow_begin)
    {
        return color_snow(value);
    }
    else{
        return color_dark_leaves(value);
    }
}



vec4 color_default(in RaycastHit hit)
{
    //begin grass at local_y > snow_begin
    float grass_begin = .25f;
    float mix = 0.05f;

    float value = sample_cube(iChannel0, hit).r;
    
    float local_y = (hit.point - hit.cube.pos).y;

    if(local_y > grass_begin)
    {
        return color_grass(value);
    }
    else if(local_y > grass_begin - mix)
    {
        //quick mix
        return value > 0.66f ? color_ground(value) : color_grass(value);
    }
    else{
        return color_ground(value);
    }
}

vec4 get_biome_ambient(in RaycastHit hit)
{
    vec4 ambient = vec4(0.0, 0.0, 0.0, 1.0);
    if(!hit.hit){ return ambient;}

    bool biome_cube = hit.cube.type == DEFAULT
            || hit.cube.type == TUNDRA
            || hit.cube.type == DESERT
            || hit.cube.type == CAVE;
    
    if(hit.cube.type == DEFAULT)
    {
        ambient = color_default(hit);
    }
    else if(hit.cube.type == DESERT)
    {
        float value = sample_cube(iChannel0, hit).r;
        ambient = color_desert(value);
    }        
    else if(hit.cube.type == TUNDRA)
    {
        ambient = color_tundra(hit);
    }
    else if(hit.cube.type == CAVE)
    {
        float value = sample_cube(iChannel0, hit).r;
        ambient = vec4(0.5, 0.5, 0.5, 1.0) * value;
    }
    else if(hit.cube.type == TREE_TRUNK)
    {
        float value = sample_cube(iChannel0, hit).r;
        ambient = color_dark_trunk(value);
        
    }
    else if(hit.cube.type == TREE_LEAVES)
    {
       ambient = color_tundra_tree_leaves(hit);
    }

    return ambient;
}

bool is_biome(int type)
{
    return type == DEFAULT 
    || type == TUNDRA 
    || type == DESERT 
    || type == CAVE 
    || type == TREE_TRUNK
    || type == TREE_LEAVES;
}
vec4 color_cube(in Ray ray)
{
    RaycastHit hit = raycast_voxels(ray, 0);
    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);

    if(hit.hit)
    { 
        //default ground is type0 

        bool biome_cube = is_biome(hit.cube.type);
        //COLOR + TEXTURES
        if(biome_cube)
        {
            color += get_biome_ambient(hit);
        }
        //clouds = 1
        else if(hit.cube.type == CLOUDS)
        {
            // since the clouds are transpareent we need to blend the cloud color and sky color together
            vec4 sky = color_sky(ray.dir);
            float a = hit.cube.color.a;
            vec3 col = mix(sky.rgb, hit.cube.color.rgb, a);

            return vec4(col, 1.0);
        }
        //water = 2
        else if (hit.cube.type == WATER)
        {
            //color += hit.cube.color;
            
            //shoot a second ray to get biome
            Ray water_ray = Ray(hit.point, ray.dir);
            RaycastHit water_hit = raycast_voxels(water_ray, (WATER));

            //colors
            vec4 sand_color = get_biome_ambient(water_hit);
            vec3 reflected = normalize((ray.dir - (2.0f * dot(ray.dir, hit.normal) * hit.normal)));
            vec4 water_color = vec4(getSkyColor(reflected), 1.0);

            //mix sand and water color
            color += mix(sand_color, water_color, clamp(water_hit.distance / water_depth, 0.0, 1.0));
        }

        //LIGHTS + SHADOWS
        if(biome_cube || hit.cube.type == WATER)
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
            if(enable_shadows)
            {
                Ray shadow_ray = Ray(hit.point - light.dir * 0.001, -light.dir);
                RaycastHit shadow_hit = raycast_voxels(shadow_ray, 0); 

                //for caves - if max_steps is reached assume NO light/shadows         
                if(!shadow_hit.hit && !(hit.cube.type == CAVE && shadow_hit.maxed_out))
                {
                    //no lighting    
                    vec4 diffuse = light.color * max(0.0, dot(hit.normal, -light.dir));
                    color += diffuse;        
                } 
            }                   
        }        

        //REFLECTION
        if(hit.cube.type == WATER && enable_reflections)
        {
            //basic reflection that supports 1 bounce only
            vec3 reflected = normalize((ray.dir - (2.0f * dot(ray.dir, hit.normal) * hit.normal)));
            Ray reflected_ray = Ray(hit.point + reflected * 0.001f, reflected);
            RaycastHit reflected_hit = raycast_voxels(reflected_ray, 0);

            //can't do recursion, can cleanup code later for better reflection
            if(reflected_hit.hit)
            {
                 float dist_fade = 1.0 - smoothstep(5.0, 512.0, reflected_hit.distance);
                if(is_biome(reflected_hit.cube.type))
                {
                    //float value = sample_cube(iChannel0, reflected_hit).r;
                    vec4 ambient = get_biome_ambient(reflected_hit);
                   
                    color += ambient * reflection_strength * dist_fade;           
                }
                else
                {
                    color += reflected_hit.cube.color * reflection_strength* dist_fade;
                }                
            }           
        }

        vec3 fog_color = getSkyColor(ray.dir);
        float fog_amount = getFogAmount(hit.distance);
        return mix(color, vec4(fog_color, 1.0), fog_amount);
    }

    return vec4(-1.0, 0.0, 0.0, 1.0);
}




void day_night_cycle()
{
    // move the sun/moon around xy unit circle
    vec3 sun_position = vec3(cos(1.57 + iTime * day_night_speed), sin(1.57 + iTime *day_night_speed), 0.0);
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