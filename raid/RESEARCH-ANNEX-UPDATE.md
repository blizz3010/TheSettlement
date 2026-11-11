# Research Annex final_b integration candidate

The supplied two-storey architecture now replaces the old Research Annex blockout
in Relay Ridge. It is a separate source candidate, not a released Windows build.
The 28×24m building and 32×30m apron retain their original scale and orientation.
The public main entrance leads to the internal stair; the courtyard also has the
external stair. The 4.2m upper level contains the existing research keycard and the
locked secure research room. One existing raid cache is inside that room.

## Gameplay and collision

- Original `bunker` POI ID, location, radius, 4–5 loot-quality band and keycard
  state are unchanged. Public routes are now accessible before collecting the card.
- Seven ordinary door leaves are visibly removed. All frames, building surfaces,
  stairs, rails, props and window glass receive mesh collision.
- The Secure leaf ships posed 80° open. The wrapper closes it around its supplied
  hinge before creating the actual locked collider. Unlocking uses the existing
  raid logic and removes the leaf/collision, without claiming door animation.
- The card rests on the supplied upper-corridor pedestal outside Secure. The cache
  is inside Secure rather than at the artist's unrelated ground-lab loot marker.
- The apron is raised 4cm to avoid coplanar terrain. Existing terrain, trail routes,
  foliage, player controller, extraction, save logic and all other POIs are unchanged.
- No enemies, item drops, persistence, extra economy, door animation or multiplayer
  are added. Keys, unlocks and prototype quality rolls still reset on leaving.

## Source/import

All three original ZIPs, including editable Blender source, module GLBs, texture
maps and reference renders, are preserved under `AUTHORING/ResearchAnnex`.
Two isolated editor-import attempts were terminated by the environment. The
supported Godot GLTFDocument conversion succeeded and produced a self-contained
native scene, with no new `.godot` cache dependencies. A rebuild tool is included.

The asset test compares every mesh-array value, node transform, material property
and 44 decoded texture slots against a fresh read of the original GLB. The actual
GLB contains **15,406 triangles**, including 284 coping triangles. The supplier's
report says 15,410 and 288 respectively. The runtime matches the delivered GLB
exactly; no triangles were lost by conversion. Three plain materials intentionally
have no maps; the other eleven retain their maps at 512–2048px.

## Verification and limits

The dedicated test uses unchanged production `step_motion`, standing 1.8m × radius
0.32m capsule, actual integrated collision and real camera/raycast target selection.
Its visit starts once at the public trail forecourt, walks inside/upstairs, tests
the missing-card denial and physical gate, collects the card, unlocks and searches
the secure cache, rejects a repeat roll, then returns down the other stair.

Eight supplied routes are separately driven at 2.4, 4.2 and 7m/s, without jumps or
mid-route teleport/nudges. Independent starting positions are test setup. Waypoints
require <12cm horizontal and <24cm vertical error. At high speed the automated
driver can overshoot/reapproach waypoints; these tests establish reachability, not
human camera feel or a smooth sprint demonstration.

The narrow upper external doorway passed with about 2.210m minimum measured
foot-to-lintel clearance in these runs. The capsule traversal, not the upward
ray alone, verifies fit. This does not guarantee an arbitrary taller controller.
Closed-door capsule sweeps and both secure-room window panes are also checked.

See the candidate's final regression summary for aggregate results. These are
Linux headless physics/logic checks, not rendered visual or native-input acceptance.
No display is available here. Blender reference renders were inspected, but Godot
lighting/transmission/glass appearance, Windows controls, sound and performance
need a short rendered review in the next combined build. No new Windows package,
production-save acceptance or full-game regression is claimed by this change.
