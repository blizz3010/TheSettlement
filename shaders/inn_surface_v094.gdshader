shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Inn-only, static, texture-free finish. No displacement or global lighting changes.
uniform vec4 tint : source_color = vec4(.45,.30,.18,1.0);
uniform int kind = 0; // 0 timber member, 1 floorboards, 2 plaster, 3 woven cloth
uniform int grain_axis = 0;
uniform float roughness = .82;
varying vec3 local_position;
varying vec3 local_normal;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise2(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void vertex() { local_position=VERTEX; local_normal=NORMAL; }
void fragment() {
 vec3 p=local_position;
 vec2 q=grain_axis==0 ? p.zy : (grain_axis==1 ? p.xz : p.xy);
 float along=grain_axis==0 ? p.x : (grain_axis==1 ? p.y : p.z);
 float tone=1.0;
 if(kind==1) {
  float row=floor(p.x/.25), offset=hash21(vec2(row,9.0))*2.4;
  vec2 board=vec2(p.x/.25,(p.z+offset)/2.4);
  vec2 edge=min(fract(board),1.0-fract(board));
  vec2 fw=max(fwidth(board),vec2(.0001));
  float seam=1.0-min(smoothstep(.007-fw.x,.007+fw.x,edge.x),smoothstep(.002-fw.y,.002+fw.y,edge.y));
  float grain=noise2(vec2(p.x*90.0,p.z*1.8));
  float detail=1.0-smoothstep(.12,.6,length(fwidth(vec2(p.x*90.0,p.z*1.8))));
  tone=(.94+hash21(floor(board))*.13)*(1.0+(grain-.5)*.13*detail);
  tone=mix(tone,.43,seam*.65);
 } else if(kind==2) {
  vec2 wall=abs(local_normal.x)>.5?p.zy:p.xy;
  tone=.98+noise2(wall*4.0)*.04;
 } else if(kind==3) {
  vec2 weave=p.xz*180.0;
  float detail=1.0-smoothstep(.25,.85,length(fwidth(weave)));
  tone=1.0+(sin(weave.x)*sin(weave.y))*.035*detail;
 } else {
  float grain=noise2(q*32.0+vec2(noise2(vec2(along*.45,q.x*4.0))*.7,along*.7));
  float detail=1.0-smoothstep(.2,.8,length(fwidth(q*32.0)));
  tone=.97+noise2(vec2(along*.55,q.x*5.0))*.06+(grain-.5)*.14*detail;
 }
 ALBEDO=tint.rgb*tone;
 ROUGHNESS=roughness;
 METALLIC=0.0;
}
