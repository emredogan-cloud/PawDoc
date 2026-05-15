# mobile

Flutter 3.x app for PawDoc (iOS + Android).

## Phase 0 Status

The foundation only. Splash screen renders, theme is wired, navigation is set
up, but **no feature flows are implemented yet**. Phase 1 adds onboarding,
auth, camera, analysis, and the paywall.

## Local Development

Requires Flutter 3.41+ (`flutter --version`).

```bash
# Install packages
flutter pub get

# Copy env template (and edit it)
cp env/dev.json.example env/dev.json

# Run on a connected device or simulator
flutter run --dart-define-from-file=env/dev.json
```

`env/dev.json` is gitignored — fill it from Doppler.

## Quality

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos --fatal-warnings
flutter test
```

All three are required-to-pass in CI (`.github/workflows/mobile-ci.yml`).

## Layout

```
lib/
├── main.dart                 entrypoint
├── app/
│   ├── app.dart              MaterialApp
│   ├── config.dart           compile-time env
│   ├── router.dart           go_router config
│   └── theme.dart            Material 3 theme
├── shared/
│   ├── services/             logger, supabase client
│   ├── providers/            Riverpod cross-feature providers (Phase 1+)
│   ├── models/               shared value objects (Phase 1+)
│   └── widgets/              shared widgets (Phase 1+)
├── features/
│   ├── auth/                 (Phase 1)
│   ├── onboarding/           (Phase 1)
│   ├── home/                 (Phase 1)
│   ├── analysis/             (Phase 1)
│   ├── pets/                 (Phase 1)
│   ├── history/              (Phase 3)
│   ├── reminders/            (Phase 3)
│   ├── paywall/              (Phase 1)
│   └── settings/             (Phase 2)
└── platform/
    ├── ios/                  on-device CoreML (Phase 1+)
    └── android/              on-device TFLite (Phase 1+)
env/                         compile-time env injection
test/                        widget + unit tests
```

## Architectural Rules

- **Feature-first folders.** Each `features/<name>/` is self-contained (its own
  state, routes, screens). Cross-feature dependencies go through `shared/`.
- **No `dynamic`.** Strict casts + strict inference enforced by analyzer.
- **No `print`.** Use `AppLogger.of('module.name')`.
- **No widgets call `String.fromEnvironment` directly.** Use `appConfigProvider`.
- **`const` constructors everywhere they can be.** Enforced by lints.
- **Generated code (`*.g.dart`, `*.freezed.dart`) is gitignored.** Run codegen
  locally: `dart run build_runner build --delete-conflicting-outputs`.

## Bundle ID

iOS / Android: `com.pawdoc.pawdoc` (set via `flutter create --org com.pawdoc`).

## Flavors / Environments

We do not use native flavors. Environment selection happens at compile time via
`--dart-define-from-file`:

```bash
flutter run --dart-define-from-file=env/dev.json     # dev backend
flutter run --dart-define-from-file=env/prod.json    # prod backend
```

The resulting binary is hard-coded to its environment — no runtime selection,
no `.env` parsing on device.
