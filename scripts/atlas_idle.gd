extends RefCounted
## Private copy of the exact standing clip; only existing spine_03 rotation changes.
static func install(player:AnimationPlayer)->String:
 if not is_instance_valid(player) or not player.has_animation('Atlas_Standing') or player.has_animation_library('coverage_private'):return ''
 var original=player.get_animation('Atlas_Standing')
 var tracks=[]
 for track in range(original.get_track_count()):
  var path=original.track_get_path(track)
  var bone=String(path.get_subname(path.get_subname_count()-1)) if path.get_subname_count()>0 else ''
  if original.track_get_type(track)==Animation.TYPE_ROTATION_3D and bone=='spine_03':tracks.append(track)
 if tracks.size()!=1 or original.track_get_key_count(tracks[0])==0:return ''
 var value=original.track_get_key_value(tracks[0],0)
 if not value is Quaternion or not value.is_finite():return ''
 var base:Quaternion=value
 var clip:Animation=original.duplicate(true);clip.length=4.0;clip.loop_mode=Animation.LOOP_LINEAR
 var track:int=tracks[0]
 while clip.track_get_key_count(track)>0:clip.track_remove_key(track,0)
 for sample in [[0.0,0.0],[1.0,1.0],[2.0,0.0],[3.0,-1.0],[4.0,0.0]]:
  clip.rotation_track_insert_key(track,sample[0],base*Quaternion(Vector3.RIGHT,.004*sample[1]))
 var library=AnimationLibrary.new();library.resource_local_to_scene=true;clip.resource_local_to_scene=true
 if library.add_animation('quiet_idle',clip)!=OK:return ''
 if player.add_animation_library('coverage_private',library)!=OK:return ''
 return 'coverage_private/quiet_idle'
