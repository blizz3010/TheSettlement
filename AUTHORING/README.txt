NPC source/provenance

The exact runtime GLBs under assets/npc_coverage are self-contained editable mesh, rig, material and animation sources. Import copies into Blender for further edits; preserve the originals. Importing a GLB does not recover original MPFB parametric controls. A new Blender round trip is a NEW candidate and must be compared/validated; do not assume byte identity.

Shared provisional Rook/west staff: the private original authoring .blend was re-exported byte-identically before acceptance. That file contains private executor path metadata and is deliberately not included. PROVENANCE.json records its hash and exact runtime GLB hash. The included GLB is sufficient to rebuild the game without Blender or MPFB installed. Both staff instances share the model asset but use independent skeleton/animation instances; their runtime fit is recorded in scripts/staff_fit.gd.

Atlas: the authoritative static-standing candidate is the runtime GLB, reconstructed exactly from the included immutable baseline GLB plus frozen static-deltas.json. Run:
  python3 AUTHORING/Atlas/exact-glb-review/replay_static_fit.py
Default is read-only verification. Add --output NEW_FILE.glb to create an independent file; existing files are refused. Historical divergent Blender files are not included or claimed to contain the accepted sleeve fit. Atlas has a static standing pose, not idle animation or final likeness approval.

CC0-ASSET-LICENSE.md is the official installed MPFB system-asset license. The MPFB Blender add-on itself is GPL; addon code is not bundled here. No new licensed texture downloads are required for this game project.

AUTHORING/.gdignore and the export exclusions keep these reproduction inputs out of runtime packages. Do not remove those exclusions merely to satisfy a guard check.
