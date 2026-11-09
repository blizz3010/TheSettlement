shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float detail_distance=85.0;
varying float blade_height;
void vertex(){
 blade_height=UV.y;
 vec3 root=MODEL_MATRIX[3].xyz;
 float fade=1.0-smoothstep(detail_distance-12.0,detail_distance,distance(root,CAMERA_POSITION_WORLD));
 VERTEX*=fade;
 float wave=sin(TIME*1.1+root.x*.72+root.z*.31);
 VERTEX.x+=wave*.035*UV.y*UV.y*fade;
}
void fragment(){ALBEDO=COLOR.rgb*mix(.52,.97,blade_height);ROUGHNESS=1.0;}
