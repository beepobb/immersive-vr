shader_type canvas_item;

uniform sampler2D noise_texture : source_color, repeat_enable;

// Frost controls
uniform float large_noise_scale : hint_range(0.1, 20.0) = 2.5;
uniform float fine_noise_scale  : hint_range(0.1, 40.0) = 10.0;

uniform float large_noise_strength : hint_range(0.0, 1.0) = 0.18;
uniform float fine_noise_strength  : hint_range(0.0, 1.0) = 0.06;

uniform vec4 tint_color : source_color = vec4(0.78, 0.86, 0.92, 0.30);
uniform float milkiness : hint_range(0.0, 1.0) = 0.35;
uniform float brightness : hint_range(0.5, 2.0) = 1.0;

// Edge / panel shaping
uniform float edge_highlight : hint_range(0.0, 0.5) = 0.12;
uniform float edge_width : hint_range(0.001, 0.2) = 0.03;

// Top lighting for glass feel
uniform float top_glow_strength : hint_range(0.0, 0.5) = 0.10;

void fragment() {
	vec2 uv = UV;

	// Two layers of noise:
	// 1) large soft cloudy variation
	// 2) smaller fine frost grain
	vec4 large_noise_tex = texture(noise_texture, uv * large_noise_scale);
	vec4 fine_noise_tex  = texture(noise_texture, uv * fine_noise_scale);

	float large_noise = (large_noise_tex.r - 0.5) * large_noise_strength;
	float fine_noise  = (fine_noise_tex.r - 0.5) * fine_noise_strength;

	// Base frosted glass color
	vec3 glass_color = tint_color.rgb * brightness;

	// Add milkiness to fake blur / diffusion
	glass_color = mix(glass_color, vec3(1.0), milkiness * 0.18);

	// Soft cloudy variation
	glass_color += vec3(large_noise);

	// Fine frost grain
	glass_color += vec3(fine_noise);

	// Slight vertical glow near the top
	float top_glow = (1.0 - smoothstep(0.0, 0.35, uv.y)) * top_glow_strength;
	glass_color += vec3(top_glow);

	// Soft edge highlight
	float left = smoothstep(0.0, edge_width, uv.x);
	float top = smoothstep(0.0, edge_width, uv.y);
	float right = smoothstep(0.0, edge_width, 1.0 - uv.x);
	float bottom = smoothstep(0.0, edge_width, 1.0 - uv.y);

	float inner = left * top * right * bottom;
	float edge = 1.0 - inner;

	glass_color += vec3(edge * edge_highlight);

	COLOR = vec4(glass_color, tint_color.a);
}