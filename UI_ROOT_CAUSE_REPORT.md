# PawDoc — UI Root Cause Report (Phase 6)
**2026-06-13**

## Root cause: **A — the new UI never merged.**

The `ui-translation` branch — which contains the entire new UI (screen rewrites,
the bottom-nav `root_shell`, the `paw_ui` kit, 9 `_v1` illustrations, and its
pubspec asset registration) — was **never merged into `main`**. It is internally
complete and self-consistent *on the branch*; it simply never landed.

### Why it's A and not the others (each ruled out with evidence)
| Hypothesis | Ruled out by |
|---|---|
| **B — UI merged, assets didn't** | UI itself isn't on main either (`root_shell.dart`, `paw_ui.dart`, the screen rewrites all MISSING from main). It's not an asset-only gap. |
| **C — assets merged, pubspec omitted** | The assets aren't on main at all; and on `ui-translation` the pubspec **is** updated (`pubspec.yaml +4`). Registration was done — on the branch. |
| **D — APK built from stale artifacts** | The APK was built **fresh** (2026-06-13 14:08) from main `d167ed0`. Not stale — just the wrong branch. |
| **E — wrong APK installed** | Contributing, not root: the installed APK was correct *for main*; the problem is main lacks the UI. The build-from-main is downstream of A. |
| **F — fallback masked missing assets** | main has no new UI to mask; it renders its own (ui-cycle + Rive) UI. No silent fallback involved. |

### How it happened (timeline)
1. The UI-translation program ran on `ui-translation` (branched off main `e1aed76`, PR #40) — Batches 1–4 + launch hardening. Reported "complete **and merged**." The "merged" half was **untrue**.
2. The finalization mission merged the engineering fixes (#41–#72) into main — but **never included `ui-translation`**.
3. Device validation built from main `d167ed0` (which has ui-cycle + motion, not ui-translation) and validated *that* UI, without detecting the new UI was absent.
4. The founder, looking for the translation UI (e.g. bottom nav), correctly saw the *earlier* main UI.

### Net
A single, clear miss: a finished feature branch that never got merged, then a
validation that tested the wrong branch. No data loss — the work is intact on
`ui-translation`; it needs an (involved) merge. See UI_RECOVERY_PLAN.md.
