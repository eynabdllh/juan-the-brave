// A shader that creates volumetric, multi-layered fog like the reference image.
shader_type canvas_item;

// --- You can tune these in the Inspector to get the perfect look! ---
uniform vec4 fog_color : source_color = vec4(0.8, 0.85, 0.9, 0.4); // A soft, off-white, semi-transparent color
uniform float zoom : hint_range(1.0, 10.0) = 4.0;                   // Lower number = bigger, softer fog wisps
uniform float density : hint_range(0.1, 1.0) = 0.5;                 // How thick the fog is. Higher = more fog
uniform float speed_main : hint_range(0.0, 0.1) = 0.02;             // Speed of the main fog layer
uniform float speed_detail : hint_range(0.0, 0.1) = 0.035;          // Speed of the detail layer (parallax)

// --- Noise Functions ---
// These functions work together to create natural-looking patterns.
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.y * u.x;
}

// Fractional Brownian Motion (FBM) - This is the key to the volumetric look.
// It layers noise on top of itself to create detail and depth.
float fbm(vec2 st) {
    float value = 0.0;
    float amplitude = 0.5;
    // More octaves = more detailed, whispy fog
    for (int i = 0; i < 6; i++) {
        value += amplitude * noise(st);
        st *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// --- Main Shader Logic ---
void fragment() {
    // 1. CREATE TWO LAYERS
    // We create two sets of coordinates that move at different speeds.
    // This creates a parallax effect, giving the fog a sense of depth.
    vec2 uv_main = UV * zoom;
    uv_main.x += TIME * speed_main;
    
    vec2 uv_detail = UV * zoom * 2.0; // Detail layer is more zoomed in
    uv_detail.x += TIME * speed_detail; // and moves slightly faster
    
    // 2. GENERATE THE NOISE FOR EACH LAYER
    float main_fog = fbm(uv_main);
    float detail_fog = fbm(uv_detail);
    
    // 3. COMBINE THE LAYERS
    // We combine the two layers. The detail layer is used to "erode" or create holes in the main layer.
    float combined_fog = main_fog - detail_fog;
    
    // 4. DRAW THE FINAL FOG
    // Use smoothstep to create soft, feathery edges based on our density control.
    float final_alpha = smoothstep(density - 0.1, density + 0.2, combined_fog);
    
    // Set the final color and transparency.
    COLOR = fog_color;
    COLOR.a *= final_alpha;
}