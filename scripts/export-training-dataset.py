#!/usr/bin/env python3
"""Phase 6.2 — export the outcome-labeled analyses to a fine-tune-ready JSONL.

This is an **admin-only** script. It uses the Supabase `service_role` key and
intentionally bypasses RLS to aggregate across users. The PII-strip pipeline
lives in `ai-service/app/training_export.py` and is independently unit-tested.

USAGE
  export SUPABASE_URL="https://<ref>.supabase.co"
  export SUPABASE_SERVICE_ROLE_KEY="<service_role JWT>"   # Doppler / 1Password
  ai-service/.venv/bin/python scripts/export-training-dataset.py \\
      --output /tmp/pawdoc-training-$(date +%Y%m%d).jsonl \\
      --limit 5000

WHAT GETS EXPORTED  (positive allowlist — see training_export.CONTEXT_ALLOWED)
  context     : species, breed, age_years (at analysis time), input_type, symptom_text
  ai_response : triage_level, primary_concern, confidence, tier_used, override_applied
  outcome     : user_outcome, user_rating, days_to_feedback
  label       : false_positive_proxy | false_negative_proxy | true_*_proxy | null

WHAT NEVER LEAVES  (PII_BLOCKLIST — see training_export.assert_no_pii)
  - any uuid: id / analysis_id / pet_id / user_id / feedback_id
  - email / RevenueCat / OneSignal identifiers
  - GPS / IP
  - R2 storage keys / signed URLs

A pet name MAY appear inside `symptom_text` ("Buddy is lethargic…"). Pet names
are NOT user-identifying PII and provide useful linguistic context for the
model, but if the founder later releases the dataset externally a separate NER
pass should be run on the symptom_text field. Documented here so the choice is
explicit.

The script writes the OUTPUT file OUTSIDE the repo by default (/tmp). Repo
`.gitignore` carries `*.jsonl` as a belt-and-braces guard.
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "ai-service"))

from app.training_export import dumps_jsonl, to_training_record  # noqa: E402

PAGE_SIZE = 1000  # max PostgREST page; we paginate when --limit > PAGE_SIZE.

# PostgREST resource-embed select — minimum surface that satisfies the
# allowlist. Anything NOT named here is never even fetched from the server.
SELECT = (
    "triage_level,"
    "primary_concern,"
    "confidence_score,"
    "tier_used,"
    "emergency_override_applied,"
    "input_type,"
    "text_description,"
    "created_at,"
    "pet:pets(species,breed,birth_date),"
    "analysis_feedback(outcome,rating,created_at)"
)


def _fetch_page(client: httpx.Client, url: str, headers: dict[str, str],
                offset: int, limit: int) -> list[dict]:
    params = {
        "select": SELECT,
        # Only join-eligible rows: an analysis with at least one feedback row.
        "analysis_feedback": "not.is.null",
        "order": "created_at.desc",
        "limit": str(limit),
        "offset": str(offset),
    }
    resp = client.get(f"{url}/rest/v1/analyses", params=params, headers=headers, timeout=30.0)
    resp.raise_for_status()
    return resp.json()


def main() -> int:
    parser = argparse.ArgumentParser(description="Export outcome-labeled PawDoc data to JSONL.")
    parser.add_argument(
        "--output",
        default=f"/tmp/pawdoc-training-{__import__('datetime').datetime.utcnow().strftime('%Y%m%d')}.jsonl",
        help="Output JSONL path (default /tmp/pawdoc-training-<UTC date>.jsonl).",
    )
    parser.add_argument("--limit", type=int, default=5000, help="Max rows to scan (default 5000).")
    args = parser.parse_args()

    url = os.environ.get("SUPABASE_URL") or ""
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    if not url or not key:
        print(
            "ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required. "
            "Source them from Doppler / 1Password — never commit them.",
            file=sys.stderr,
        )
        return 2

    headers = {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        # PostgREST: ask for a "Prefer" header that returns the joined rows
        # (default already returns them; explicit for clarity).
        "Accept": "application/json",
    }

    written = 0
    skipped_no_outcome = 0
    fp = fn = tp = tn = 0

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with httpx.Client() as client, out_path.open("w", encoding="utf-8") as fh:
        scanned = 0
        offset = 0
        while scanned < args.limit:
            page_size = min(PAGE_SIZE, args.limit - scanned)
            rows = _fetch_page(client, url, headers, offset, page_size)
            if not rows:
                break
            for row in rows:
                rec = to_training_record(row)
                if rec is None:
                    skipped_no_outcome += 1
                    continue
                fh.write(dumps_jsonl(rec))
                written += 1
                label = rec.get("label")
                if label == "false_positive_proxy":
                    fp += 1
                elif label == "false_negative_proxy":
                    fn += 1
                elif label == "true_positive_proxy":
                    tp += 1
                elif label == "true_negative_proxy":
                    tn += 1
            scanned += len(rows)
            offset += len(rows)
            if len(rows) < page_size:
                break

    print(f"Wrote {written} records to {out_path}")
    print(f"  skipped (no outcome yet): {skipped_no_outcome}")
    print(f"  labels — FP={fp}  FN={fn}  TP={tp}  TN={tn}")
    if fn > 0:
        print(
            f"NOTE: {fn} false-negative-proxy row(s) found. Review them and add the "
            "incidents to ai-service/tests/golden_set.json to harden the safety eval.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
