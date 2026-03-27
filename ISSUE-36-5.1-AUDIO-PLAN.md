# Issue #36: No 5.1 Sound in QSS-M

## Summary

This should be treated as an SDL/Windows surround-output regression on top of a stereo-only mixer, not as a one-line cvar bug.

Current code evidence:

- The SDL backend hard-codes stereo in `Quake/snd_sdl.c`.
- The mix buffer is only `left/right` in `Quake/q_sound.h`, and channel spatialization is only `left/right` in `Quake/snd_dma.c`.
- The transfer path assumes 1 or 2 output channels; forcing 6 output channels into the current path will corrupt transfer math, which matches the reported screeching/silence from the July 2025 test builds.
- `snd_speakers` does not appear to exist in the current repo history, so that experiment likely never landed.

## Plan

### 1. Reproduce and instrument

- Build and test the current Windows SDL2 binary with the bundled SDL version.
- Add temporary logging in `SNDDMA_Init` for requested format, obtained format, driver, and device name.
- Compare behavior with current SDL and the older Quakespasm 0.95.0 SDL DLL that users report still fills 5.1 speakers.

### 2. Fix the backend API first

- Replace `SDL_OpenAudio` with `SDL_OpenAudioDevice` for SDL2 builds in `Quake/snd_sdl.c`.
- Start using an obtained `SDL_AudioSpec` instead of assuming the requested format is what the device actually runs.
- Add a real `snd_speakers` cvar in `Quake/snd_dma.c` with:
  - `0 = auto`
  - `2 = stereo`
  - `6 = 5.1`

### 3. Keep the engine stereo internally for phase 1

- Do not set `shm->channels = 6` and reuse the existing mixer unchanged.
- Keep internal mixing as stereo, then add a dedicated stereo-to-5.1 output expansion step at the final transfer stage.
- This gives a compatibility fix quickly:
  - front L/R from the original mix
  - optional center/rears derived from stereo
  - LFE off or conservative

### 4. Separate internal mix channels from device channels

- Right now `shm->channels` is overloaded and leaks device layout into timing and mix code.
- Introduce distinct concepts for internal mix width and device output width so the engine keeps thinking in sample pairs while SDL output can be 2 or 6 channels safely.

### 5. Verify before shipping

- Test stereo hardware and 5.1 hardware.
- Test `snd_speakers 0`, `snd_speakers 2`, and `snd_speakers 6`.
- Verify:
  - SFX
  - ambient loops
  - streamed music
  - demo playback
  - `snd_restart`
- Confirm no screeching, silence, underruns, or timing regressions.

## Scope Note

If the goal is true positional 5.1, that is a second-phase project. It would require redesigning the core sound structures, spatialization, raw sample handling, and mixer transfer code.

For issue #36, the pragmatic fix is:

- keep the internal mix stereo
- add a safe 5.1 output path at the SDL/device boundary
