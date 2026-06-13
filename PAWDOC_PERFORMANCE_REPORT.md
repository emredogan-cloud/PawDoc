# PawDoc — Performance Report
**2026-06-13** · Redmi Note 11R (Android 13, 3.66 GB RAM — low-mid range). Observed only; no speculation.

## Startup (am start -W, release build)
| Launch | TotalTime |
|--------|-----------|
| First cold (post-install, JIT warmup) | **4,805 ms** |
| Subsequent cold | **1,783 ms** |
| Warm (after force-stop) | **895 ms** |

The first post-install launch (~4.8s) is on the slow side for a low-RAM device
(Flutter engine + Dart AOT warmup + asset load); subsequent launches (~0.9–1.8s)
are good. No black-screen/hang during startup; the splash → sign-in transition
was clean.

## Memory (dumpsys meminfo, on Home)
- **TOTAL PSS ≈ 136.8 MB** · TOTAL RSS ≈ 219 MB · Native Heap ≈ 37 MB · Dalvik ≈ 2 MB · SWAP ≈ 0.5 MB.
- For a Flutter app bundling Rive/Lottie/illustrations this is **reasonable** (typical 100–200 MB) and comfortable on a 3.66 GB device. No leak signal observed across the session (launch → onboarding → analyze → home), though a dedicated soak/leak test was not run.

## Frame pacing / jank
- `gfxinfo` was reset by the recovery force-stop, so only 2 frames were captured
  (inconclusive — the single post-launch frame reads as "janky" by definition).
  **A meaningful jank profile was not obtained** and is **deferred to the founder
  device-pass** (scroll history, switch pets, run several analyses while capturing
  `gfxinfo`). Subjectively, the onboarding transitions + loading animation
  rendered smoothly in the captured frames (no visible stutter/flicker).
- Display supports 60/90/30 Hz; no frame-rate anomalies observed.

## Network
- The analyze call (okhttp) to the Supabase Edge/AI path completed; the emergency
  override returned promptly (server-side, pre-AI). No retries/timeouts observed
  on the validated flows.

## Recommendation
Acceptable for beta. For the founder device-pass: capture a real `gfxinfo`
jank profile during sustained navigation, and confirm startup on a representative
low-end device is acceptable (consider deferring heavy asset preloads if the
~4.8s first-launch proves bothersome in tester feedback).
