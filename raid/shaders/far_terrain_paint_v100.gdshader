shader_type spatial;
render_mode cull_disabled;
// TASKS item 9 far-scenery paint. Keeps the finished southern v094 sector
// intact (south_protect). paint_full covers every other azimuth; otherwise
// the original east-sector cone is used. lake_cut keeps the original lake
// ellipse discard unless PR #5 has already reshaped MiddleRidge.
uniform int terrain_band = 0;
uniform vec4 original_tint : source_color = vec4(1.0);
uniform bool lake_cut = true;
uniform bool paint_full = true;
uniform bool south_protect = true;
uniform vec2 paint_dir = vec2(1.0, 0.0);
uniform float paint_cos_full = 0.87;
uniform float paint_cos_edge = 0.70;
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
vec3 v094_ground(float broad, float grain, float ridges, float slope){
 vec3 forest=mix(vec3(.055,.09,.063),vec3(.12,.17,.105),broad);
 forest*=.88+grain*.20;
 vec3 rock=mix(vec3(.18,.205,.19),vec3(.31,.34,.29),broad*.82+ridges*.18);
 float exposed=smoothstep(.15,.48,slope)*.82+smoothstep(.69,.88,broad)*.6;
 return mix(forest,rock,clamp(exposed,0.0,1.0));
}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;wn=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
 if(lake_cut && length((wp.xz-vec2(20.0,130.0))/vec2(100.0,75.0))<1.0){discard;}
 float radius=length(wp.xz);
 vec2 dir=normalize(wp.xz+vec2(1e-5,0.0));
 float north=dot(dir,vec2(0.0,-1.0));
 float w_south=smoothstep(0.6156614753,0.7660444431,north)*smoothstep(70.0,84.0,radius);
 float w_az=paint_full?1.0:smoothstep(paint_cos_edge,paint_cos_full,dot(dir,normalize(paint_dir)));
 float w_paint=w_az*smoothstep(58.0,74.0,radius);
 if(south_protect){w_paint*=1.0-w_south;}
 vec3 base=COLOR.rgb*original_tint.rgb;
 float broad=noise(wp.xz*.026)*.65+noise(wp.xz*.071)*.35;
 float grain=noise(wp.xz*.42);
 float ridges=noise(wp.xz*.041+vec2(wp.y*.075,-wp.y*.05));
 float slope=1.0-abs(wn.y);
 vec3 col=base;
 if(w_south>0.0){
  vec3 g=v094_ground(broad,grain,ridges,slope);
  if(terrain_band==2){
   g=mix(vec3(.21,.29,.34),vec3(.39,.445,.46),broad*.82+ridges*.18);
   float snow=smoothstep(99.0,141.0,wp.y+noise(wp.xz*.047)*20.0-ridges*12.0)*(1.0-smoothstep(.45,.83,slope));
   g=mix(g,vec3(.66,.72,.74),snow*.8);
  }
  g=mix(g,vec3(.34,.43,.49),smoothstep(130.0,780.0,radius)*.64);
  col=mix(col,g,w_south);
 }
 if(w_paint>0.0){
  if(terrain_band>=2){
   vec3 g=mix(vec3(.22,.28,.32),vec3(.40,.45,.46),broad*.75+ridges*.25);
   float snow=smoothstep(90.0,150.0,wp.y+noise(wp.xz*.047)*22.0-ridges*12.0)*(1.0-smoothstep(.42,.82,slope));
   g=mix(g,vec3(.70,.74,.76),snow*.85);
   g=mix(g,vec3(.48,.58,.64),smoothstep(280.0,860.0,radius)*.70);
   col=mix(col,g,w_paint);
  }else{
   float patch=noise(wp.xz*.018+3.1)*.6+noise(wp.xz*.055-1.7)*.4;
   vec3 meadow=mix(vec3(.20,.29,.13),vec3(.31,.38,.17),grain*.6+broad*.4);
   vec3 woods=mix(vec3(.07,.12,.075),vec3(.13,.19,.10),broad);
   vec3 g=mix(meadow,woods,smoothstep(.42,.62,patch));
   float band=sin(wp.y*.55+noise(wp.xz*.03)*6.0)*.5+.5;
   vec3 dirt=mix(vec3(.30,.25,.16),vec3(.38,.32,.21),grain);
   g=mix(g,dirt,smoothstep(.80,.97,band)*smoothstep(.12,.35,slope)*.65);
   vec3 rock=mix(vec3(.30,.31,.28),vec3(.45,.45,.40),broad*.7+ridges*.3);
   float exposed=smoothstep(.38,.62,slope+ridges*.18)+smoothstep(28.0,46.0,wp.y+ridges*10.0)*.55;
   g=mix(g,rock,clamp(exposed,0.0,1.0));
   if(terrain_band==1){
    g=mix(g,mix(vec3(.17,.24,.20),vec3(.28,.33,.30),broad),.45);
    g=mix(g,vec3(.40,.50,.56),smoothstep(200.0,620.0,radius)*.58);
   }else if(terrain_band==3){
    // Scenic apron: calmer grass so the ridge-foot seam settles.
    g=mix(meadow,woods,smoothstep(.50,.78,patch)*.45);
    g=mix(g,dirt,smoothstep(.85,.98,band)*.2);
   }else{
    g=mix(g,vec3(.42,.52,.58),smoothstep(110.0,520.0,radius)*.62);
   }
   col=mix(col,g,w_paint);
  }
 }
 ALBEDO=col;ROUGHNESS=1.0;SPECULAR=.5*(1.0-max(w_south,w_paint));
}
