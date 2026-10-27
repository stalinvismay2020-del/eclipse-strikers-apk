# Eclipse Strikers — Godot Android

An offline-first, anime-inspired 3D football game project built with Godot 4 and GDScript.

## Android build

A GitHub Actions workflow exports a debug APK on pushes to game source/config files and can be started manually from **Actions → Build Eclipse Strikers APK → Run workflow**.

- APK artifact: `eclipse-strikers-debug-apk`
- Package ID: `com.innocentzero.eclipsestrikers`
- Target: Android ARM64
- Engine: Godot 4.3
- Rendering: Mobile-friendly GL Compatibility

## Current implemented systems

- 3D pitch, goals, physics ball, and eight players for offline 4v4
- Third-person player camera, keyboard and touch controls
- Shoot, pass, through pass, finesse shot, tackle/jockey, sprint, burst and ultimate actions
- AI teammates/opponents, match timer, score, kickoffs and full-time
- Lobby, character/ability/team-color selection, tutorial, settings and pause
- Local profile/progression, goals, tasks/rewards, and sound effects
- Optional direct-IP multiplayer prototype (requires reachable host/network; offline mode remains the default)

## Important status

This is an actively developed game prototype, not a claim of a finished commercial-quality game. A successful CI export proves the APK was produced; actual Android gameplay/performance still needs device testing. Final anime character models, rigged animations, advanced VFX/audio, and comprehensive football rules remain future polish.

## Build artifact

Open the repository's **Actions** tab, select **Build Eclipse Strikers APK**, open a successful run, then download the `eclipse-strikers-debug-apk` artifact. Artifacts expire after 14 days, so download and keep the APK.
