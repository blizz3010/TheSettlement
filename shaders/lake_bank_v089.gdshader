shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float broad=noise(wp.xz*.19)*.62+noise(wp.xz*.71)*.38;
 float fine=noise(wp.xz*10.0);
 float filter_amount=1.0-smoothstep(.06,.25,length(fwidth(wp.xz)));
 vec3 turf=mix(vec3(.105,.158,.068),vec3(.205,.259,.114),broad);
 turf*=1.0+(fine-.5)*.28*filter_amount;
 vec3 soil=mix(vec3(.08,.075,.055),vec3(.20,.18,.12),noise(wp.xz*4.0));
 float edge=length((wp.xz-vec2(20.0,130.0))/vec2(100.0,75.0));
 float wet=(1.0-smoothstep(.72,1.25,wp.y))*(1.0-smoothstep(1.0,1.025,edge));
 ALBEDO=mix(turf,soil,wet);ROUGHNESS=.98;SPECULAR=.08;
}
