shader_type canvas_item;

uniform sampler2D noise_texture : source_color, repeat_enable;

// Base glass
uniform vec4 tint_color : source_color = vec4(0.76, 0.84, 0.95, 0.24);

// Diffusion / fake blur
uniform float cloud_scale : hint_range(0.1, 10.0) = 1.2;
uniform float grain_scale : hint_range(1.0, 40.0) = 20.0;
uniform float cloud_strength : hint_range(0.0, 0.3) = 0.16;
uniform float grain_strength : hint_range(0.0, 0.15) = 0.035;
uniform float warp_strength : hint_range(0.0, 0.08) = 0.02;

// Lighting
uniform float top_glow : hint_range(0.0, 0.3) = 0.11;
uniform float center_haze : hint_range(0.0, 0.3) = 0.06;

// Thickness / bevel
uniform float outer_edge_width : hint_range(0.001, 0.12) = 0.035;
uniform float inner_edge_width : hint_range(0.001, 0.12) = 0.07;
uniform float outer_highlight : hint_range(0.0, 0.5) = 0.22;
uniform float inner_highlight : hint_range(0.0, 0.5) = 0.10;
uniform float inner_shadow : hint_range(0.0, 0.5) = 0.10;
uniform float rim_blue_strength : hint_range(0.0, 0.3) = 0.06;

// Rounded corners
uniform float corner_radius : hint_range(0.0, 100.0) = 22.0;
uniform float corner_softness : hint_range(0.1, 10.0) = 1.5;

float rounded_box_sdf(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 uv = UV;

	// --- Rounded mask in pixel space ---
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = uv * size - size * 0.5;
	vec2 half_size = size * 0.5;

	float sdf = rounded_box_sdf(p, half_size - vec2(1.0), corner_radius);
	float mask = 1.0 - smoothstep(0.0, corner_softness, sdf);

	// Noise layers
	vec4 cloud_tex = texture(noise_texture, uv * cloud_scale);
	vec4 grain_tex = texture(noise_texture, uv * grain_scale);

	vec2 warp = (cloud_tex.rg - 0.5) * warp_strength;
	vec4 warped_cloud_tex = texture(noise_texture, uv * cloud_scale + warp);

	float cloud = ((cloud_tex.r - 0.5) + (warped_cloud_tex.g - 0.5)) * 0.5 * cloud_strength;
	float grain = (grain_tex.r - 0.5) * grain_strength;

	vec3 color = tint_color.rgb;

	// Fake blur / diffusion
	color += vec3(cloud);
	color += vec3(grain);

	// Top glow
	float top_light = (1.0 - smoothstep(0.0, 0.35, uv.y)) * top_glow;
	color += vec3(top_light);

	// Slight center milkiness
	float center_mask_x = 1.0 - abs(uv.x * 2.0 - 1.0);
	float center_mask_y = 1.0 - abs(uv.y * 2.0 - 1.0);
	float center_mask = center_mask_x * center_mask_y;
	color += vec3(center_mask * center_haze);

	// Outer edge mask
	float left_o = 1.0 - smoothstep(0.0, outer_edge_width, uv.x);
	float right_o = 1.0 - smoothstep(0.0, outer_edge_width, 1.0 - uv.x);
	float top_o = 1.0 - smoothstep(0.0, outer_edge_width, uv.y);
	float bottom_o = 1.0 - smoothstep(0.0, outer_edge_width, 1.0 - uv.y);
	float outer_edge = max(max(left_o, right_o), max(top_o, bottom_o));

	// Inner bevel band
	float left_i = 1.0 - smoothstep(0.0, inner_edge_width, uv.x);
	float right_i = 1.0 - smoothstep(0.0, inner_edge_width, 1.0 - uv.x);
	float top_i = 1.0 - smoothstep(0.0, inner_edge_width, uv.y);
	float bottom_i = 1.0 - smoothstep(0.0, inner_edge_width, 1.0 - uv.y);
	float inner_band = max(max(left_i, right_i), max(top_i, bottom_i));

	float bevel_band = clamp(inner_band - outer_edge, 0.0, 1.0);

	// Bright outer rim
	color += vec3(outer_edge * outer_highlight);

	// Cool blue outer rim tint
	color += vec3(0.22, 0.45, 0.78) * (outer_edge * rim_blue_strength);

	// Inner bevel highlight (top-left bias)
	float bevel_light = bevel_band * ((1.0 - uv.y) * 0.7 + (1.0 - uv.x) * 0.3);
	color += vec3(bevel_light * inner_highlight);

	// Inner bevel shadow (bottom-right bias)
	float bevel_shadow = bevel_band * (uv.y * 0.7 + uv.x * 0.3);
	color -= vec3(bevel_shadow * inner_shadow);

	COLOR = vec4(color, tint_color.a * mask);
}