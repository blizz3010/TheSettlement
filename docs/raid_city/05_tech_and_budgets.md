# 5. Godot tech: terrain, streaming, LOD, water, budgets

[Index](../raid_city_design.md) · prev: [4. Systems](04_systems_integration.md) · next: [6. Assets](06_assets.md)

Facts this section builds on:

- The engine is **Godot 4.6.3** (`tools/pinned-r8-runtime.json` `engine_version`).
- The renderer is **Compatibility (OpenGL 3.3 / GLES3)** (`project.godot`: `renderer/rendering_method="gl_compatibility"`, MSAA 2×).
- The raid maps are generated **384 m squares in 32 m chunks with trimesh collision** (`raid/scripts/relay_config.gd`, `raid/scripts/relay_generator.gd`).
- Grass has already been the worst bottleneck once. The Town Hall stall was ~16.5M primitives per frame, ~14.6M of them grass clumps; it was fixed by `raid/scripts/grass_view_culling.gd`.

## 5.1 Terrain options (honest comparison)

Godot 4 has **no built-in terrain node**. "Built-in heightmap" means building our own chunked meshes from a heightmap image,
with `HeightMapShape3D` collision. The project already does a version of this per raid map.

| | A. Own heightmap chunks (extend `relay_generator.gd`) | B. Terrain3D plugin (GDExtension, C++) | C. Static meshes from Blender (Artie) |
|---|---|---|---|
| What it is | 16-bit heightmap → per-chunk `ArrayMesh` with baked LODs + `HeightMapShape3D` | Geometry-clipmap terrain, up to 65.5 km, sculpt/paint in the editor, built-in foliage instancer | Hand-built terrain tiles exported as glb |
| Version / renderer fit | Ours; works in Compatibility today | **v1.1.0 (Oct 30 2026) supports Godot 4.5–4.8 and fully supports Compatibility** (since 1.0 / Godot 4.4). The planned **2.x moves to a GPU-driven workflow and drops Compatibility**, so we'd pin 1.x | Any |
| Streaming | We write it (region tiles of 256 m) | Region-based data files; loads all regions in use, no true async streaming of terrain data at 24 km² scale (verify in the spike) | We write it |
| Collision | `HeightMapShape3D` per tile (cheap) instead of today's trimesh | Built in; generated around the camera / dynamic | Trimesh (expensive) or simplified |
| Editing | External (World Machine / Gaea / Blender → heightmap); slow iteration | **Best**: in-editor sculpt, paint, holes for tunnels | Artie in Blender; good for hero spots only |
| Risks | Engineering time; seams and LOD cracks | Native binaries per platform; must pass our import/pinning policy (`vendor/`, manifests, C16); upstream changes | Huge files; hard to change roads |
| Cost on low-end | Predictable | Generally good (clipmap); the shader is heavier than a plain mesh on Intel iGPUs (measure) | Depends on tri counts |

**Recommendation:**

- **Phase 1 (one city district)** barely needs terrain. The city is flat streets, a river cut and embankments.
  Use **option A** (extend our generator with `HeightMapShape3D`) plus modular street meshes. That avoids adding a native plugin before we have to.
- **Phase 0 spike:** run Terrain3D 1.1 on the minimum-spec machine with a 4 × 6 km test heightmap, and compare it with option A on frame time, memory and load time.
  Decide before Phase 4 (region).
- If we adopt Terrain3D, **pin 1.1.x**. Terrain3D 2.x won't run in Compatibility.

## 5.2 Streaming and chunks

- **Grid:** 256 m region tiles (24 km² → 16 × 24 = 384 tiles) for terrain and foliage. The city uses **128 m blocks** for buildings and props.
- **Rings:** around the player (or vehicle, looking ahead along its velocity):
  - **Near (≤ 256 m):** full detail and physics.
  - **Mid (256–800 m):** LOD1/LOD2, no physics except terrain.
  - **Far (800 m+):** impostors, terrain LOD, landmark impostor.
- **Loading:**
  - Use `ResourceLoader.load_threaded_request` for tile scenes, with a per-frame instantiation budget (≤ 2 ms per frame, like the existing budgeted coroutine path in `scripts/settlement_stream.gd`).
  - Look-ahead scales with speed: at 45 m/s, preload 2 tiles ahead.
  - Flying cars at 70 m/s need the far ring as impostors, plus a speed limit in the upper lane while tiles load.
- **Heist sites are "anchored":** the bank interior, vault and grocery back room load as **sub-scenes when you get within 120 m**. Detail is concentrated there; the rest of the city stays modular and cheap.
- **Floating origin:** not needed at 4 × 6 km (see §2.2).

## 5.3 LOD, impostors, occlusion

- **Mesh LOD:**
  - Auto LOD (meshoptimizer on import) works with any renderer, including Compatibility.
  - Use it for props. For hero assets use Artie's hand LODs (LOD0/1/2 like the P2 handoffs), with `generate_lods` turned off on import.
- **Visibility ranges (HLOD):** buildings switch to merged block meshes at 300 m and to **block impostors** (octahedral or 8-view billboards) at 800 m.
  Towers and the statue get their own impostors.
