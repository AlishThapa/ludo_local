# Ludo Local delivery plan

## Phase 0 (included)
- [x] Flutter CustomPainter board and responsive shell (local starter; pending upload)
- [x] 2–4 player pass-and-play (local starter; pending upload)
- [x] Isolated Ludo rules and basic tests
- [ ] Verify `flutter analyze` and `flutter test` using Flutter SDK
- [ ] Test Android 8.0 on real 4 GB RAM hardware

## Phase 1 — Game correctness and polish
- [ ] Confirm the canonical clockwise track and color-to-home mapping visually
- [ ] Shared-square token stacking, home lane UX, accessibility
- [ ] Rules: three sixes, blockades, house-rule configuration
- [ ] State persistence, pause/resume, sound/haptic toggles
- [ ] Sprite-free transitions, dice roll animation, 60 FPS profiling

## Phase 2 — Wi-Fi / hotspot multiplayer
- [ ] Host authoritative move/dice command validation
- [ ] Versioned, ordered message protocol with snapshot hashes
- [ ] TCP peer adapters and reconnect/resume
- [ ] mDNS/Bonjour room advertisement with manual fallback
- [ ] Android–iOS cross-device testing, airplane mode with Wi-Fi enabled

## Phase 3 — Bluetooth-only multiplayer
- [ ] Evaluate and implement BLE central/peripheral roles on both platforms
- [ ] Advertisement, service discovery, MTU-aware framing and acknowledgments
- [ ] Host election, disconnect handling, maximum peer capacity testing
- [ ] Validate Android↔Android, iOS↔iOS, Android↔iOS on actual devices

## Phase 4 — Release qualification
- [ ] Device matrix: Android 8.0 / 4 GB, newer budget Android, iPhone
- [ ] Warm/cold start time, memory, CPU, frame pacing, battery profiling
- [ ] APK/AAB size reports; asset pruning; release obfuscation as appropriate
- [ ] Offline and permissions regression tests
