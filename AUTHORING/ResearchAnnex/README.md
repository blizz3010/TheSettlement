# Research Annex source preservation

The three original user-supplied final_b ZIPs are preserved byte-for-byte in
`source/`, with SHA-256 and size recorded in `SOURCE-ARCHIVES.json`. The models
archive contains the editable Blender file, assembled and far-LOD GLBs, eleven
modules, geometry reports and route data. The other archives contain 27 texture
maps and 18 official Blender renders/plans. No supplied scripts were executed.

Extract all three archives into the same separate authoring folder. Module image
URIs resolve to `../textures`; the assembled and far-LOD GLBs embed their maps.
The far LOD and preview landscape are not active game-world assets.

The runtime scene is a lossless Godot serialization of the assembled GLB via
Godot 4.6.3 GLTFDocument, with embedded uncompressed images. This avoids the editor
texture-import path that was terminated by the environment here; the cause was
not confirmed. No new `.godot` imports are needed.
Rebuild into a new output file with the included `tools/convert_research_annex.gd`
and an isolated development profile. The file refuses to overwrite existing
outputs. Verify geometry, material images and controller tests after any change.

Gameplay wrapper `raid/scripts/research_annex.gd` creates trimesh collision,
removes seven ordinary door leaves to leave public routes open, closes the
supplied Secure leaf before adding its lock collider, and connects the existing
raid keycard/cache state. All shell surfaces including glass remain physical.
These are candidate integration changes, not functionality supplied by the artist.

Source Blender renders are reference art, not screenshots from the game. Runtime
lighting, glass, texture appearance, performance and native Windows play remain
unverified. No license beyond the supplied project's existing ownership is granted.
