# Audio and texture credits

## Commander radio

- Generated with Higgsfield Seed Audio, Grady preset voice, for this project; subject to Higgsfield's applicable terms (not the CC0 effects license).
- Alpine job: `132d9051-aafd-4148-828a-aaf1a52bd73f`; volcanic: `f7d0df55-5d99-4a41-b882-35cf2d04c6ad`; completion: `5e31b3c4-a17a-4b05-ac53-e97f5c749852`.
- Original briefing/wave jobs: `7a68eb2b-ff50-41ec-8d57-cfc9d4d8e917`, `6569a357-9a79-4a88-82c5-8360be739061`.
- New source WAVs retained in `assets/audio/source/`; radio edits apply a 350–3400 Hz band, compression and loudness normalization. Rebuild with `bash tools/prepare_radio.sh`.

## Helicopter

- **Helicopter Sounds**, by **aquinn**, OpenGameArt, CC0.
- Source page: https://opengameart.org/content/helicopter-sounds
- Source download: https://opengameart.org/sites/default/files/helicopter_0.mp3
- Local original: `assets/audio/source/helicopter-aquinn.mp3`.
- Used as `rotor_loop.wav`: a steady segment was cropped, normalized, and crossfaded for looping. Pitch and volume respond to flight speed.

## Combat sounds

- **Sci-fi Sounds**, by **Kenney**, CC0.
- Source page: https://kenney.nl/assets/sci-fi-sounds
- Original archive retained under `assets/audio/source/kenney-sci-fi.zip`.
- The supplied license is preserved in `assets/audio/KENNEY-LICENSE.txt`.
- Uses explosionCrunch, lowFrequency_explosion, impactMetal, laserSmall, laserLarge, and thrusterFire samples for explosions, impacts, enemy weapons, and rocket launches.
- Cannon sound layers the first prototype's original synthesized transient with Kenney's metallic impact sample. Rocket launch is normalized from thrusterFire. Playback adds mild pitch variation and distance attenuation.

## Original assets

- Victory music: original 12-second synth/brass cue, synthesized without external samples by `tools/compose_victory.py`.

- Menu theme: original 32-bar electronic instrumental, 108 BPM, composed and synthesized for Dust Front without third-party samples. Rebuild the 71.1-second stereo loop with `python3 tools/compose_theme.py`.

- Lock, warning, reward, and menu cues were synthesized for this game.
- Sand, rock, snow, ash, and metal albedo/normal/roughness textures were generated procedurally for this game. `tools/prepare_assets.py` reproduces these maps and audio edits from the retained inputs.
- Helicopter source: user-requested Higgsfield 3D Jutsu project `9f7e8324-73ed-45d1-8757-75747407a3b6`, revision 3. The helicopter remains subject to the source service's applicable asset terms.
