# Headset threat cues (TASKS item 22, PR B)

Four original sounds, one per file, synthesized from code by `tools/gear_audio/make_threat_sounds.py` (deterministic; re-running reproduces the same bytes). Hashes are in SOURCE-PROVENANCE.json.

- `turret_servo_whine.wav` (0.70 s): sentry turret head acquiring a target.
- `turret_warmup_tone.wav` (0.90 s): rising charge, matches the turret's 0.9 s warmup.
- `turret_shot.wav` (0.45 s): turret discharge.
- `live_cable_crackle.wav` (1.00 s): shorted live cable, repeated while in hearing range.

They only play when a tiered **headset** is equipped (raid/scripts/gear_tiers/raid_gear.gd). With no headset the raid is silent for these threats, exactly as before. Hearing range scales with the headset tier. The cues go through a runtime `GearThreat` bus with a compressor whose strength scales with the tier; the bus is removed when the raid ends. Import metadata was generated in a separate minimal Godot 4.6.3 project so the settlement's pinned imports were not touched. This is not an audible mix approval; listen-test the levels in a playtest.