- **Occlusion culling:** `OccluderInstance3D` with baked box occluders per building. It works in all renderers (CPU, Embree) and helps a lot in streets.
  Turn on `rendering/occlusion_culling/use_occlusion_culling`.
- **Draw calls are the Compatibility renderer's weak point:**
  - Merge static facades per block.
  - Use texture atlases and trim sheets (the street kit).
  - Use MultiMesh for repeated props (lamps, signs, parked cars, trees).

## 5.4 Water and waterfall

- **River and park lake:** extend the Settlement lake shader (`shaders/inn_lake_v088.gdshader`, `shaders/lake_bank_v089.gdshader`).
  Use scrolling normal maps, depth tint from a baked depth texture (no screen-depth read), a fresnel reflection of a `ReflectionProbe` / sky, and shore foam from a mask.
- **Waterfall:** a ribbon mesh with scrolling UVs and a foam mask, an emissive-free spray card, GPU particles for mist, and a pool from the lake shader.
  There's a cave behind it: the waterfall mesh needs a hole the player can walk through, with no collider on the water.
- **Wet neon streets** (`street_view.jpg`): Compatibility has no SSR.
  Use a puddle mask (lower roughness), per-block `ReflectionProbe`s, and emissive signs with a small glow (Compatibility supports glow since 4.3).

## 5.5 Foliage budget

Lessons from the Settlement:

- Grass clumps must be culled per view (`grass_view_culling.gd`).
- Quality tiers must change density and distance (`scripts/options_panel.gd` `grass_quality`, `scenery_quality`).
- Distant trees are cheap as MultiMesh batches (item 9's dense treeline: 2,100 instances, 86,634 tris, 2 batches).

| Area | Low | Medium | High |
|---|---|---|---|
| Grass instances visible | 40k, ≤ 35 m | 120k, ≤ 55 m | 250k, ≤ 80 m |
| Trees, full mesh | ≤ 60 within 120 m | ≤ 150 within 200 m | ≤ 300 within 300 m |
| Tree impostors / cards | to 600 m | to 1,000 m | to 1,500 m |
| City Park | grass 30k, 40 trees | 80k, 90 trees | 150k, 160 trees |
| Waterfall forest | grass 40k, 80 trees + cards | 100k, 160 | 200k, 260 |

## 5.6 Budgets for low-end hardware

**Minimum spec target:** GTX 950 / RX 460 / Intel Iris Xe class, 4-core CPU, 8 GB RAM, 1080p at 30 fps on Low (720p render scale allowed), 60 fps on Medium for mid-range.
Measure it on real hardware. The box's llvmpipe numbers are relative only.

| Budget (per frame, in the city) | Low | Medium | High |
|---|---|---|---|
| Draw calls | ≤ 900 | ≤ 1,500 | ≤ 2,500 |
| Visible triangles | ≤ 1.2M | ≤ 2.5M | ≤ 4M |
| Dynamic lights with shadows | 1 sun + 2 | 1 + 4 | 1 + 8 |
| Shadow distance | 60 m | 120 m | 200 m |
| Traffic cars (kinematic) | 20 | 40 | 70 |
| Cars as physics bodies | 4 | 8 | 12 |
| Pedestrians (animated) | 20 | 45 | 80 |
| Police AI active | 6 | 10 | 16 |
| Flying cars on lanes | 4 | 10 | 18 |
| Script time (AI + traffic) | ≤ 4 ms | ≤ 5 ms | ≤ 6 ms |
| Physics step | ≤ 3 ms | ≤ 4 ms | ≤ 5 ms |
| RAM / VRAM | ≤ 3 GB / ≤ 1.5 GB | ≤ 4 GB / ≤ 2.5 GB | ≤ 6 GB / ≤ 4 GB |
| Load into raid | ≤ 25 s HDD | ≤ 15 s SSD | — |

Animated pedestrians are the big unknown in Compatibility, because skinning is on the CPU in some paths.
Plan **3 animation LODs**: full skeleton ≤ 25 m, reduced bones ≤ 60 m, and vertex-animated or billboard crowds beyond that.

**Asset poly budgets** (mid-to-high poly, as the P2/E1 work):

| Asset | LOD0 | LOD1 | LOD2 / impostor |
|---|---|---|---|
| Hero building (bank) exterior | 120–180k | 40k | 6k / impostor |
| Bank interior + vault (streamed) | 150k | 50k | — |
| Grocery store (with interior) | 60–90k | 25k | 4k |
| ATM | 4–6k | 1.5k | — |
| Bridge (per 50 m span) | 40–60k | 15k | 3k |
| City block facade set | 30–50k / building | 10k | block impostor |
| Player vehicle | 40–70k | 15k | 4k |
| Traffic vehicle | 15–25k | 6k | 1.5k |
| Pedestrian / police | 12–18k (like gear budgets, 12–18k in `gear_defs.gd` ART rows) | 6k | 1.5k |
| Statue landmark | 60k | 15k | 2k / impostor |
