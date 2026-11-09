shader_type spatial;
render_mode cull_disabled;
varying vec3 pos;
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float a=pos.x*.63+pos.z*.41+TIME*.38;
 float b=pos.z*.89-pos.x*.25+TIME*.27;
 float waves=sin(a)*cos(b);
 ALBEDO=mix(vec3(.025,.095,.12),vec3(.065,.17,.19),waves*.18+.5);
 ROUGHNESS=.55;METALLIC=0.0;SPECULAR=.12;
 // World-space normal avoids undefined tangent bases on the untextured fan mesh.
 vec3 world_normal=normalize(vec3(.012*cos(a),1.0,.009*sin(b)));
 NORMAL=normalize((VIEW_MATRIX*vec4(world_normal,0.0)).xyz);
}
