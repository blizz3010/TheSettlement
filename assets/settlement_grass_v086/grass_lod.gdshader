shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color;
uniform vec3 color2 : source_color;
uniform sampler2D noise;
uniform float noiseScale = 20.0;

uniform bool near_mode = true;
uniform float near_start = 18.0;
uniform float near_end = 24.0;
uniform float far_end = 55.0;
varying vec3 worldPos;

// V96-04: feather the existing 51 m coverage edge only beside Rook.
// No new roots, no authority edits, no alpha pass and no path encroachment.
float rook_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float rook_feather(vec2 p) {
 if(p.x<=23.0 || p.x>=44.0 || p.y<=30.0 || p.y>=47.0) { return 1.0; }
 float shoulder=51.0-length(p);
 if(shoulder>=2.17) { return 1.0; }
 float region=smoothstep(23.0,26.0,p.x)*(1.0-smoothstep(40.0,44.0,p.x))*smoothstep(30.0,33.0,p.y)*(1.0-smoothstep(43.0,47.0,p.y));
 // Correlated clumps make a broken shoulder instead of a new concentric line.
 float grouped=rook_hash(floor(p*1.7));
 float progress=smoothstep(0.0,2.0,shoulder+.34*(grouped-.5));
 float population=mix(.08,1.0,progress);
 float retained=step(rook_hash(floor(p*103.0)),population);
 float height=mix(.18,1.0,progress);
 return mix(1.0,height*retained,region);
}
void vertex() {
	vec3 root_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
 float d = distance(root_world.xz, CAMERA_POSITION_WORLD.xz);
 float blend = smoothstep(near_start, near_end, d);
 float keep = near_mode ? 1.0-blend : blend*(1.0-smoothstep(far_end-5.0,far_end,d));
 float feather=rook_feather(root_world.xz);
 VERTEX.y *= keep*feather;
 // Zero-height rejected tufts must not leave broad flat green cards on soil.
 VERTEX.xz *= mix(.0,1.0,smoothstep(0.0,.12,feather));
 worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 noiseLevel = texture(noise, worldPos.xz / noiseScale).rgb;
	ALBEDO = mix(color, color2, 1.0- UV.y) * mix(color, color2, noiseLevel.r);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}