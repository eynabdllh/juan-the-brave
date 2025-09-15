// For a ColorRect, CanvasItem shader
shader_type canvas_item;

// --- You can tune these in the Inspector! ---
uniform vec4 cloud_color : source_color = vec4(0.0, 0.0, 0.0, 0.25);
uniform float cloud_speed : hint_range(0.0, 0.1) = 0.015;
uniform float zoom : hint_range(1.0, 10.0) = 3.0;
uniform float pixel_size : hint_range(1.0, 16.0) = 4.0;
uniform int FBM_octaves : hint_range(1, 8) = 6;

// --- NEW AND MODIFIED PARAMETERS ---
uniform float density : hint_range(0.1, 1.0) = 0.5; // Renamed from cloud_cover for clarity
uniform float edge_softness : hint_range(0.01, 0.5) = 0.1; // This controls the blur!

uniform vec2 screen_size; // Set by the controller script

// --- Noise Functions (no changes here) ---
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}
float noise(vec2 st) {
    vec2 i = floor(st); vec2 f = fract(st); vec2 u = f * f * (3.0 - 2.0 * f);
    float a = random(i); float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0)); float d = random(i + vec2(1.0, 1.0));
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.y * u.x;
}
float fbm(vec2 st) {
    float value = 0.0; float amplitude = 0.5;
    for (int i = 0; i < FBM_octaves; i++) {
        value += amplitude * noise(st); st *= 2.0; amplitude *= 0.5;
    }
    return value;
}

// --- Main Shader Logic ---
void fragment() {
    // 1. PIXELATION (Using our 'screen_size' variable)
    vec2 pixelated_uv = floor(UV * (screen_size / pixel_size)) / (screen_size / pixel_size);

    // 2. ANIMATION & SCALING
    vec2 motion = vec2(TIME * cloud_speed, 0.0);
    vec2 final_uv = (pixelated_uv * zoom) + motion;
    
    // 3. GENERATE CLOUD VALUE
    float cloud_value = fbm(final_uv);
    
    // 4. DRAW THE CLOUDS (Using our new parameters)
    // The 'edge_softness' now controls the width of the fade, creating the blur effect.
    float cloud_alpha = smoothstep(density - edge_softness, density + edge_softness, cloud_value);
    
    COLOR = cloud_color;
    COLOR.a *= cloud_alpha;
}