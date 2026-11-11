extends RefCounted
## Test-process teardown only, never used by gameplay.
## With --fixed-fps, many simulated frames can pass before one real mixer period.
## Godot's audio server releases stopped playbacks asynchronously. Keep real
## playback enabled and let it drain before the test process exits.
static func drain(tree:SceneTree):
	await tree.process_frame
	OS.delay_msec(150)
	await tree.process_frame
