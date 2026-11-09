// Optional pure sky helper: owner must integrate before clouds/stars, never replace cycle.
// One non-emissive-looking textured world-disc; no Geometry/Light, assets or shader TIME.
float rv_hash(vec2 p){return fract(sin(dot(p,vec2(73.17,291.31)))*17513.71);}
float rv_noise(vec2 p){
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(rv_hash(i),rv_hash(i+vec2(1,0)),f.x),mix(rv_hash(i+vec2(0,1)),rv_hash(i+vec2(1,1)),f.x),f.y);
}
float valley_body_mask(vec3 eye){
 vec3 axis=normalize(vec3(0.62,0.43,-0.65));
 float rr=(1.0-pow(dot(eye,axis),2.0))/(0.105*0.105);
 return (1.0-smoothstep(0.985,1.015,rr))*step(0.0,dot(eye,axis));
}
// Multiply star/meteor overlays by (1.0-valley_body_mask(EYEDIR)).
vec3 valley_celestials(vec3 eye, vec3 sky_color, float daylight, vec3 sun_direction){
 vec3 axis=normalize(vec3(0.62,0.43,-0.65));
 vec3 right=normalize(cross(axis,vec3(0,1,0)));
 vec3 up=cross(right,axis);
 vec2 q=vec2(dot(eye,right),dot(eye,up));
 float forward=step(0.0,dot(eye,axis));
 // Inclined fine orbital ring: behind body, lower contrast than dome ribs.
 vec2 tilt=mat2(vec2(0.88,0.475),vec2(-0.475,0.88))*q;
 float ellipse=length(tilt/vec2(0.245,0.067));
 float ring=(1.0-smoothstep(0.006,0.015,abs(ellipse-1.0)))*forward;
 vec3 ring_color=mix(vec3(0.12,0.15,0.20),vec3(0.73,0.69,0.58),daylight);
 vec3 result=mix(sky_color,ring_color,ring*mix(0.22,0.37,daylight));
 float radius=0.105;
 vec2 uv=q/radius;float rr=dot(uv,uv);
 float disc=(1.0-smoothstep(0.985,1.015,rr))*forward;
 vec3 normal=normalize(right*uv.x+up*uv.y-axis*sqrt(max(0.0,1.0-rr)));
 float lit=max(0.0,dot(normal,normalize(sun_direction)));
 float terrain=rv_noise(uv*4.7)+0.4*rv_noise(uv*13.0)+0.13*rv_noise(uv*31.0);
 vec3 body=mix(vec3(0.38,0.43,0.45),vec3(0.69,0.64,0.54),smoothstep(0.35,1.05,terrain));
 body*=mix(0.17,0.92,lit);
 // Atmospheric wash retains distant daytime disc; dark face stays subdued at night.
 body=mix(body,sky_color,mix(0.12,0.48,daylight));
 return mix(result,body,disc);
}
