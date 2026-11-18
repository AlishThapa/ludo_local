# Ludo Local 🎲

An offline-first Ludo game for Android and iOS, designed for smooth gameplay, small downloads, and low-end devices.

## Goals

- Flutter/Dart with a pure-Dart rules engine and lightweight custom board rendering.
- Minimum Android 8.0 (API 26); performance target: 60 FPS on phones with 4 GB RAM.
- Local pass-and-play first; Wi-Fi/hotspot and Bluetooth multiplayer in later milestones.
- No internet, login, or server requirement during gameplay.

## Status

Early development. Android 8 compatibility, FPS, memory usage, release size, and offline networking **have not yet been verified on physical devices**. Features and compatibility are only considered complete after testing.

## Branches

- `main`: stable project baseline.
- `feature/ludo-core`: development of the first playable game version.

## Roadmap

1. Core Ludo rules, pass-and-play, responsive board, and automated tests.
2. Local Wi-Fi/hotspot lobby and host-authoritative synchronization.
3. Bluetooth Low Energy connection mode, including Android/iOS cross-device testing.
4. Reconnect/resume, accessibility, visual polish, and audio.
5. Continuous integration, Android 8 validation, performance profiling, and APK size optimization.

## Technology

Flutter + Dart is preferred over Unity for a compact turn-based board game. Keep rendering, rules, and connection transports separate so gameplay remains deterministic and testable.

## License

No license selected yet.
