shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// Rook-only quiet stone/plaster variant; other shops retain their existing shader. No texture downloads, displacement,
// screen sampling, animation or geometry changes. Fine detail is footprint filtered.
uniform int kind = 0; // timber, stone, plaster, metal, fabric, polished stone, ceramic
uniform int detail_quality = 2;
uniform vec4 tint : source_color = vec4(0.45,0.32,0.20,1.0);
uniform float roughness = 0.82;
uniform float metallic = 0.0;
varying vec3 local_position;
varying vec3 local_normal;
varying mat3 normal_to_view;
float hash31(vec3 p) {
 p=fract(p*0.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);
}
vec4 grain(vec3 x) {
 vec3 p=floor(x),f=fract(x),u=f*f*(3.0-2.0*f),du=6.0*f*(1.0-f);
 float a=hash31(p),b=hash31(p+vec3(1,0,0)),c=hash31(p+vec3(0,1,0)),d=hash31(p+vec3(1,1,0));
 float e=hash31(p+vec3(0,0,1)),f1=hash31(p+vec3(1,0,1)),g=hash31(p+vec3(0,1,1)),h=hash31(p+vec3(1,1,1));
 float k1=b-a,k2=c-a,k3=e-a,k4=a-b-c+d,k5=a-c-e+g,k6=a-b-e+f1,k7=-a+b+c-d+e-f1-g+h;
 return vec4(a+k1*u.x+k2*u.y+k3*u.z+k4*u.x*u.y+k5*u.y*u.z+k6*u.x*u.z+k7*u.x*u.y*u.z,
 du*vec3(k1+k4*u.y+k6*u.z+k7*u.y*u.z,k2+k4*u.x+k5*u.z+k7*u.x*u.z,k3+k5*u.y+k6*u.x+k7*u.x*u.y));
}
vec3 orient(vec3 p,vec3 axis) {
 if(axis.r>0.5) return p.yxz;
 if(axis.b>0.5) return p.xzy;
 return p;
}
float filtered(vec3 p) {return 1.0-smoothstep(0.20,0.85,max(length(dFdx(p)),length(dFdy(p))));}
void vertex() {local_position=VERTEX;local_normal=NORMAL;normal_to_view=MODELVIEW_NORMAL_MATRIX;}
void fragment() {
 vec3 p=local_position,n=normalize(local_normal),gradient=vec3(0.0);
 // Explicitly orient two-sided fabric normals because this shader overrides NORMAL.
 if(!FRONT_FACING) n=-n;
 vec3 base=tint.rgb;
 float r=roughness,m=metallic;
 // Medium uses only a broad surface. High adds restrained pores/fibres; Max
 // adds a second filtered grain scale and sharper material separation.
 if(kind==0) {
  vec3 q=orient(p,COLOR.rgb);
  vec4 broad=grain(q*vec3(5.5,0.62,5.5)+vec3(3.2,1.5,7.6));
  base*=1.0+(broad.x-0.5)*0.46;
  if(detail_quality>=2) {
   vec3 fp=q*vec3(92.0,2.2,92.0)+vec3(broad.x*3.0,0.0,broad.x*3.0);
   vec4 fine=grain(fp);float w=filtered(fp);
   base*=1.0+(fine.x-0.5)*0.24*w;
   gradient=orient(fine.yzw*vec3(1.0,0.035,1.0),COLOR.rgb)*0.09*w;
   r+=(fine.x-0.5)*0.10*w;
   if(detail_quality>=3) {
    vec3 micro=q*vec3(260.0,7.0,260.0);vec4 pores=grain(micro);float mw=filtered(micro);
    base*=1.0+(pores.x-0.5)*0.10*mw;
    gradient+=orient(pores.yzw*vec3(1.0,0.035,1.0),COLOR.rgb)*0.025*mw;
   }
  }
 } else if(kind==1 || kind==5) {
  vec4 cloud=grain(p*2.8+vec3(7.3,2.9,1.1));
  vec4 layers=grain(p*vec3(5.0,7.0,2.2)+vec3(cloud.x*3.4));
  base*=1.0+(cloud.x-0.5)*0.12+(layers.x-0.5)*0.06;
  if(detail_quality>=2) {
   float vein=1.0-smoothstep(0.018,0.065,abs(layers.x-0.51));
   base=mix(base,base*1.08,vein*0.20);
   vec3 fp=p*110.0;vec4 fine=grain(fp);float w=filtered(fp);
   base*=1.0+(fine.x-0.5)*0.11*w;
   gradient=fine.yzw*(kind==5 ? 0.025 : 0.075)*w;
   r+=(fine.x-0.5)*0.12*w;
   if(detail_quality>=3) {
    vec3 micro=p*255.0;vec4 pores=grain(micro);float mw=filtered(micro);
    gradient+=pores.yzw*0.025*mw;base*=1.0+(pores.x-0.5)*0.08*mw;
   }
  }
 } else if(kind==2) {
  vec4 broad=grain(p*8.0);base*=1.0+(broad.x-0.5)*0.055;
  if(detail_quality>=2) {
   vec3 fp=p*72.0;vec4 fine=grain(fp);float w=filtered(fp);
   gradient=(fine.yzw*0.045+ broad.yzw*0.025)*w;
   base*=1.0+(fine.x-0.5)*0.08*w;
  }
 } else if(kind==3) {
  vec4 wear=grain(p*12.0+vec3(4.8,3.2,6.1));
  float patina=smoothstep(0.55,0.83,wear.x)*0.22;
  base=mix(base,base*vec3(0.46,0.64,0.53),patina);
  r+=patina*0.20;
  if(detail_quality>=2) {
   vec3 fp=p*vec3(160.0,24.0,160.0);vec4 fine=grain(fp);float w=filtered(fp);
   base*=1.0+(fine.x-0.5)*0.10*w;r+=(fine.x-0.5)*0.13*w;
   gradient=fine.yzw*0.025*w;
  }
 } else if(kind==6) {
  vec4 glaze=grain(p*24.0+vec3(1.7,4.6,8.2));base*=1.0+(glaze.x-0.5)*0.08;
  r+=(glaze.x-0.5)*0.06;
  if(detail_quality>=2) {
   vec3 fp=p*125.0;vec4 pores=grain(fp);float w=filtered(fp);
   gradient=pores.yzw*0.012*w;
  }
 } else {
  vec4 broad=grain(p*9.0);base*=1.0+(broad.x-0.5)*0.10;
  if(detail_quality>=2) {
   vec3 wpos=p*210.0;float w=filtered(wpos);
   vec3 weave=sin(wpos*6.2831853);
   vec3 an=abs(n);float cross_weave=dot(weave,vec3(1.0)-an)*0.5;
   base*=1.0+cross_weave*0.09*w;
   gradient=cos(wpos*6.2831853)*0.04*w;
  }
 }
 gradient-=n*dot(n,gradient);
 NORMAL=normalize(normal_to_view*(n-gradient));
 ALBEDO=clamp(base,vec3(0.0),vec3(1.0));ROUGHNESS=clamp(r,0.35,0.97);METALLIC=m;
}
