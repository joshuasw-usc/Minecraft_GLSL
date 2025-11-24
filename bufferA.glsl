// WASD movement
// W: Forward
// A: Left
// S: Backward
// D: Right

float max_terrain_height = 120.0;

// Shadertoy keyboard helper
bool keyDown(int keyCode)
{
    return texelFetch(iChannel1, ivec2(keyCode, 0), 0).x > 0.01;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    ivec2 fc = ivec2(fragCoord);

    // only care about pixel (0,0) - clear everything else.
    if (!(fc.x == 0 && fc.y == 0))
    {
        fragColor = vec4(0.0);
        return;
    }

    vec3 camPos;

    // Initial camera position
    if (iFrame == 0)
        camPos = vec3(0.0, max_terrain_height * 0.66, 0.0);
    else
        camPos = texelFetch(iChannel0, ivec2(0, 0), 0).xyz;

    // Mouse Input
    vec2 m = iMouse.xy / iResolution.xy;
    float yaw   = (m.x - 0.5) * 6.2831853;
    float pitch = (m.y - 0.5) * 1.2;

    vec3 camForward;
    camForward.x = cos(pitch) * sin(yaw);
    camForward.y = sin(pitch);
    camForward.z = cos(pitch) * cos(yaw);
    camForward = normalize(camForward);

    vec3 up    = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(up, camForward));

    // WASD: 'W'=87, 'A'=65, 'S'=83, 'D'=68
    float w = keyDown(87) ? 1.0 : 0.0;
    float s = keyDown(83) ? 1.0 : 0.0;
    float a = keyDown(65) ? 1.0 : 0.0;
    float d = keyDown(68) ? 1.0 : 0.0;

    float forwardInput = w - s;
    float rightInput   = d - a;

    float moveSpeed = 20.0;
    float dt = (iFrame == 0) ? 0.0 : iTimeDelta;

    vec3 moveDir = vec3(0.0);
    if (forwardInput != 0.0)
        moveDir += camForward * forwardInput;
    if (rightInput != 0.0)
        moveDir += right * rightInput;

    if (length(moveDir) > 0.0)
    {
        moveDir = normalize(moveDir);
        camPos += moveDir * moveSpeed * dt;
    }

    // Keep above ground

    // Store position in (0,0)
    fragColor = vec4(camPos, 1.0);
}
