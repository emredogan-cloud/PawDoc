// GAP-A6: pure R2/S3 helpers for the account-deletion cascade. The signed
// list/delete HTTP lives in the Edge function (Deno + aws4fetch); the XML
// parsing + prefix-safety logic is here so it runs in Node and is unit-tested.

function decodeXml(s) {
  return s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

/** Extract object keys from an S3/R2 ListObjectsV2 XML response. */
export function parseListKeys(xml) {
  const keys = [];
  const re = /<Key>([^<]*)<\/Key>/g;
  let m;
  while ((m = re.exec(xml)) !== null) keys.push(decodeXml(m[1]));
  return keys;
}

/** Continuation token for the next page, or null when the listing is complete. */
export function parseNextToken(xml) {
  if (!/<IsTruncated>\s*true\s*<\/IsTruncated>/i.test(xml)) return null;
  const m = /<NextContinuationToken>([^<]+)<\/NextContinuationToken>/.exec(xml);
  return m ? decodeXml(m[1]) : null;
}

/**
 * Safety filter: only ever return keys that live under `prefix`
 * (`uploads/<uid>/`). Even if a listing is mis-scoped, we never delete an
 * object outside the user's own namespace.
 */
export function keysUnderPrefix(keys, prefix) {
  return keys.filter((k) => typeof k === "string" && k.startsWith(prefix) && !k.includes(".."));
}
