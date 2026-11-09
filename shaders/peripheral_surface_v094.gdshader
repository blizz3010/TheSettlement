shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(.43,.40,.33,1.0);
uniform int kind = 0; // 0 limestone; 1 prepared turf; 2 earth overlay.
uniform float variation = .13;
uniform float roughness = .90;
uniform float contact = 0.0;
varying vec3 p;
varying vec4 vcolor;
float hash21(vec2 q) {return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 q) {
 vec2 i=floor(q),f=fract(q);f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;vcolor=COLOR;}
void fragment(){
 float broad=noise2(p.xz*.71+p.yy*.2),fine=noise2(p.xz*18.0+p.yy*11.0);
 float filtered=1.0-smoothstep(.05,.25,length(fwidth(p)));
 vec3 base=tint.rgb*(1.0+variation*((broad-.5)+(fine-.5)*.24*filtered));
 float damp=(1.0-smoothstep(.08,.60,p.y))*contact;
 base*=1.0-damp*.16;
 if(kind==1){
  float lawn=noise2(p.xz*.19)*.62+noise2(p.xz*.71)*.38;
  base=tint.rgb*mix(.87,1.10,lawn)*(1.0+(fine-.5)*.14*filtered);
 }
 if(kind==2){
  float lawn=noise2(p.xz*.19)*.62+noise2(p.xz*.71)*.38;
  vec3 turf=mix(vec3(.105,.158,.068),vec3(.205,.259,.114),lawn);
  turf*=1.0+(noise2(p.xz*10.0)-.5)*.28*filtered;
  base=mix(turf,base,vcolor.a);
 }
 ALBEDO=base;ROUGHNESS=clamp(roughness+(fine-.5)*.06,.7,1.0);SPECULAR=.08;
}
