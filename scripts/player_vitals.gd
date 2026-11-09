extends RefCounted
# Runtime prototype state only. No damage sources, healing, death, regeneration or save fields.
signal changed(current:float, maximum:float)
var _maximum:float=100.0
var _current:float=100.0
var maximum:float:
	get:return _maximum
var current:float:
	get:return _current
func set_values(current_value:Variant, maximum_value:Variant=100.0)->bool:
	for value in [current_value,maximum_value]:
		if not (value is int or value is float) or not is_finite(float(value)):return false
	if float(maximum_value)<=0:return false
	var next_max=float(maximum_value)
	var next_current=clampf(float(current_value),0,next_max)
	if _current==next_current and _maximum==next_max:return true
	_current=next_current;_maximum=next_max
	changed.emit(_current,_maximum)
	return true
