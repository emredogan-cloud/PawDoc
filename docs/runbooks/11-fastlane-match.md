# 11 — Fastlane + Match (iOS certs, TestFlight, Play)

> **The long pole of Phase 0.4.** Match certificate setup routinely overruns. The lane
> files (`fastlane/`) are written; this is the account/cert work + relocating them into
> `mobile/ios` / `mobile/android` in Phase 1.1.

**Prerequisite:** Apple Developer Program approved (runbook 01).

## 1. Install

```bash
# in mobile/ios once it exists (1.1); for now you can validate from fastlane/
gem install bundler
bundle install            # installs the fastlane gem pinned in Gemfile
```

## 2. App Store Connect API key (`.p8`)

App Store Connect → **Users and Access → Integrations → App Store Connect API** → **Generate key** (role: App Manager).
Record and store as GitHub secrets:
- **Key ID** → `APP_STORE_CONNECT_API_KEY_KEY_ID`
- **Issuer ID** → `APP_STORE_CONNECT_API_KEY_ISSUER_ID`
- **`.p8` contents** → `APP_STORE_CONNECT_API_KEY_KEY`

## 3. Match (signing certs in a private repo)

1. Create an **empty PRIVATE** repo, e.g. `emredogan-cloud/pawdoc-certs`.
2. Point `fastlane/Matchfile` at it (`MATCH_GIT_URL`).
3. Generate + store certs once, locally:
   ```bash
   export MATCH_PASSWORD=<a strong passphrase you choose>
   fastlane match appstore
   ```
4. Store as GitHub secrets: `MATCH_PASSWORD`, and a `MATCH_GIT_BASIC_AUTHORIZATION` (base64 of `user:personal_access_token`) so CI can read the certs repo.

CI runs match in **readonly** mode — it never mints new certs.

## 4. Google Play service account (for `play_internal`)

Play Console → **Setup → API access** → create/link a Google Cloud **service account** → grant it release permissions → download the **JSON key**. Store its path/contents as `GOOGLE_PLAY_JSON_KEY_FILE`.

## 5. Verify (Phase 0.4 DoD)

Once `mobile/ios` exists (1.1): push a tag and confirm a TestFlight build appears within 24h.
```bash
git tag v0.1.0 && git push origin v0.1.0   # triggers release.yml
```
