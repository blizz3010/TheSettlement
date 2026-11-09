extends RefCounted
## Option one only: bounded landscape layering. No path/door/building changes.
## Compact supports; coefficients are metres, x/z are world-space metres.
const EXTRA_RESERVES = [
 Rect2(-10,32.5,8,7), Rect2(6,34.5,8,7), # Future sites A/B; Rook C already protected.
 Rect2(-22,-10,16,16), # Original plot/trader exclusion retained as unused ground.
 Rect2(-32.5,6.5,17,17), Rect2(-16.5,12.8,9,4.4),
 Rect2(-16.5,17.5,4,5), Rect2(-10,6,7,11) # Full Home reservation envelopes.
]
static func affects(p:Vector2)->bool:
 # Whole-cell conservative supports include the analytic zero boundary.
 return Rect2(-38,-30,20,20).has_point(p) or Rect2(33,15,19,20).has_point(p)
static func bump(p:Vector2,center:Vector2,radius:float)->float:
 return 1.0-smoothstep(0.0,radius,p.distance_to(center))
static func interval(v:float,start:float,finish:float,feather:float)->float:
 return smoothstep(start,start+feather,v)*(1.0-smoothstep(finish-feather,finish,v))
static func delta(p:Vector2,legacy_mask:float)->float:
 if legacy_mask<=0:return 0.0
 var extra=1.0
 for r in EXTRA_RESERVES:
  var nearest=Vector2(clampf(p.x,r.position.x,r.end.x),clampf(p.y,r.position.y,r.end.y))
  extra=minf(extra,smoothstep(0.0,3.0,p.distance_to(nearest)))
 # Two broad shoulders; the west hollow is genuinely below its old raised surface.
 var west=.58*bump(p,Vector2(-28,-20),9.0)-.70*bump(p,Vector2(-31,-20),4.5)
 var east=.64*bump(p,Vector2(42,25),8.0)
 # Soft, planted terrace transition; never a required walking step.
 var terrace=.28*interval(p.x,38.0,46.0,2.8)*interval(p.y,16.0,27.0,3.0)
 return (west+east+terrace)*legacy_mask*extra*(1.0-smoothstep(49.0,52.0,p.length()))
static func stone_face(_p:Vector2)->bool:
 # Native review rejected the angular painted-stone patch. Keep planted relief.
 return false
