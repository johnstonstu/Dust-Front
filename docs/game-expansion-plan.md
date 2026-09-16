# Dust Front — Game Expansion Plan

**Project:** Apache / Dust Front (repo: `johnstonstu/Dust-Front`)  
**Constraint:** No Higgsfield MCP `generate_*` or paid media. Prefer free/local assets, code, SVG/CSS-style UI drawing, procedural geometry/textures, and existing repo art.  
**Date:** 2026-09-16

---

## What the game is today

**Stack:** Godot 4 (Compatibility / `gl_compatibility` renderer), GDScript, single main scene (`main.tscn` → `game.gd`).

**Structure:**
| Area | Files / role |
|------|----------------|
| Core loop | `game.gd` — flight, combat, waves, pause, smoke/capture modes |
| Campaign data | `campaign.gd` — 3 missions, loadouts, upgrades, save (`user://campaign.cfg`) |
| World | `arena.gd` + `terrain.gdshader` — procedural 2.6 km biomes (desert / alpine / volcanic) |
| UI | `start_menu.gd`, `hangar_ui.gd`, `flight_hud.gd`, `radar.gd`, `victory_screen.gd` |
| Audio | `combat_audio.gd` + Kenney CC0 / aquinn CC0 / original synth cues |
| Art | Higgsfield Apache GLB (existing; do not regenerate), procedural terrain maps, prototype enemy meshes |

**Playable loop today:**
1. Start menu → hangar (missions / loadout / upgrades / audio / flight feel).
2. Launch a theater: 3 waves of drones + ace cadence; clear waves for hull/ammo resupply.
3. Finish mission → victory screen, unlock next theater, earn credits/XP.
4. After any clear: endless mode in that theater (cap 22 enemies, scaled HP).
5. Fail: keep XP/credits, return hangar.

**Known prototype gaps (from README):** decorative outposts have no damage; enemies are placeholder geometry; streak counter is visual-only; no ground threats; campaign is 3 theaters only.

---

## Goals for this expansion (one pass)

Ship a **coherent “operations expansion”** that deepens the sortie fantasy without new paid art:

1. **Fourth theater — 04 / NIGHT OASIS** — night desert biome (procedural sky, oasis water, cooler lighting, reuse sand/metal textures).
2. **Hardpoints (ground targets)** — destroyable radar/fuel sites near the pad; required for wave clear alongside air contacts; HUD markers.
3. **New enemy — SAM pad** — ground AA that tracks and fires; forces altitude awareness.
4. **Pickups** — hull repair / missile crates from some kills (procedural meshes + existing reward SFX).
5. **Streak payoffs** — kill streaks grant real ammo/credits/hull at thresholds (3 / 5 / 8).
6. **Desert sandstorm pulse** — short fog + dust particle bursts on desert/oasis (code-only weather).
7. **Progression wiring** — hangar, start menu, save clamp, victory, HUD, and smoke tests updated for 4 missions + new combat systems.

**Out of scope this pass:** multiplayer, new helicopter model, Higgsfield radio re-recording, standalone export packaging, full physics collision for every prop.

---

## What will change

### Systems
- `campaign.gd` — mission 4, unlock cap 4, SAM kill rewards, save/load clamps.
- `arena.gd` — biome index 3 (night oasis): sky/sun/fog, oasis water plane, hardpoint spawn markers; expose hardpoint build helpers.
- `game.gd` — hardpoints array + damage; SAM spawn/AI; pickups; streak rewards; sandstorm timer; wave-clear gated on hardpoints; mission index clamps; smoke assertions.
- `hangar_ui.gd` / `start_menu.gd` / `flight_hud.gd` / `victory_screen.gd` — 4-mission UI and objective copy.
- `radar.gd` — optional hardpoint blips (ground contacts).

### Content
- Mission brief + reward for Night Oasis.
- Per-wave hardpoint spawns (1–3 sites).
- SAM units mixed into later waves / mission 3–4 and endless.

### UX
- Objective line mentions hardpoints when present.
- Hangar mission list shows 4 operations.
- Streak toast text when bonuses fire.

### Art approach (free only)
- **Reuse:** existing sand/rock/metal/ash textures, Kenney/aquinn audio, Apache GLB already in repo.
- **Procedural:** oasis water material (emission + transparency), night sky colors, SAM/hardpoint/pickup meshes via `BoxMesh`/`CylinderMesh`/`SphereMesh`, sandstorm via fog density + `puff()` dust.
- **UI:** continue `_draw()` HUD language (no new image packs).
- **No** Higgsfield image/video/audio/3D generation.

---

## Needs and blockers

| Need | Status |
|------|--------|
| Godot CLI for `--smoke-test` | **Not installed** in this VM; download official Linux x86_64 binary (4.3+ / 4.4.x) for verification |
| New paid/media APIs | **None** — blocked by project rule; not used |
| Extra CC0 packs | Optional; not required if procedural + existing audio suffice |
| Higgsfield Apache terms | Existing model stays as-is; no regeneration |

**Blocker risk:** If Godot cannot be installed/run headless, code still ships with expanded smoke assertions; document manual F5 check as follow-up.

---

## Ordered implementation steps

1. Write this plan; confirm path exists (Phase 1 gate).
2. Create feature branch `cursor/dust-front-ops-expansion-4073`.
3. Extend `campaign.gd` (mission 4, rewards, unlocks, SAM rewards).
4. Extend `arena.gd` for night oasis + hardpoint prop helpers.
5. Implement hardpoints, SAMs, pickups, streaks, sandstorm in `game.gd`.
6. Update hangar / start menu / HUD / radar / victory for 4 ops + new objectives.
7. Expand `run_smoke_test()` for new systems; keep prior asserts green.
8. Install Godot if possible; run `--headless --path . -- --smoke-test`.
9. Light README / ASSET_CREDITS note (procedural oasis; no new paid media).
10. Commit, push, open **draft** PR summarizing this plan.

---

## How we’ll verify

1. **Automated:** `godot --headless --path . -- --smoke-test`  
   Expect print `SMOKE PASS: ...` including new hardpoint/SAM/pickup/streak/mission-4 checks.
2. **Build sanity:** project opens without parse errors (headless boot).
3. **Play checklist (manual / capture if display available):**
   - Start menu shows 4th op when unlocked.
   - Night Oasis loads dark sky + water.
   - Destroy hardpoints to clear a wave; SAM fires from ground.
   - Streak at 3+ shows credit/ammo toast; pickups restore hull/ammo.
   - Desert/oasis briefly thickens fog during sandstorm pulse.
4. **Regression:** endless cap, victory no double-reward, save/load, pause center.

### Verification results (2026-09-16)

- Installed Godot **4.4.1** locally in the agent VM (`~/bin/godot`).
- Headless smoke: **PASS** (`SMOKE PASS: combat, hardpoints, SAM, pickups, streaks, sandstorm, ...`).
- Draft PR: https://github.com/johnstonstu/Dust-Front/pull/1
- No Higgsfield tools used for this expansion.

---

## Success criteria

- Meaningful gameplay depth beyond tweaks (new theater + ground war layer + rewards).
- Coherent with existing desert-ops tone and HUD language.
- Zero Higgsfield generation calls for this expansion.
- Draft PR opened with plan highlights in the body.
)
