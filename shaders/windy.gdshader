// For a Tile in a TileSet, CanvasItem shader (Corrected Version)
shader_type canvas_item;

uniform float speed = 1.0;
uniform float minStrength : hint_range(0.0, 0.1) = 0.02;
uniform float maxStrength : hint_range(0.0, 0.1) = 0.05;
uniform float strengthScale = 10.0;
uniform float interval = 3.5;
uniform float detail = 1.0;
uniform float distortion : hint_range(0.0, 1.0);
uniform float heightOffset : hint_range(0.0, 1.0);
uniform float offset = 0.0;

float getWind(vec2 vertex, vec2 uv, float time){
    float diff = pow(maxStrength - minStrength, 2.0);
    float strength = clamp(minStrength + diff + sin(time / interval) * diff, minStrength, maxStrength) * strengthScale;
    float wind = (sin(time) + cos(time * detail)) * strength * max(0.0, (1.0 - uv.y) - heightOffset);
    return wind; 
}

void vertex() {
    // --- THE CRITICAL FIX IS HERE ---
    // Get the world position of the current vertex being drawn.
    // MODEL_MATRIX is the correct 2D equivalent of the old WORLD_MATRIX.
    vec2 world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;

    // We add the world position to the time. This makes each tree sway differently
    // based on its location, preventing them from looking like a synchronized army.
    // The small multipliers prevent the effect from being too chaotic.
    float time = (TIME * speed) + (world_pos.x * 0.01) + offset;
    
    // Apply the wind effect using this unique, position-aware time.
    VERTEX.x += getWind(VERTEX, UV, time);
}