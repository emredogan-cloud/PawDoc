# 07 — Cloudflare R2 buckets + CORS

R2 stores pet photos/videos. S3-compatible, no egress fees. Two buckets isolate dev from prod.

**Dashboard:** Cloudflare → **R2**.

## 1. Enable R2

Cloudflare dashboard → **R2** → Enable (you may need a payment method on file even for the free tier). Note your **Account ID** (right-hand panel).

## 2. Create an R2 API token (S3 credentials)

R2 → **Manage R2 API Tokens** → **Create API token**:
- Permissions: **Object Read & Write**.
- Copy the **Access Key ID** and **Secret Access Key** (secret shown once).

Store everything in Doppler:
```bash
doppler secrets set R2_ACCOUNT_ID="<account id>"            --project pawdoc --config dev
doppler secrets set R2_ACCESS_KEY_ID="<access key id>"      --project pawdoc --config dev
doppler secrets set R2_SECRET_ACCESS_KEY="<secret>"         --project pawdoc --config dev
doppler secrets set R2_ENDPOINT="https://<account id>.r2.cloudflarestorage.com" --project pawdoc --config dev
doppler secrets set R2_BUCKET_DEV="pawdoc-uploads-dev"      --project pawdoc --config dev
doppler secrets set R2_BUCKET_PROD="pawdoc-uploads-prod"    --project pawdoc --config dev
# repeat the relevant ones for --config prd
```

## 3. Create buckets + apply CORS

**Script (recommended)** — pulls creds from Doppler:
```bash
doppler run --project pawdoc --config dev -- ./scripts/r2-bootstrap.sh
```
This creates `pawdoc-uploads-dev` + `pawdoc-uploads-prod` and applies `infra/r2-cors.json` (origins: `pawdoc.app` + localhost; methods GET/PUT/HEAD).

**Dashboard alternative:** R2 → Create bucket (×2) → each bucket → **Settings → CORS Policy** → paste the rules from `infra/r2-cors.json`.

## 4. Verify

```bash
doppler run --project pawdoc --config dev -- ./scripts/verify-phase-0.2.sh
```
Then confirm a **real browser preflight** (the roadmap calls out curl-only checks as insufficient): from any `https://pawdoc.app`-origin page (or a localhost dev page), run in the browser console:
```js
fetch("https://<account-id>.r2.cloudflarestorage.com/pawdoc-uploads-dev/probe",
  { method: "OPTIONS" }).then(r => console.log([...r.headers]))
```
You should see an `access-control-allow-origin` header.

## Security model (important)

- **Never ship R2 write keys in the app.** The Flutter client uploads using **short-lived presigned PUT URLs** minted by an Edge Function (built in Phase 1.2, per Critical Review #6).
- Keep buckets **private** (no public read). Reads also go through presigned/proxied URLs.
- EXIF/GPS is stripped client-side before upload (Phase 1.2, Critical Review #7).
