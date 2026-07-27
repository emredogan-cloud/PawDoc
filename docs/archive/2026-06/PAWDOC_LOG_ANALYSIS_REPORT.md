# PawDoc — Log Analysis Report
**2026-06-13** · logcat captured across launch, auth, onboarding, pet-create, and the emergency analyze flow.

## Summary: clean — no app-level crashes, exceptions, or fatal errors.
Across every validated flow, **zero `FATAL` / `AndroidRuntime` / `E/flutter`
exceptions** were emitted by `app.pawdoc`. No ANRs. No `MissingConfig`/Supabase
init errors (the build is correctly configured).

## What WAS in the logs (classified)
| Class | Examples | Severity |
|-------|----------|----------|
| **App crashes/exceptions** | — none — | n/a |
| App network | okhttp `sendRequest` on analyze (completed) | INFO (normal) |
| Expected lifecycle | "app died, no saved state" after **BACK on the sign-in root** (normal Android exit, not a crash) | INFO |
| Device/OEM noise | MIUI `FileUtils: err … mi_exception_log`, `SLM-SRV-SLAService thermal_message ENOENT`, `WifiVendorHal getWifiLinkLayerStats … ERROR_UNKNOWN`, `C2MtkBufferManager slow BM`, gms `avc: denied` | EXTERNAL — Xiaomi/MIUI system, **not PawDoc** |
| Keyboard/IME | LatinIme/KeyboardManager (Turkish IME) | INFO |

None of the `E/` lines originate from `app.pawdoc`; they are MIUI platform/vendor
logs present regardless of the app.

## Notable absences (good)
- No unhandled Dart exceptions, no Sentry-class errors, no failed-assert red screens.
- No repeated retry storms or network-failure loops on the validated paths.

## Caveats
- Release build → minimal app-level logging by design (no verbose Supabase/analyze
  traces), so logcat alone can't confirm internal branch coverage; behavior was
  verified via screenshots instead.
- Flows not exercised on-device (photo/video analyze, family, etc.) were not
  log-analyzed — founder device-pass should re-capture logcat for those.
