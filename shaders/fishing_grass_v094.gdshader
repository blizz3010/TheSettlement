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
uniform vec2 clearing_center = vec2(17.00153,-38.79084);
uniform vec2 clearing_radii = vec2(1.45,1.25);
varying vec3 worldPos;

void vertex() {
	vec3 root_world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
 float d = distance(root_world.xz, CAMERA_POSITION_WORLD.xz);
 float blend = smoothstep(near_start, near_end, d);
 float keep = near_mode ? 1.0-blend : blend*(1.0-smoothstep(far_end-5.0,far_end,d));
 float clearing = length((root_world.xz-clearing_center)/clearing_radii);
 keep *= smoothstep(.73,1.0,clearing);
 // Local reachable south-bank taper. The casting rectangle remains unchanged.
 float course=-46.5+2.0*sin(root_world.x*.105)+.45*sin(root_world.x*.24);
 float water=.34-.0012*root_world.x;
 bool cast_area=root_world.x>=13.87 && root_world.x<=16.13 && root_world.z>=-45.829 && root_world.z<=-40.569;
 float shore=smoothstep(3.0,4.0,root_world.x)*(1.0-smoothstep(22.0,23.0,root_world.x));
 if(root_world.z>course && root_world.z<course+4.0 && !cast_area){
  keep *= mix(1.0,smoothstep(.02,.46,root_world.y-water),shore);
 }
 VERTEX.y *= keep;
 worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 noiseLevel = texture(noise, worldPos.xz / noiseScale).rgb;
	ALBEDO = mix(color, color2, 1.0- UV.y) * mix(color, color2, noiseLevel.r);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}