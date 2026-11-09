shader_type spatial;
render_mode cull_disabled;
// Original opaque vertex color. No ALPHA, texture lookup or new surface.
uniform float wind_strength : hint_range(0.0,1.0) = 1.0;
uniform float phase_offset = 0.0;
uniform float study_time = -1.0; // -1 = real shader TIME; >=0 deterministic capture only.
mat3 rot_x(float a) { float c=cos(a); float s=sin(a); return mat3(vec3(1,0,0),vec3(0,c,s),vec3(0,-s,c)); }
mat3 rot_z(float a) { float c=cos(a); float s=sin(a); return mat3(vec3(c,s,0),vec3(-s,c,0),vec3(0,0,1)); }
void vertex() {
  if (UV2.y > 0.5 && wind_strength > 0.0) {
    vec3 hinge=vec3(UV.x,UV.y,UV2.x);
    float t=study_time>=0.0 ? study_time : TIME;
    float phase=phase_offset + INSTANCE_CUSTOM.x + dot(hinge,vec3(1.71,0.37,1.13));
    float a=0.016*sin(t*1.15+phase)*wind_strength;
    float b=0.008*sin(t*1.73+phase*1.39)*wind_strength;
    mat3 bend=rot_z(a)*rot_x(b);
    VERTEX=hinge+bend*(VERTEX-hinge);
    NORMAL=bend*NORMAL;
  }
}
void fragment() { ALBEDO=COLOR.rgb; ROUGHNESS=0.86; }
