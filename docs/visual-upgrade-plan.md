# Dust Front — Visual Upgrade Plan

**Repo:** `johnstonstu/Dust-Front`  
**Base:** `cursor/dust-front-ops-expansion-4073` (PR #1) → follow-up branch for visuals  
**Constraint:** No Higgsfield `generate_*`. Free / local / procedural / in-repo CC0 only.  
**Renderer:** Godot 4 `gl_compatibility` — keep upgrades compatible (no Forward+ volumetrics).

---

## Current stack (brief)

| Layer | Today |
|-------|--------|
| Terrain | `terrain.gdshader` — sand/snow/ash + rock mix by slope; oasis tint only |
| Lighting | Procedural sky + one `DirectionalLight3D`; night biome adds a moon Omni |
| Materials | Flat `StandardMaterial3D` helpers; metal/sand textures on outposts & enemies |
| Enemies / hardpoints | Prototype boxes/cylinders; red lens dots; hardpoint orange Omni |
| VFX | Sphere `puff()`, torus shock `burst()`, simple gun flash sphere + Omni |
| UI | `_draw()` HUD / radar / menus — mint/amber ops language |

**Gaps:** flat lighting read, weak muzzle/explosion pop, enemies blend into desert, water is a static cylinder, HUD hardpoints under-emphasized, sandstorm is fog-only.

---

## Pass goals (one coherent desert/ops look)

1. **Atmosphere** — warmer desert / cooler alpine / ember volcanic / deeper night oasis; fog color energy + sky contrast; sandstorm tint + denser dust billows.
2. **Terrain materials** — macro dune variation, rock normal depth, biome grading in shader (no new textures).
3. **Water / oasis** — fresnel-ish transparency, pulse emission, shore foam ring (procedural mesh).
4. **VFX** — elongated muzzle flash + spark puffs; multi-layer explosions (core / fire / smoke); ground sand kick richer near rotor.
5. **Readability** — enemy accent panels + team emission; SAM danger beacon; hardpoint chevron rings / strobe lights.
6. **HUD** — hardpoint world markers, streak strip, sandstorm edge vignette; keep mint/amber ops palette.

**Out of scope:** new GLB/heli, paid packs, Higgsfield, gameplay balance rewrites.

---

## Files to touch

- `terrain.gdshader` — dune macro, biome grading, subtle heat haze albedo
- `arena.gd` — env/sun/fog polish, oasis water + foam, rock normals, outpost accents
- `game.gd` — VFX (muzzle/burst/puff/sand), enemy/SAM/hardpoint materials & lights, sandstorm tint
- `flight_hud.gd` / `radar.gd` — hardpoint/streak/sandstorm readability
- Optional tiny shaders: `water.gdshader`, `fx_unlit.gdshader` if StandardMaterial limits hit

---

## Verify

```bash
godot --headless --path . -- --smoke-test
```

Expect `SMOKE PASS`. Gameplay systems unchanged; visuals only.
