# Item 21: Town Hall "stall" (Ori's playtest blocker)

All captures: plain `--path .` launch, fresh XDG profile, Xvfb + llvmpipe (software GL),
1440x900, default High preset (MSAA 4x, sun shadows, grass High). Capture driver loaded
through a temporary override.cfg (never committed): raid/tests/town_hall_stall_driver.gd.

## Root cause
Not a hang: the main loop keeps running (watchdog never fired in-world). At the Town Hall
spawn every frame takes ~10 s on llvmpipe: 16.5M primitives / 5,267 draw calls per frame,
14.6M of them 130-triangle grass clumps (SettlementGroundGrassV086 near chunks, coverage and
garden beds). With 10 s frames, player.gd (pinned) loses input:
- movement is polled in _physics_process; a key pressed and released inside one frame is
  never seen (hold W 5 s -> 0.00 m moved),
- every queued mouse-motion event is applied at once, so a player nudging the mouse while
  waiting pins the camera at the -1.25 pitch clamp (the floor),
- Escape/close only take effect on the next drawn frame (10-22 s), and the window close
  button only opens a quit prompt that needs another click.

## Before / after (spawn, hall rear, plaza)
| view | before prims / draws / frame | grass hidden entirely | after (this PR) |
|---|---|---|---|
| spawn | 16.54M / 5,267 / ~10 s | 4.77M / 5,222 / ~3.5-4 s | 11.03M / 5,257 / ~7.8 s |
| hall rear | 16.19M / 2,597 / ~9.4 s | 3.08M / 2,567 / ~2.9 s | 11.90M / 2,625 / ~8.6 s |
| plaza | 20.99M / 14,138 / ~12 s | 8.28M / 14,013 / ~4.4 s | 19.46M / 14,304 / ~11.6 s |

llvmpipe is the main factor: with no grass at all the spawn is still ~3.5-4 s per frame.
A real GPU draws 11-16M triangles, heavily but playably.

Input (symptoms run, same scripted events):
| | before | after |
|---|---|---|
| hold W for 5 s (wall clock) | 0.00 m | 0.36 m |
| quick W tap | 0.00 m | 0.36 m |
| 12 x 60 px mouse nudges | pitch -0.04 -> -1.25 (floor) | -0.04 -> -0.39 (capped per slow frame) |
| second window close while quit prompt is up | game keeps running | saves and quits |

## Files
- before_01_spawn_high_preset.png, before_02_camera_pinned_at_floor.png,
  before_03_quit_prompt_game_keeps_running.png
- grass_spawn_original.png / grass_spawn_culled.png, grass_plaza_original.png /
  grass_plaza_culled.png (same view, culling off/on; pixel diff < 0.3% of the frame)
- after_*.png: walking out of the hall, the pause menu with "Return to Town Hall entrance",
  and the result of pressing it.

After run (this PR, same launch): overlays, then counter -> exit -> plaza walk at ~8 s frames
(physics-capped, slow but every step lands), pause menu, Return to Town Hall entrance pressed
from the plaza -> `{ok: true, used: "entrance", position: (0, 0.27, -15.4)}`.
