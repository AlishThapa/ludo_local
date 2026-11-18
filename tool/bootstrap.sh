#!/usr/bin/env bash
set -euo pipefail
# From project root; requires Flutter SDK installed.
flutter create --platforms=android,ios --project-name ludo_local .
flutter pub get
flutter analyze
flutter test
