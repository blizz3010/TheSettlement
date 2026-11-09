extends RefCounted
# Both81-polygon arrays were captured and compared coordinate-by-coordinate.
# Only three cardinal-circle near-zero trig values differ by at most6.06e-20.
# Accept that exact full-array variant, not arbitrary numerical tolerances.
const CANONICAL='223b598613ef376d884c5ee62b5150aa234a27c057ef079652ff012000944ea7'
const WINDOWS='428baba7a92341ff88247cfa4bedfc82392630126e07d9f1e31889fff9bc9376'
static func digest(value:Array)->String:return var_to_bytes(value).hex_encode().sha256_text()
static func matches(current:Array,expected:Array)->bool:
 if current==expected:return true
 return digest(expected)==CANONICAL and digest(current)==WINDOWS
