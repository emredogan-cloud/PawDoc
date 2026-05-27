# PawDoc — User Profile

**Solo founder** focusing on architecture, security, and live infrastructure
provisioning. Relying on the agent for heavy coding while owning the high-level
technical direction, the product/business decisions, and anything requiring real
credentials, accounts, or money (Doppler secrets, Supabase/Fly/R2/RevenueCat/
OneSignal provisioning, app-store accounts, E&O insurance, legal review).

The **#1 business risk is a false-negative AI analysis** (telling a pet parent
"likely normal" when it's an emergency). Therefore **safety and defensive coding
are always prioritized over speed.** When trading off, choose the safer, more
conservative path and explain it.

## How the founder works with the agent
- **Executes the roadmap sub-PR by sub-PR**, approving each at an explicit human gate. Wants scope kept tight to the current sub-PR — no scope creep, no skipping ahead.
- **Wants risks and decisions surfaced, not absorbed.** Raise Critical-Review items, security gaps, and trade-offs as clear proposals; let the founder decide. Don't silently apply or silently revert.
- **Verification over assertion.** Expects checks actually run and output shown before "done." Distrusts unverified "it works" / "merged" claims — confirm by content/state.
- **Security-first by default.** Add necessary security/compliance even when unlisted. Never weaken the emergency path, disclaimers, RLS, or secret hygiene to ship faster.
- **Founder-side actions are manual and gated.** Device/simulator runs, live-infra deploys, store submissions, payments, and legal steps are the founder's; mark them MANUAL — never fake or auto-execute them.
