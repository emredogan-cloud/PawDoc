# 18 — Legal & Launch Gate (Phase 2.2)

> **HARD GATE.** PawDoc **must not** be released publicly until every item in
> §1 is done. These are founder/legal actions — they cannot be automated.

## 1. Blockers — required before any public launch

- [ ] **E&O (Errors & Omissions) insurance, ≥ $100K coverage, BOUND.** Start the
      application early — underwriting for an AI health-adjacent product can take
      weeks and may probe the "information, not diagnosis" framing. Keep the
      certificate of insurance on file; its effective date must precede launch.
- [ ] **Attorney review of the legal docs.** `docs/legal/terms-of-service.md` and
      `docs/legal/privacy-policy.md` are **templates**. A licensed attorney (US +
      EU/GDPR consumer/health experience) must finalize them and fill every
      `[BRACKETED]` placeholder.
- [ ] **CR #24 — Veterinary practice-law review (per jurisdiction).** In several US
      states, giving "veterinary advice" without a VCPR can constitute unlicensed
      practice. Have counsel confirm the "information & guidance, not diagnosis"
      framing is sufficient for each launch market, and inform the ToS/UX copy.
- [ ] **CR #9 — Retention policy decision.** Choose and document in the Privacy
      Policy §6: (a) full erasure on deletion + a defined purge window, or (b)
      anonymise-and-retain de-identified records. The code currently does full
      erasure (ON DELETE CASCADE). Align the policy to the code (or vice-versa).

## 2. Stand-up items

- [ ] **`support@pawdoc.app`** — create the mailbox/forwarding (Cloudflare Email
      Routing or your provider); add MX + SPF/DKIM/DMARC. Send/receive a test mail.
- [ ] **Publish the legal pages** at `https://pawdoc.app/terms` and
      `https://pawdoc.app/privacy` (the Next.js landing site lands in Phase 4.3; until
      then a simple static page is fine). Link them from the app and the store listing.
- [ ] **Affirmative ToS acceptance at signup** (checkbox / "By continuing you agree…")
      — required for GDPR; wire into the auth flow.

## 3. App Store review notes — DO NOT use the word "diagnosis"

Frame the review notes (and the listing) as an **information tool**, e.g.:

> "PawDoc is an AI-assisted **information and triage** tool for pet owners. It helps
> owners decide whether and how urgently to seek veterinary care. It does **not**
> provide a veterinary diagnosis or treatment and is not a substitute for a
> veterinarian. Every result shows a clear disclaimer, and emergency guidance always
> directs users to contact a veterinarian."

- Avoid "diagnose/diagnosis/treat/cure" in metadata, screenshots, and notes.
- Mention that disclaimers are shown on every result and that emergencies are never
  gated behind payment.
- Note the in-app **account deletion** (Apple Guideline 5.1.1(v) — already implemented).

## 4. Verify (what's automatable)

- Disclaimers are API-injected (not removable by the UI):
  ```bash
  ./scripts/verify-disclaimers.sh
  ```
- The whole phase: `./scripts/verify-phase-2.2.sh`

## 5. Sign-off

Public launch (Phase 2.3) proceeds **only** when §1 is fully checked: insurance bound,
legal docs attorney-reviewed and live, practice-law review done, and the retention
policy decided.
