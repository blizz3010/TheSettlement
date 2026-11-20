// P2B copy of assets/settlement_grass_v086/grass_lod.gdshader (pinned, not edited). Installed only on the
// SettlementGroundGrassV086 batches (and their GrassViewCulling sub-chunks) that touch the inn hill, by
// raid/scripts/inn_hillside_finish.gd. Identical to the original outside the inn-hill mask; inside it the
// same patch field as p2b_ground_finish.gdshader shortens and thins tufts in dry patches, lifts them a
// little in clover, and tints them to match. inn_hill_variation 0 restores the original exactly.
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
uniform float inn_hill_variation : hint_range(0.0, 1.0) = 1.0;
varying vec3 p2b_tint;

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
float hill_hash(vec2 p) { vec3 p3=fract(vec3(p.xyx)*.1031); p3+=dot(p3,p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }
float hill_noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hill_hash(i),hill_hash(i+vec2(1,0)),f.x),mix(hill_hash(i+vec2(0,1)),hill_hash(i+vec2(1,1)),f.x),f.y);
}
float hill_mask(vec2 p) {
 return smoothstep(-27.0,-22.0,p.x)*(1.0-smoothstep(24.0,29.0,p.x))*smoothstep(22.0,27.0,p.y)*(1.0-smoothstep(49.0,53.0,p.y))*inn_hill_variation;
}
void vertex() {
	vec3 root_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
 float d = distance(root_world.xz, CAMERA_POSITION_WORLD.xz);
 float blend = smoothstep(near_start, near_end, d);
 float keep = near_mode ? 1.0-blend : blend*(1.0-smoothstep(far_end-5.0,far_end,d));
 float feather=rook_feather(root_world.xz);
 VERTEX.y *= keep*feather;
 p2b_tint=vec3(1.0);
 float hm=hill_mask(root_world.xz);
 if (hm>0.0) {
  vec2 p=root_world.xz;
  float dry=smoothstep(.80,.88,hill_noise(p*.115+vec2(3.1,9.7)));
  float clover=smoothstep(.64,.76,hill_noise(p*.205+vec2(11.3,4.2)))*(1.0-dry);
  float mottle=hill_noise(p*.62+vec2(1.7,5.3));
  // Dry patches: shorter, thinner turf (about 40 % of tufts dropped at the patch core); clover a bit fuller.
  float kept=step(hill_hash(floor(p*4.3)+vec2(7.0,2.0)),1.0-.5*dry);
  float h=mix(1.0,mix(.5,1.0,1.0-dry)*mix(1.0,1.12,clover)*mix(.9,1.08,mottle)*kept,hm);
  VERTEX.y*=h;
  VERTEX.xz*=mix(1.0,kept,hm);
  vec3 t=vec3(mix(.80,1.24,mottle)*1.08);
  t=mix(t,vec3(1.45,1.30,.58),dry*.85);
  t=mix(t,vec3(.62,.80,.64),clover*.85);
  p2b_tint=mix(vec3(1.0),t,hm);
 }
 // Zero-height rejected tufts must not leave broad flat green cards on soil.
 VERTEX.xz *= mix(.0,1.0,smoothstep(0.0,.12,feather));
 worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 noiseLevel = texture(noise, worldPos.xz / noiseScale).rgb;
	ALBEDO = mix(color, color2, 1.0- UV.y) * mix(color, color2, noiseLevel.r);
	ALBEDO *= p2b_tint;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}