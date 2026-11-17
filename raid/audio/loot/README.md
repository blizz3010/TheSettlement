# Raid loot cues (TASKS item 13)

Three original sounds, one per file, synthesized from code by `tools/loot_audio/make_loot_sounds.py` (deterministic; re-running reproduces the same bytes). Hashes are in SOURCE-PROVENANCE.json.

- `loot_cache_open.wav` (0.75 s): latch snap, hinge creak and lid thump when a supply cache is first searched. Positional at the cache.
- `loot_pickup.wav` (0.42 s): canvas rustle and parts rattle when loot goes into the raid haul.
- `loot_drop.wav` (0.38 s): dull bundle thud when an item is dropped from the haul.

Played by `raid/scripts/raid_loot/raid_loot_audio.gd` on the existing SFX bus at -16 dB (provisional). They are kept out of `raid_audio.gd` so its fourteen-cue contract is unchanged. Import metadata was generated in a separate minimal Godot 4.6.3 project so the settlement's pinned imports were not touched. This is not an audible mix approval; listen-test the levels in a playtest.
