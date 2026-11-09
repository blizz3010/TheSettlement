shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Original quiet wall finish. No normal perturbation or displacement.
// World-scaled local coordinates avoid stretching grain on batched unit cubes.
uniform vec4 tint : source_color = vec4(0.36,0.235,0.135,1.0);
varying vec3 p;
void vertex() {
 p=VERTEX*vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
}
void fragment() {
 float crossgrain=p.x+p.z;
 float grain=sin(crossgrain*63.0+sin(p.y*1.1+crossgrain*5.0)*0.55);
 float fade=1.0-smoothstep(0.15,0.65,max(length(dFdx(p*63.0)),length(dFdy(p*63.0))));
 float broad=sin(crossgrain*8.5+sin(p.y*.55)*.3);
 ALBEDO=tint.rgb*(1.0+broad*.045+grain*.025*fade);
 ROUGHNESS=.86;
 METALLIC=0.0;
}
