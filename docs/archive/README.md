# Archive — historical engineering reports

Point-in-time development reports, audits, verdicts and superseded roadmaps.
**Nothing here is current.** They are kept because they hold the *reasoning* behind
decisions that are still in force, plus the evidence trail for past findings.

Archived on 2026-07-27 by moving (`git mv`) every root-level report whose last
commit predated 2026-07-23. Full git history is preserved — use
`git log --follow docs/archive/<month>/<file>` to read a document's history
across the move.

## Layout

Files are filed by the month of their last substantive commit.

| Folder | Contents |
| --- | --- |
| `2026-06/` | Launch-gap analysis, remediation playbook, go-live master plan, UI/motion phase reports (A–L, M0–M4), batch + sprint execution reports, first device-validation pass, merge-authority investigation. |
| `2026-07/` | Pre-launch final audit, final evolution report, product-evolution masterplan + feature matrix, founder strategy guide, store-review checklists, legal-portal report, RC validation, environment audit, Play internal-test report, Turkish product doc. |

## Where the current documentation lives

| Topic | Current location |
| --- | --- |
| Project instructions / conventions | `CLAUDE.md` (root) |
| Environment + local setup | `ENVIRONMENT_SETUP.md` (root) |
| Per-phase implementation log | `IMPLEMENTATION_CHANGELOG.md` (root) |
| Live legal page copy | `LEGAL_CONTENT_APPENDIX.md` (root) |
| Latest release status | `FINAL_RELEASE_READY_REPORT.md` (root) |
| Founder operations | `docs/runbooks/` |
| Frozen API contract | `docs/contracts/ANALYSIS_RESULT.md` |
| Execution roadmap | `roadmap/APP_EXECUTION_ROADMAP_DECOMPOSED.md` |
| Standing decisions (do not revert) | `memory/PAST_DECISIONS.md` |
| Per-sub-PR reports | `sub-pr-report/` |

## Reading these safely

- Cross-references inside archived documents use bare filenames from when they
  sat together in the repo root. Those neighbours are now in this tree, usually
  in the same month folder.
- Status claims ("verdict NO", "blocked", "not yet built") were true on the
  document's date and are frequently stale. Treat `FINAL_RELEASE_READY_REPORT.md`
  and `memory/PAST_DECISIONS.md` as authoritative on current state.
