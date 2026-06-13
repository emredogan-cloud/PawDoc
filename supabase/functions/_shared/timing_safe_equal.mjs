// GAP-E5: constant-time string comparison for webhook secret verification.
//
// A naive `a === b` (or `!==`) short-circuits at the first differing byte, so
// response time leaks how many leading bytes of a guess are correct — enough to
// recover a shared secret byte-by-byte. This compares every byte regardless of
// where they differ, folding the result (and the length difference) into a
// single accumulator so the work is independent of the inputs' contents.
//
// Note: like Node's crypto.timingSafeEqual, this does not hide the *length* of
// the inputs; it removes the content-dependent early exit, which is the
// exploitable channel for secret recovery.
export function timingSafeEqual(a, b) {
  const enc = new TextEncoder();
  const ab = enc.encode(String(a ?? ""));
  const bb = enc.encode(String(b ?? ""));
  const len = Math.max(ab.length, bb.length);
  // Seed with the length difference so unequal lengths can never compare equal.
  let diff = ab.length ^ bb.length;
  for (let i = 0; i < len; i++) {
    diff |= (ab[i] ?? 0) ^ (bb[i] ?? 0);
  }
  return diff === 0;
}
