// Retro terminal shader for Ghostty
// Source: https://github.com/0xhckr/ghostty-shaders
// Original: https://www.shadertoy.com/view/WsVSzV (CC BY NC SA 3.0)
//
// Simple retro CRT with teal/green phosphor tint, scanlines, and barrel warp.
// Lightweight alternative to the full CRT shader.

float warp = 0.25; // simulate curvature of CRT monitor
float scan = 0.50; // simulate darkness between scanlines

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    // squared distance from center
    vec2 uv = fragCoord / iResolution.xy;
    vec2 dc = abs(0.5 - uv);
    dc *= dc;

    // warp the fragment coordinates
    uv.x -= 0.5; uv.x *= 1.0 + (dc.y * (0.3 * warp)); uv.x += 0.5;
    uv.y -= 0.5; uv.y *= 1.0 + (dc.x * (0.4 * warp)); uv.y += 0.5;

    // sample inside boundaries, otherwise set to black
    if (uv.y > 1.0 || uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0)
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    else
    {
        // determine if we are drawing in a scanline
        float apply = abs(sin(fragCoord.y) * 0.5 * scan);

        // sample the texture and apply a teal tint
        vec3 color = texture(iChannel0, uv).rgb;
        vec3 tealTint = vec3(0.0, 0.8, 0.6);

        // mix the sampled color with the teal tint based on scanline intensity
        fragColor = vec4(mix(color * tealTint, vec3(0.0), apply), 1.0);
    }
}
