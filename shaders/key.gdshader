// A simple shader to make an item gently pulse with light.
shader_type canvas_item;

// You can change these in the Inspector!
uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 0.7, 0.5); // A soft, pale yellow
uniform float speed = 2.0;

void fragment() {
    // Get the original color of the sprite pixel
    vec4 original_color = texture(TEXTURE, UV);
    
    // Create a gentle pulsing effect using a sine wave on time
    float pulse = (sin(TIME * speed) + 1.0) * 0.5; // Ranges from 0.0 to 1.0
    
    // Mix the original color with the glow color based on the pulse.
    // We only apply the glow to the visible parts of the sprite.
    COLOR = mix(original_color, glow_color, pulse * original_color.a);
    COLOR.a = original_color.a; // Keep the original alpha
}