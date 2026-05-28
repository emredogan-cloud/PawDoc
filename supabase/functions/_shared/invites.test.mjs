// Phase 6.3.1 — invite-helper unit tests.
import assert from "node:assert/strict";
import { test } from "node:test";

import {
  INVITE_ELIGIBLE_TIERS,
  buildInviteEmail,
  generateInviteToken,
  inviteLink,
  normalizeEmail,
} from "./invites.mjs";

test("invite-eligible tiers: family + b2b_lite, NOT premium or free", () => {
  assert.equal(INVITE_ELIGIBLE_TIERS.has("family"), true);
  assert.equal(INVITE_ELIGIBLE_TIERS.has("b2b_lite"), true);
  assert.equal(INVITE_ELIGIBLE_TIERS.has("premium"), false);
  assert.equal(INVITE_ELIGIBLE_TIERS.has("trial"), false);
  assert.equal(INVITE_ELIGIBLE_TIERS.has("free"), false);
});

test("token is URL-safe and high-entropy", () => {
  const a = generateInviteToken();
  const b = generateInviteToken();
  assert.notEqual(a, b);
  assert.match(a, /^[A-Za-z0-9_-]+$/);
  // 32 random bytes -> base64url without padding -> 43 chars.
  assert.equal(a.length, 43);
});

test("normalizeEmail trims + lowercases; rejects strings without @", () => {
  assert.equal(normalizeEmail("  FOO@Example.COM "), "foo@example.com");
  assert.equal(normalizeEmail(""), null);
  assert.equal(normalizeEmail(null), null);
  assert.equal(normalizeEmail("not-an-email"), null);
  assert.equal(normalizeEmail(undefined), null);
});

test("inviteLink defaults to pawdoc.app/invite + URL-encodes the token", () => {
  assert.equal(
    inviteLink(null, "abc123-_x"),
    "https://pawdoc.app/invite/abc123-_x",
  );
  assert.equal(
    inviteLink("https://example.com/i/", "abc"),
    "https://example.com/i/abc",
  );
});

test("Resend payload includes the link + expiry hint", () => {
  const email = buildInviteEmail({
    to: "foo@example.com",
    link: "https://pawdoc.app/invite/xyz",
    inviterName: "Alice",
    groupName: "Smith family",
  });
  assert.equal(email.to, "foo@example.com");
  assert.match(email.subject, /Alice/);
  assert.match(email.subject, /PawDoc/);
  assert.match(email.text, /Smith family/);
  assert.match(email.text, /48 hours/);
  assert.match(email.text, /pawdoc\.app\/invite\/xyz/);
});

test("Resend payload tolerates a missing inviter name + group name", () => {
  const email = buildInviteEmail({
    to: "foo@example.com",
    link: "https://pawdoc.app/invite/xyz",
  });
  assert.match(email.text, /Family/);
  assert.doesNotMatch(email.text, /undefined/);
});
