shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec2 surface_uv;
void vertex(){surface_uv=UV;}
void fragment(){
 // Opaque tread ribs, filtered with derivatives to avoid distant shimmer.
 float phase=surface_uv.y/0.18;
 float line=abs(fract(phase+0.5)-0.5);
 float footprint=max(fwidth(phase),0.002);
 float rib=1.0-smoothstep(0.055,0.055+footprint,line);
 rib*=1.0-smoothstep(0.25,0.65,footprint);
 ALBEDO=mix(vec3(0.19,0.225,0.22),vec3(0.28,0.315,0.30),rib*0.5);
 METALLIC=0.30;ROUGHNESS=0.92;SPECULAR=0.2;
}
