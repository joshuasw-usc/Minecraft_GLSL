//AI generated helper functions
//We must write out own noise later

// Simple hash: maps 2D integer coords to a random float in [0, 1)
float hash21(vec2 p) {
    // large, odd constants to scramble bits
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// ---- small 3D->1D hash for pseudo-randomness ----
float hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

// Turn hash into a random 2D gradient on the unit circle
vec2 grad2(vec2 ip) {
    float a = hash21(ip) * 6.2831853; // 2*pi
    return vec2(cos(a), sin(a));
}

// Smoothstep curve used by Perlin (fade)
float fade(float t) {
    // 6t^5 - 15t^4 - 10t^3 (classic Perlin)
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Infinite 2D Perlin-like noise
float perlin2D(vec2 p) {
    // Lattice coords
    vec2 ip = floor(p);
    vec2 fp = fract(p);

    // Gradients at 4 corners of the cell
    vec2 g00 = grad2(ip + vec2(0.0, 0.0));
    vec2 g10 = grad2(ip + vec2(1.0, 0.0));
    vec2 g01 = grad2(ip + vec2(0.0, 1.0));
    vec2 g11 = grad2(ip + vec2(1.0, 1.0));

    // Vectors from each corner to p
    vec2 d00 = fp - vec2(0.0, 0.0);
    vec2 d10 = fp - vec2(1.0, 0.0);
    vec2 d01 = fp - vec2(0.0, 1.0);
    vec2 d11 = fp - vec2(1.0, 1.0);

    // Dot products
    float v00 = dot(g00, d00);
    float v10 = dot(g10, d10);
    float v01 = dot(g01, d01);
    float v11 = dot(g11, d11);

    // Smooth interpolation weights
    vec2 u = vec2(fade(fp.x), fade(fp.y));

    // Bilinear interpolation with smooth weights
    float x0 = mix(v00, v10, u.x);
    float x1 = mix(v01, v11, u.x);
    float v  = mix(x0, x1, u.y);

    // Optional: map from roughly [-1,1] to [0,1]
    return 0.5 * v + 0.5;
}



//Gets a pseduo random vector3
vec3 random_vec3D(vec3 ip) {
    float x = hash13(ip);
    float y = hash13(ip + 19.1);
    float z = hash13(ip + 47.3);

    // map [0,1] → [-1,1]
    vec3 g = vec3(x,y,z) * 2.0 - 1.0;
    return normalize(g);
}


// Map pos to 3D Perlin-like noise in [0,1]
float perlin3D(vec3 p)
{
    // Lattice coordinates and local fractional position
    vec3 ip = floor(p);
    vec3 fp = fract(p);

    // Gradients at 8 corners of the cell
    vec3 g000 = random_vec3D(ip + vec3(0.0, 0.0, 0.0));
    vec3 g100 = random_vec3D(ip + vec3(1.0, 0.0, 0.0));
    vec3 g010 = random_vec3D(ip + vec3(0.0, 1.0, 0.0));
    vec3 g110 = random_vec3D(ip + vec3(1.0, 1.0, 0.0));
    vec3 g001 = random_vec3D(ip + vec3(0.0, 0.0, 1.0));
    vec3 g101 = random_vec3D(ip + vec3(1.0, 0.0, 1.0));
    vec3 g011 = random_vec3D(ip + vec3(0.0, 1.0, 1.0));
    vec3 g111 = random_vec3D(ip + vec3(1.0, 1.0, 1.0));

    // Vectors from each corner to p
    vec3 d000 = fp - vec3(0.0, 0.0, 0.0);
    vec3 d100 = fp - vec3(1.0, 0.0, 0.0);
    vec3 d010 = fp - vec3(0.0, 1.0, 0.0);
    vec3 d110 = fp - vec3(1.0, 1.0, 0.0);
    vec3 d001 = fp - vec3(0.0, 0.0, 1.0);
    vec3 d101 = fp - vec3(1.0, 0.0, 1.0);
    vec3 d011 = fp - vec3(0.0, 1.0, 1.0);
    vec3 d111 = fp - vec3(1.0, 1.0, 1.0);

    // Dot products (influence of each corner)
    float v000 = dot(g000, d000);
    float v100 = dot(g100, d100);
    float v010 = dot(g010, d010);
    float v110 = dot(g110, d110);
    float v001 = dot(g001, d001);
    float v101 = dot(g101, d101);
    float v011 = dot(g011, d011);
    float v111 = dot(g111, d111);

    // Smooth interpolation weights
    vec3 u = vec3(fade(fp.x), fade(fp.y), fade(fp.z));

    // Trilinear interpolation with smooth weights
    float x00 = mix(v000, v100, u.x);
    float x10 = mix(v010, v110, u.x);
    float x01 = mix(v001, v101, u.x);
    float x11 = mix(v011, v111, u.x);

    float y0 = mix(x00, x10, u.y);
    float y1 = mix(x01, x11, u.y);

    float v = mix(y0, y1, u.z);

    // Map from roughly [-1,1] to [0,1]
    return v * 0.5 + 0.5;
}