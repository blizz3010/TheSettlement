shader_type sky;
// Original static broken banks and restrained thin wisps. No weather/time/planet.
uniform vec3 zenith : source_color = vec3(0.24,0.40,0.58);
uniform vec3 horizon : source_color = vec3(0.76,0.77,0.73);
float hash21(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float clouds(vec2 p) {
 float n=0.0; float amplitude=0.57;
 for(int i=0;i<4;i++){ n+=noise2(p)*amplitude; p=mat2(vec2(1.65,1.2),vec2(-1.2,1.65))*p+7.1; amplitude*=0.46; }
 return n;
}
void sky() {
 float y=max(EYEDIR.y,0.0);
 vec3 base=mix(horizon,zenith,pow(y,0.52));
 vec2 p=EYEDIR.xz/(0.36+y)*5.2;
 float n=clouds(p*vec2(0.8,1.4));
 // Less coverage, smaller banks, sharper but antialiased edges.
 float mask=smoothstep(0.58,0.73,n)*smoothstep(0.02,0.13,y);
 mask*=1.0-smoothstep(0.65,0.98,y)*0.60;
 float w=noise2(p*vec2(0.55,5.0)+vec2(33.0,12.0));
 float wisps=smoothstep(0.73,0.92,w)*smoothstep(0.12,0.3,y)*(1.0-smoothstep(0.65,0.9,y))*0.18;
 vec3 cloud=mix(vec3(0.70,0.75,0.79),vec3(0.91,0.89,0.82),smoothstep(0.56,0.79,n));
 COLOR=mix(base,cloud,min(mask*0.85+wisps,0.9));
}
