// GAP-A6 R2-helper tests. Run: node --test supabase/functions/_shared/r2.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import { keysUnderPrefix, parseListKeys, parseNextToken } from "./r2.mjs";

const UID = "11111111-1111-1111-1111-111111111111";
const XML = `<?xml version="1.0"?>
<ListBucketResult>
  <Contents><Key>uploads/${UID}/a.jpg</Key></Contents>
  <Contents><Key>uploads/${UID}/sub/b.png</Key></Contents>
  <Contents><Key>uploads/other/c.jpg</Key></Contents>
  <IsTruncated>false</IsTruncated>
</ListBucketResult>`;

test("parseListKeys extracts every key", () => {
  assert.deepEqual(parseListKeys(XML), [
    `uploads/${UID}/a.jpg`,
    `uploads/${UID}/sub/b.png`,
    "uploads/other/c.jpg",
  ]);
});

test("keysUnderPrefix keeps only the caller's namespace (never deletes others')", () => {
  const keys = parseListKeys(XML);
  assert.deepEqual(keysUnderPrefix(keys, `uploads/${UID}/`), [
    `uploads/${UID}/a.jpg`,
    `uploads/${UID}/sub/b.png`,
  ]);
});

test("keysUnderPrefix rejects traversal", () => {
  assert.deepEqual(keysUnderPrefix([`uploads/${UID}/../../etc`], `uploads/${UID}/`), []);
});

test("parseNextToken: null when complete, token when truncated", () => {
  assert.equal(parseNextToken(XML), null);
  const more = `<ListBucketResult><IsTruncated>true</IsTruncated><NextContinuationToken>TOK123</NextContinuationToken></ListBucketResult>`;
  assert.equal(parseNextToken(more), "TOK123");
});
