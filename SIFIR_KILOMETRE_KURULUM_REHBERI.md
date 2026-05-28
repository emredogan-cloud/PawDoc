# PawDoc — Sıfır Kilometre Kurulum ve Operasyon Rehberi

> Bu belge, mühendislik tarafı tamamlanmış (Faz 0 → Faz 6.3.1) bir kod tabanı varken, **kurucunun henüz tek bir hesap açmadığı, tek bir API anahtarı üretmediği, tek bir komut çalıştırmadığı sıfır noktasından** başlayıp uygulamayı canlıya almasına yarayan tam yol haritasıdır.
>
> Akış, gereksiz sekme değiştirmeyi en aza indirecek şekilde platform/işlem bloklarına bölünmüştür. Her adımda **hangi dashboard'a girilir, hangi butona basılır, anahtar nereye kaydedilir** açıkça yazılıdır.
>
> Tek doğruluk kaynağı bu rehberdir; ayrıntı için sırasıyla [`/ENVIRONMENT_VARS.md`](ENVIRONMENT_VARS.md) ve [`docs/runbooks/00–21`](docs/runbooks) referans dosyalarıdır.

---

## 0. Sözleşme ve Genel Kurallar

PawDoc — **safety-critical** bir hayvan sağlığı triyaj uygulamasıdır. Bu yüzden aşağıdaki kurallar **hiçbir aşamada esnetilmez**:

1. **Hiçbir gerçek sır git'e gömülmez.** Tüm gerçek değerler **Doppler**'da saklanır; `.env.example` dosyaları yalnızca şekil tariflerini içerir, gerçek anahtar barındırmaz.
2. **Üç katmanlı çevre ayrımı:** Geliştirme (`dev`), AB veri ikametgâhı (`eu`) ve üretim (`prd`). Her birinin ayrı Supabase projesi ve ayrı R2 kovası vardır.
3. **`service_role` anahtarı yalnızca sunucu tarafıdır.** Asla mobil uygulamaya, web istemcisine veya client-side koda gömülmez.
4. **EMERGENCY (acil) kararı asla ödeme duvarının ardına alınmaz.** Hem sunucu (`/analyze` Edge Function) hem istemci (`paywall_policy`) bu kuralı uygular.
5. **R2 yazma anahtarları istemciye gönderilmez.** İstemci yüklemeleri yalnızca **kısa ömürlü presigned PUT URL'leri** ile yapılır (CR #6).
6. **Yasal kapılar geçilmeden halka açılmaz.** E&O sigortası, avukat onaylı ToS/Gizlilik Politikası, veteriner hukuk incelemesi (CR #24) ve CR #9 saklama kararı tamamlanmadan **public availability açılmaz.**

> Yasal kapılar tüm teknik ortam çalışırken bile, halka açık çıkışın önündeki tek **HARD GATE**'tir. Beta testi ve store submission'a başlayabilirsiniz; **public availability açılamaz.** Detay: `docs/runbooks/18-legal-and-launch-gate.md`.

---

## İçindekiler

1. [Genel Bakış: Yola Çıkış Planı](#1-genel-bakış-yola-çıkış-planı)
2. [Blok A — Hesap Açma (Day-1, paralel başlatılır)](#blok-a--hesap-açma-day-1-paralel-başlatılır)
3. [Blok B — Sır Yönetimi Omurgası: Doppler + GitHub PAT](#blok-b--sır-yönetimi-omurgası-doppler--github-pat)
4. [Blok C — Backend Servis Hesapları ve Anahtarlar](#blok-c--backend-servis-hesapları-ve-anahtarlar)
5. [Blok D — Sırları Hedef Platformlara Aktarma](#blok-d--sırları-hedef-platformlara-aktarma)
6. [Blok E — Veritabanı Migration ve Test Scriptleri](#blok-e--veritabanı-migration-ve-test-scriptleri)
7. [Blok F — Supabase Edge Functions Deploy](#blok-f--supabase-edge-functions-deploy)
8. [Blok G — AI Service (Fly.io) Deploy](#blok-g--ai-service-flyio-deploy)
9. [Blok H — Web (pawdoc.app/check ve marketing) Deploy](#blok-h--web-pawdocappcheck-ve-marketing-deploy)
10. [Blok I — Mobil Build, Gerçek Cihazda Test ve Fastlane](#blok-i--mobil-build-gerçek-cihazda-test-ve-fastlane)
11. [Blok J — Manuel ve Yasal Süreçler (Yayın Kapısı)](#blok-j--manuel-ve-yasal-süreçler-yayın-kapısı)
12. [Blok K — Çıkıştan Sonra Operasyonel Rutinler](#blok-k--çıkıştan-sonra-operasyonel-rutinler)
13. [Ekler: Tüm Çevresel Değişkenler ve Sırların Sahip Olduğu Yerler Matrisi](#ekler-tüm-çevresel-değişkenler-ve-sırların-sahip-olduğu-yerler-matrisi)

---

## 1. Genel Bakış: Yola Çıkış Planı

| Aşama | Süre | Ön koşul | Çıktı |
|---|---|---|---|
| Blok A — Hesap Açma | Day 1 (Apple inceleme 24–48h, Google 1–3 gün) | — | Tüm platform hesapları başlatılmış |
| Blok B — Doppler omurgası | 30 dk | Doppler hesabı | `pawdoc` projesi, `dev`/`prd` config'leri, placeholder slot'ları |
| Blok C — Backend hesaplar + anahtarlar | 3–4 saat | Blok B | Doppler'da gerçek değerler |
| Blok D — Sırların dağıtımı | 1–2 saat | Blok C | Supabase, Fly, Cloudflare Pages, GitHub Actions sırları yerinde |
| Blok E — Veritabanı | 30 dk | Blok C (Supabase URL + access token) | 16 migration uygulandı, RLS testleri yeşil |
| Blok F — Edge Functions deploy | 1 saat | Blok E | 13 Edge Function canlı |
| Blok G — Fly AI service | 30 dk | Blok C (Anthropic + Gemini + OpenAI) | `https://pawdoc-ai.fly.dev/health` → `ok` |
| Blok H — Web deploy | 1 saat | Blok C (Supabase URL/anon + Turnstile site key) | `https://pawdoc.app` ve `/check` canlı |
| Blok I — Mobil + Fastlane | 1 gün | Apple/Google Play onaylı + Blok C | Cihaza yüklenmiş build, TestFlight + Play internal track |
| Blok J — Yasal + store submission | 2–4 hafta (avukat + E&O incelemesi) | Tüm önceki bloklar | App Store + Play onayı, halka açık çıkış |

> Bloklar **kabaca paraleldir**: Apple/Google Play inceleme süresini, Blok B ve C arka planda çalışarak telafi edersiniz. Ama Bloklar E → F → G **bu sıralamayla** gitmelidir (migration olmadan function deploy edilmez; AI service'i secrets olmadan deploy etmek kötü duruma yol açar).

---

## Blok A — Hesap Açma (Day-1, paralel başlatılır)

> Bu blokta sadece kayıt + ödeme + kimlik doğrulamayı başlatıyoruz. **API anahtarı üretimi** Blok C'ye kadar bekleyebilir; Apple/Google ise inceleme süresi yüzünden ilk gün başlatılmalıdır.

### A.1 — Apple Developer Program

**Neden ilk gün:** İnceleme 24–48 saat sürer; TestFlight + App Store erişimi buna bağlıdır.

1. Tarayıcıdan **<https://developer.apple.com/programs/enroll/>** adresine girin.
2. **PawDoc için adanmış bir iş Apple ID'si** ile giriş yapın (kişisel rastgele bir hesap değil). Hesapta **iki adımlı doğrulama (2FA)** açılmış olsun.
3. Giriş yaptıktan sonra **Entity Type** ekranında seçim yapın:
   - **Individual / Sole Proprietor** — en hızlı; satıcı olarak adınız görünür. D-U-N-S numarası gerekmez.
   - **Organization / Company** — şirketinizi satıcı olarak gösterir; **D-U-N-S numarası zorunlu** (Dun & Bradstreet'ten ücretsiz, birkaç gün sürebilir).
   > Solo kurucu için **Individual** en hızlı yoldur; sonradan Organization'a geçebilirsiniz.
4. Kişisel bilgileri girin, sözleşmeleri kabul edin.
5. **$99/yıl** ücreti ödeyin.
6. **"Welcome to the Apple Developer Program"** e-postasını bekleyin (24–48 saat).
7. Onay geldiğinde aşağıdakileri bir not defterine kaydedin (Blok I'da kullanılacak):
   - **Team ID** → App Store Connect → sağ üstteki hesap menüsü → **Membership Details** içinde
   - Hesabın sahibi Apple ID e-postası
   - Seçtiğiniz entity tipi (Individual / Organization)

> **App Store Connect API anahtarı (`.p8`)** Fastlane için Blok I'da üretilecek; şimdi üretmeyin.

### A.2 — Google Play Developer

**Neden ilk gün:** Kimlik doğrulaması 1–3 gün sürebilir. Sağlık uygulamaları ek kontrole tabidir.

1. **<https://play.google.com/console/signup>** adresine girin.
2. **PawDoc için adanmış bir Google hesabı** ile giriş yapın. 2FA aktif olsun.
3. Hesap türü:
   - **Personal** — solo kurucu için en hızlı.
   - **Organization** — D-U-N-S numarası gerekir; geliştirici olarak şirketi gösterir.
4. **Developer name** alanına store'da görünecek adı yazın (sonradan değiştirmek karmaşıktır — Apple satıcı adıyla tutarlı seçin).
5. **$25 tek seferlik** kayıt ücretini ödeyin.
6. **Identity verification**: hükümet kimliği + adres talep edilir; doldurun ve gönderin.
7. Onayı bekleyin (1–3 gün). Statüsü `pending` iken Bloklar B–E'ye geçebilirsiniz.

### A.3 — Domain ve Cloudflare DNS

> `pawdoc.app` zaten Cloudflare'a delege edilmiştir (runbook 03). Yalnızca **doğrulama**.

```bash
dig NS pawdoc.app +short
# Beklenen:
#   mark.ns.cloudflare.com.
#   ivy.ns.cloudflare.com.
```

`*.ns.cloudflare.com` görüyorsanız tamamdır. Apex `A` kaydı şu an boş olmalı (henüz yayın yok). Sonradan eklenecek kayıtlar (web landing, MX/SPF/DKIM/DMARC, `terms`/`privacy`, `blog`, `check`) Blok H + J'de yazılacaktır.

Cloudflare hesabınızda:
- **2FA** aktif olduğundan emin olun.
- Registrar'da **domain auto-renew** açık olsun (marka kaybetmeyin).

### A.4 — D-U-N-S Numarası (yalnızca Organization seçtiyseniz)

1. **<https://www.dnb.com/duns-number/get-a-duns.html>** üzerinden ücretsiz başvurun.
2. Doğrulama 1–14 gün sürebilir; Apple ve Google onayı buna bağlı.

---

## Blok B — Sır Yönetimi Omurgası: Doppler + GitHub PAT

> Bu adım **bütün diğer adımların önünde** durur. Tüm anahtarları Doppler'a koyacağız; sonra Doppler'dan diğer platformlara akıtacağız.

### B.1 — Doppler Hesabı + CLI

1. **<https://dashboard.doppler.com>** adresine gidip ücretsiz hesap açın. 2FA açın.
2. Yerel makinenizde `doppler` CLI olduğundan emin olun:
   ```bash
   doppler --version   # v3.x bekleniyor
   ```
   Yoksa kurulum: <https://docs.doppler.com/docs/install-cli>
   - macOS: `brew install dopplerhq/cli/doppler`
   - Linux (resmi script):
     ```bash
     (curl -Ls --tlsv1.2 --proto "=https" --retry 3 https://cli.doppler.com/install.sh || wget -t 3 -qO- https://cli.doppler.com/install.sh) | sudo sh
     ```
3. CLI'ı tarayıcı üzerinden yetkilendirin (interaktif):
   ```bash
   doppler login
   ```

### B.2 — `pawdoc` Projesini ve Tüm Sır Slot'larını Oluşturma

Repo kökünde, hazır bootstrap script'ini çalıştırın:

```bash
cd /home/emre/Downloads/PawDoc
./scripts/doppler-bootstrap.sh
```

Bu script şunları yapar (idempotent ve non-destructive — gerçek değerlere dokunmaz):
- `pawdoc` projesini oluşturur
- `dev` ve `prd` config'lerini oluşturur (production'ın Doppler'daki adı `prd`'dir)
- Faz 0.1 omurgasındaki tüm sır slot'larını **placeholder** ile (`SET_IN_PHASE_0.2`) doldurur

Doğrulama:
```bash
doppler secrets --project pawdoc --config dev
doppler secrets --project pawdoc --config prd
./scripts/verify-phase-0.1.sh
```

### B.3 — Doppler Service Token (CI/Fly için)

Doppler dashboard'unda:

1. **Projects** → `pawdoc` → `prd` config'e tıklayın.
2. **Access** sekmesi → **Service Tokens** → **Generate**.
3. Read-only olarak üretin. Çıkan token tek seferde gösterilir, **hemen kopyalayın**.
4. Bu token Blok D'de GitHub Actions ve Fly.io'ya **`DOPPLER_TOKEN`** olarak yapıştırılacak.

### B.4 — GitHub Personal Access Token (yalnızca branch protection için)

> Tek seferlik kullanımdır; sırların CI üzerinden okunması için **kullanılmaz** (onun yerine `DOPPLER_TOKEN` gider).

1. **<https://github.com/settings/tokens>** → **Fine-grained tokens** → **Generate new token**.
2. Repository access: `emredogan-cloud/PawDoc` seçin.
3. Permissions: **Administration → Read and write**.
4. Üretin ve kopyalayın. Yerel shell'de:
   ```bash
   export GH_TOKEN="ghp_..."   # geçici, oturum içi
   ./scripts/github-branch-protection.sh
   ```
   Bu script, `main` branch'ine korumayı uygular (linear history + required status checks + required reviews).

> Token'ı `~/.bashrc`'ye **yazmayın** — tek seferlik kullanın, terminali kapatın.

### B.5 — Supabase Management Access Token

1. **<https://supabase.com/dashboard/account/tokens>** → **Generate new token**.
2. Adı: `pawdoc-cli`.
3. `sbp_…` ile başlayan token'ı kopyalayın.
4. Hem yerel shell'e hem Doppler'a kaydedin:
   ```bash
   export SUPABASE_ACCESS_TOKEN="sbp_..."
   doppler secrets set SUPABASE_ACCESS_TOKEN="sbp_..." --project pawdoc --config prd
   ```

---

## Blok C — Backend Servis Hesapları ve Anahtarlar

> Buradan itibaren her adım: hesabı açın → API anahtarını üretin → **Doppler'a koyun**. Doppler doğrulayacak son durağımızdır; oradan Blok D'de hedef platformlara dağıtım yapılır.

> **Konvansiyon:** Hassas (`🔒`) işaretli anahtarlar yalnızca `prd` config'e konur (production); aynı zamanda `dev` config'e dev-projesi karşılığı eklenir. Doppler'da yazma kalıbı:
> ```bash
> doppler secrets set <KEY>="<VALUE>" --project pawdoc --config <dev|prd>
> ```

### C.1 — Supabase: Dev + Prod + EU Projeleri

1. **<https://supabase.com/dashboard>** → **New project**.
2. **Üç ayrı proje** oluşturun. Her birinde **DB password** alanına güçlü bir parola girin ve **muhafaza edin** (Supabase yalnızca bir kez gösterir).

| Proje Adı | Region | Amaç |
|---|---|---|
| `pawdoc-dev` | size en yakın region | geliştirme |
| `pawdoc-prod` | son kullanıcılara yakın (örn. `us-east-1`) | üretim |
| `pawdoc-eu` | **`eu-central-1` (Frankfurt)** | GDPR / AB veri ikametgâhı |

3. Her projenin **20 karakterlik `project_ref`** değerini bir not defterine kaydedin. Bunu dashboard URL'sinden okuyabilirsiniz: `https://supabase.com/dashboard/project/<ref>`.

4. **Extensions** (uuid-ossp + vector) etkinleştirin. En hızlısı script:
   ```bash
   export SUPABASE_ACCESS_TOKEN="<sbp_...>"
   ./scripts/supabase-enable-extensions.sh <dev-ref> <prod-ref> <eu-ref>
   ```
   Alternatif: Dashboard → **Database → Extensions** → `uuid-ossp` ve `vector` açın.

5. Her projenin **Settings → API** sayfasından dört değeri Doppler'a koyun:

   ```bash
   # DEV
   doppler secrets set SUPABASE_URL="https://<dev-ref>.supabase.co"                  --project pawdoc --config dev
   doppler secrets set SUPABASE_ANON_KEY="<anon key>"                                --project pawdoc --config dev
   doppler secrets set SUPABASE_SERVICE_ROLE_KEY="<service_role key>"                --project pawdoc --config dev
   doppler secrets set SUPABASE_JWT_SECRET="<JWT secret>"                            --project pawdoc --config dev
   doppler secrets set SUPABASE_DB_URL="postgresql://postgres:<pw>@db.<dev-ref>.supabase.co:5432/postgres" --project pawdoc --config dev

   # PROD — aynı set, prod-ref ve prod parolasıyla
   doppler secrets set SUPABASE_URL="https://<prod-ref>.supabase.co"                 --project pawdoc --config prd
   doppler secrets set SUPABASE_ANON_KEY="<prod anon>"                               --project pawdoc --config prd
   doppler secrets set SUPABASE_SERVICE_ROLE_KEY="<prod service_role>"               --project pawdoc --config prd
   doppler secrets set SUPABASE_JWT_SECRET="<prod jwt secret>"                       --project pawdoc --config prd
   doppler secrets set SUPABASE_DB_URL="postgresql://postgres:<pw>@db.<prod-ref>.supabase.co:5432/postgres" --project pawdoc --config prd

   # EU — service_role anahtarı server-only kullanılır
   doppler secrets set SUPABASE_EU_URL="https://<eu-ref>.supabase.co"                --project pawdoc --config prd
   doppler secrets set SUPABASE_EU_ANON_KEY="<eu anon>"                              --project pawdoc --config prd
   doppler secrets set SUPABASE_EU_SERVICE_ROLE_KEY="<eu service_role>"              --project pawdoc --config prd
   ```

6. **Authentication → URL Configuration** (her üç projede):
   - **Site URL:** `https://pawdoc.app`
   - **Redirect URLs:** `pawdoc://login-callback` (mobil deep-link) + yerel geliştirme URL'leri.

> **Apple + Google OAuth provider konfigürasyonu** Blok C.5–C.6'da yapılacaktır.

> **PITR / Backup (CR #22):** Supabase Pro planında **Point-in-Time Recovery** açılır. Sağlık verisi sakladığımız için **önerilir**; karar size aittir, otomatik yapılmaz.

### C.2 — Anthropic Console (Claude Sonnet — Tier 3)

1. **<https://console.anthropic.com>** → giriş.
2. **Settings → API Keys** → **Create Key**.
3. `sk-ant-` ile başlayan anahtarı **tek seferde** kopyalayın.
4. Doppler:
   ```bash
   doppler secrets set ANTHROPIC_API_KEY="sk-ant-..." --project pawdoc --config dev
   doppler secrets set ANTHROPIC_API_KEY="sk-ant-..." --project pawdoc --config prd
   ```
5. **Billing alarm** ayarlayın (anonymous web checker + 6.1 ek personalization yüzünden trafik patlamasına karşı CR #5/#13).

### C.3 — Google AI Studio (Gemini — Tier 2)

1. **<https://aistudio.google.com/app/apikey>** → **Create API key**.
2. Üretilen anahtarı kopyalayın.
3. Doppler:
   ```bash
   doppler secrets set GOOGLE_AI_API_KEY="..." --project pawdoc --config dev
   doppler secrets set GOOGLE_AI_API_KEY="..." --project pawdoc --config prd
   ```

> Bu anahtar ayrıca **3.2 semantic cache embedding'leri** için de kullanılır — ekstra bir şey gerekmez.

### C.4 — Google Cloud Console: OAuth + Places API

#### C.4.a Google Sign-In OAuth Client

1. **<https://console.cloud.google.com>** → yeni proje (`pawdoc-prod`).
2. **APIs & Services → Credentials → Create credentials → OAuth client ID**.
3. Application type: **Web application**.
4. **Authorized redirect URIs**: her Supabase projesinin callback URL'ini ekleyin:
   ```
   https://<dev-ref>.supabase.co/auth/v1/callback
   https://<prod-ref>.supabase.co/auth/v1/callback
   https://<eu-ref>.supabase.co/auth/v1/callback
   ```
5. Client ID + Secret'ı Doppler'a koyun:
   ```bash
   doppler secrets set SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID="<client id>"     --project pawdoc --config prd
   doppler secrets set SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET="<secret>"            --project pawdoc --config prd
   # dev için de aynı set (dev-ref callback'i ekledikten sonra)
   ```
6. **Supabase dashboard** → her üç projede **Authentication → Providers → Google** → Client ID + Secret'ı yapıştırın → **Enable**.

#### C.4.b Google Places API

1. Aynı Google Cloud projesinde **APIs & Services → Library** → "Places API (New)" arayın → **Enable**.
2. **Credentials → Create credentials → API key** → bir anahtar üretin.
3. **API key restriction**: bu anahtarı yalnızca **Places API (New)** ile sınırlayın. Application restriction olarak `IP addresses` seçip Fly.io makinenin IP'sini ekleyin (Edge Function buradan değil ama Edge Function → ileride ek olarak da çıkarılabilir).
4. Doppler:
   ```bash
   doppler secrets set PLACES_API_KEY="..." --project pawdoc --config prd
   ```
5. **Billing alarm** ayarlayın (CR #12).

### C.5 — Apple Services ID (Sign in with Apple — Apple onayı geldikten sonra)

> Apple Developer onayı gelmeden bu adım yapılamaz. Onay gelince geri dönün.

1. **<https://developer.apple.com>** → **Certificates, Identifiers & Profiles → Identifiers**.
2. **+** → **Services IDs** → **Continue**.
3. **Description:** `PawDoc Sign In`, **Identifier:** `app.pawdoc.signin`.
4. **Continue → Register**.
5. Listeden bu Services ID'yi açın → **Sign In with Apple** kutusunu işaretleyin → **Configure**.
6. **Primary App ID:** `app.pawdoc` (mobil app id).
7. **Return URLs:** her Supabase projesinin callback URL'ini ekleyin.
8. **Save**.

Şimdi bir **Sign in with Apple key (`.p8`)** üretin:

1. **Keys → +** → **Sign in with Apple** kutusunu işaretleyin → **Configure** → Primary App ID `app.pawdoc`.
2. Anahtarı indirin (**`.p8` dosyası tek seferde indirilebilir**, kaybolmasın). **Key ID** ve **Team ID** notlarını alın.
3. Bu anahtar + Key ID + Team ID birleşimi, Apple Client Secret JWT'sini imzalamak için kullanılır. JWT'yi üretmek için Supabase'in Apple provider sayfasındaki yardımcıyı veya `apple-jwt-cli` benzeri bir tool'u kullanın.
4. Doppler:
   ```bash
   doppler secrets set SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID="app.pawdoc.signin"     --project pawdoc --config prd
   doppler secrets set SUPABASE_AUTH_EXTERNAL_APPLE_SECRET="<imzalanmış JWT>"          --project pawdoc --config prd
   ```
5. Supabase dashboard → **Authentication → Providers → Apple** → Services ID + Secret JWT yapıştırın → **Enable**.

### C.6 — Cloudflare R2 (resim/video object storage)

1. Cloudflare dashboard → **R2** → **Enable R2** (free tier için bile bir ödeme yöntemi gerekebilir).
2. Sağ paneldeki **Account ID**'yi not edin.
3. **Manage R2 API Tokens → Create API token** → Permissions: **Object Read & Write** → üretin.
   - **Access Key ID** ve **Secret Access Key** (tek seferde gösterilir) — hemen kopyalayın.
4. Doppler:
   ```bash
   doppler secrets set R2_ACCOUNT_ID="<account id>"                                 --project pawdoc --config dev
   doppler secrets set R2_ACCESS_KEY_ID="<access key id>"                           --project pawdoc --config dev
   doppler secrets set R2_SECRET_ACCESS_KEY="<secret>"                              --project pawdoc --config dev
   doppler secrets set R2_ENDPOINT="https://<account id>.r2.cloudflarestorage.com"  --project pawdoc --config dev
   doppler secrets set R2_BUCKET_DEV="pawdoc-uploads-dev"                           --project pawdoc --config dev
   doppler secrets set R2_BUCKET_PROD="pawdoc-uploads-prod"                         --project pawdoc --config dev
   # prd için ayrı bir R2 token üretmek istiyorsanız aynı kalıp; aksi halde dev token'ı --config prd'ye de set edin
   ```
5. Bucket'ları + CORS politikasını oluşturun:
   ```bash
   doppler run --project pawdoc --config dev -- ./scripts/r2-bootstrap.sh
   ```
   Script `pawdoc-uploads-dev` + `pawdoc-uploads-prod` bucket'larını oluşturur ve `infra/r2-cors.json`'ı uygular (origins: `pawdoc.app` + localhost; methods GET/PUT/HEAD).
6. Tarayıcıdan preflight doğrulaması yapın (terminal `curl` yeterli değildir):
   ```js
   fetch("https://<account-id>.r2.cloudflarestorage.com/pawdoc-uploads-dev/probe",
     { method: "OPTIONS" }).then(r => console.log([...r.headers]))
   ```
   `access-control-allow-origin` header'ı görmelisiniz.

> **R2 yazma anahtarları client'a asla gönderilmez.** Client'lar `generate-upload-url` Edge Function aracılığıyla kısa ömürlü presigned PUT URL'leri alır (CR #6).

### C.7 — Cloudflare Turnstile (web checker bot blok)

1. Cloudflare dashboard → **Turnstile** → **Add site**.
2. Domain: `pawdoc.app`. Widget mode: **Managed** (önerilen) veya **Invisible**.
3. İki anahtar üretilir:
   - **Site key** (public) → ileride Cloudflare Pages env'e konacak.
   - **Secret key** (private) → Edge Function'a konacak.
4. Doppler:
   ```bash
   doppler secrets set NEXT_PUBLIC_TURNSTILE_SITE_KEY="<site key>"  --project pawdoc --config prd
   doppler secrets set TURNSTILE_SECRET_KEY="<secret key>"          --project pawdoc --config prd
   ```

### C.8 — Upstash Redis (sonuç önbelleği + IP rate limit)

1. **<https://console.upstash.com>** → ücretsiz hesap.
2. **Create Database** → Region: Fly bölgenize en yakın (`iad`/`fra`/`sin` …) → **Create**.
3. Database detay sayfasında **REST API** sekmesi → **UPSTASH_REDIS_REST_URL** + **UPSTASH_REDIS_REST_TOKEN** kopyalanır.
4. Doppler:
   ```bash
   doppler secrets set UPSTASH_REDIS_REST_URL="https://...upstash.io"   --project pawdoc --config prd
   doppler secrets set UPSTASH_REDIS_REST_TOKEN="..."                    --project pawdoc --config prd
   ```

> Upstash hem **AI sonuç önbelleği** hem de **dynamic kill-switch** (`pawdoc:ai_kill_switch=1` → AI çağrılarını kapatır, redeploy gerekmez) hem de **anonymous web checker IP rate limit (3/IP/24h, fail-closed)** için kullanılır.

### C.9 — Fly.io (AI Service compute)

1. **<https://fly.io>** → hesap açın, ödeme yöntemi ekleyin (ücretsiz tier var ama bir kart gerekiyor).
2. CLI yetkilendirme (interaktif):
   ```bash
   fly auth login
   ```
3. CI/CD için non-interactive token üretin:
   ```bash
   fly tokens create deploy
   ```
   Çıktıyı kopyalayın:
   ```bash
   doppler secrets set FLY_API_TOKEN="..." --project pawdoc --config prd
   ```

> Asıl `fly deploy` Blok G'de yapılacak. Burada yalnızca hesap + token.

### C.10 — OpenAI (Phase 5.3 AI Health Journal)

1. **<https://platform.openai.com>** → hesap → **API Keys** → **Create new secret key**.
2. `sk-…` ile başlayan anahtarı kopyalayın.
3. Doppler:
   ```bash
   doppler secrets set OPENAI_API_KEY="sk-..." --project pawdoc --config prd
   ```
4. **Billing limit** ayarlayın (default model `gpt-4o-mini` — haftalık pet başına çok ucuz, ama yine de bir tavan koyun).

### C.11 — Resend (Phase 6.3.1 Family invite e-posta)

1. **<https://resend.com>** → hesap → DNS'e SPF/DKIM kaydı ekleyin (alan adı doğrulama; Cloudflare DNS'te yapılır).
2. **API Keys → Create API Key** → kopyalayın.
3. Doppler:
   ```bash
   doppler secrets set RESEND_API_KEY="re_..."                            --project pawdoc --config prd
   doppler secrets set RESEND_FROM="PawDoc <noreply@pawdoc.app>"          --project pawdoc --config prd
   doppler secrets set INVITE_LINK_BASE_URL="https://pawdoc.app/invite"   --project pawdoc --config prd
   ```

> `RESEND_API_KEY` opsiyoneldir — boş bırakırsanız `/invite-family-member` Edge Function magic link'i yine üretir ve response body'de döner; uygulama "Linki kopyala / paylaş" UX'ine düşer.

### C.12 — RevenueCat (Phase 1.4 abonelikler + Phase 6.3 PDF add-on + Phase 5.4 B2B-Lite)

1. **<https://app.revenuecat.com>** → **Create new project** → adı `PawDoc`.
2. Project → **Apps** → iki platform ekleyin:
   - Apple App Store → Bundle ID `app.pawdoc`
   - Google Play → Package name `app.pawdoc`
3. Apple app config alanı **App Store Connect shared secret / in-app purchase key** ister — bu Apple Developer onayı geldikten sonra eklenir (Blok C.5 sonrası).
4. **API keys** sayfasında üretilen anahtarlar:
   - **Secret API key** (server-side) → Doppler `prd`.
   - **Public SDK key (iOS)** → mobil build için.
   - **Public SDK key (Android)** → mobil build için.
   - **Webhook authorization secret** — kendi belirlediğiniz bir değer (örn. 64 byte rastgele).
5. Doppler:
   ```bash
   doppler secrets set REVENUECAT_API_KEY="..."                           --project pawdoc --config prd
   doppler secrets set REVENUECAT_WEBHOOK_SECRET="<webhook secret>"        --project pawdoc --config prd
   doppler secrets set REVENUECAT_PUBLIC_SDK_KEY_IOS="<ios public key>"    --project pawdoc --config prd
   doppler secrets set REVENUECAT_PUBLIC_SDK_KEY_ANDROID="<android pub>"   --project pawdoc --config prd
   ```
6. **Ürünleri Blok J'de** (App Store Connect + Play Console store entry'leri açıldıktan sonra) yaratacaksınız:
   - **Monthly subscription** (`premium_monthly`, $9.99/ay)
   - **Annual subscription** (`premium_annual`, $79.99/yıl)
   - **Family subscription** (`family_monthly`, $24.99/ay) — entitlement_id: `family`
   - **B2B-Lite** (`b2b_lite_monthly`, $19.99/ay) — entitlement_id: `b2b_lite`
   - **PDF Report consumable** (`pdf_report_addon`, $4.99 / consumable veya non-consumable)

### C.13 — OneSignal (Phase 2.1 + Phase 3.3 P2 push)

1. **<https://onesignal.com>** → hesap → **New App/Website** → name `PawDoc`.
2. **App ID**'yi kopyalayın → Doppler:
   ```bash
   doppler secrets set ONESIGNAL_APP_ID="<app id>" --project pawdoc --config prd
   ```
3. **Settings → Keys & IDs → REST API Key** → Doppler:
   ```bash
   doppler secrets set ONESIGNAL_REST_API_KEY="..." --project pawdoc --config prd
   ```
4. **APNs** (iOS) ve **FCM/Firebase** (Android) credential'larını OneSignal dashboard'da konfigüre edin:
   - APNs: Apple Developer → Keys → **Apple Push Notifications service** (`.p8`) anahtarı üretin → OneSignal'a yükleyin.
   - FCM: Firebase Console → Project Settings → **Service Accounts** → JSON indirin → OneSignal'a yükleyin.

### C.14 — Sentry (crash/error reporting)

1. **<https://sentry.io>** → hesap → **Create project** → platform **Flutter**.
2. **Settings → Client Keys (DSN)** → DSN'yi kopyalayın.
3. Doppler:
   ```bash
   doppler secrets set SENTRY_DSN="https://...@sentry.io/..." --project pawdoc --config prd
   ```

### C.15 — PostHog (product analytics)

> Roadmap "self-hosted on Fly" diyordu; **CR #18 önerisi PostHog Cloud (free tier yeterli, operasyonel yük yok)**. Aşağıda Cloud yolu.

1. **<https://app.posthog.com>** → hesap → project.
2. **Project Settings → Project API Key** → kopyalayın.
3. Doppler:
   ```bash
   doppler secrets set POSTHOG_API_KEY="phc_..."                  --project pawdoc --config prd
   doppler secrets set POSTHOG_HOST="https://us.i.posthog.com"     --project pawdoc --config prd
   ```

### C.16 — Better Uptime (opsiyonel monitör)

1. **<https://betteruptime.com>** → hesap.
2. **Monitors → Add monitor** → şu URL'leri ekleyin:
   - `https://pawdoc-ai.fly.dev/health` (deploy sonrası)
   - Her Supabase projesinin health URL'i
   - `https://pawdoc.app` ve `/check`
3. On-call alert: e-posta veya SMS aktif edin.

### C.17 — App Store Connect Shared Secret + RevenueCat bağlantısı

Apple onayı gelince RevenueCat'te bağlamak için:
1. **App Store Connect** → My Apps → (henüz uygulama eklenmediyse Blok J'de eklenecek; şimdilik bir entitlement key gerekiyorsa **Users and Access → Integrations → In-App Purchase Key**).
2. **In-App Purchase Key** üretin → indirin (`.p8`).
3. RevenueCat → **Apple project settings → App-specific shared secret / In-app purchase key** → yapıştırın.

---

## Blok D — Sırların Hedef Platformlara Aktarımı

> Tüm değerler Doppler'da. Şimdi her hedef platform için "Doppler nasıl bağlanır veya sırlar nasıl set edilir" tarif ediliyor.

### D.1 — Doppler ↔ GitHub Actions Entegrasyonu

> CI runner'larının her açılışta Doppler'dan sır çekmesi için.

1. Doppler dashboard → **Projects → pawdoc → prd → Sync** sekmesi.
2. **Add Sync → GitHub Actions** seçin.
3. Authorize → repo `emredogan-cloud/PawDoc`'u seçin.
4. **Save sync**. Bundan sonra Doppler'a yazdığınız her şey otomatik olarak GitHub Actions repo secret'larına yansır.

Alternatif (manuel): GitHub → **Settings → Secrets and variables → Actions → New repository secret** → her secret'ı tek tek girin.

**CI/CD özel build-time sırları** (Doppler ile değil, doğrudan GitHub Actions'a):
- `FLY_API_TOKEN`
- `MATCH_PASSWORD`, `MATCH_GIT_URL`, `MATCH_GIT_BASIC_AUTHORIZATION`
- `APP_STORE_CONNECT_API_KEY_KEY_ID`, `_ISSUER_ID`, `_KEY`
- `GOOGLE_PLAY_JSON_KEY_FILE`
- `FASTLANE_APPLE_ID`, `APPLE_DEVELOPER_TEAM_ID`

Bunlar runtime değil **build-time** sırlardır. Blok I'da Fastlane setup'ında üretilirler.

### D.2 — Fly.io Secrets (AI Service)

`pawdoc-ai` uygulaması için (`ai-service/fly.toml` ile create edildikten sonra):

```bash
cd ai-service

# Phase 1.3 — Tier 2/Tier 3
doppler run --project pawdoc --config prd -- \
  fly secrets set \
    ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
    GOOGLE_AI_API_KEY="$GOOGLE_AI_API_KEY"

# Phase 1.3 — opsiyonel cache + kill-switch
doppler run --project pawdoc --config prd -- \
  fly secrets set \
    UPSTASH_REDIS_REST_URL="$UPSTASH_REDIS_REST_URL" \
    UPSTASH_REDIS_REST_TOKEN="$UPSTASH_REDIS_REST_TOKEN"

# Phase 5.3 — Health Journal
doppler run --project pawdoc --config prd -- \
  fly secrets set OPENAI_API_KEY="$OPENAI_API_KEY"
```

### D.3 — Supabase Edge Function Secrets

Edge Function'lar **kendi sır setlerine** ihtiyaç duyar. Her function için ayrı set edilir:

```bash
# /analyze — Tier ayarları + AI service URL
supabase secrets set \
  AI_SERVICE_URL="https://pawdoc-ai.fly.dev" \
  --project-ref <prod-ref>

# /generate-upload-url — R2 yazma anahtarları
supabase secrets set \
  R2_ACCOUNT_ID="$R2_ACCOUNT_ID" \
  R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  R2_BUCKET="pawdoc-uploads-prod" \
  --project-ref <prod-ref>

# /analyze (resim presign için aynı R2 anahtarları)
supabase secrets set \
  R2_ACCOUNT_ID="$R2_ACCOUNT_ID" \
  R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  R2_BUCKET="pawdoc-uploads-prod" \
  --project-ref <prod-ref>

# /auth-webhook — signature secret (CR #21)
supabase secrets set SUPABASE_AUTH_WEBHOOK_SECRET="v1,whsec_..." --project-ref <prod-ref>

# /revenuecat-webhook — authorization secret (CR #21)
supabase secrets set REVENUECAT_WEBHOOK_SECRET="$REVENUECAT_WEBHOOK_SECRET" --project-ref <prod-ref>

# /process-reminders — Phase 3.3 P2 cron secret + OneSignal
supabase secrets set \
  CRON_SECRET="$(openssl rand -hex 32)" \
  ONESIGNAL_APP_ID="$ONESIGNAL_APP_ID" \
  ONESIGNAL_REST_API_KEY="$ONESIGNAL_REST_API_KEY" \
  --project-ref <prod-ref>
# !! CRON_SECRET değerini bir yere not edin — birazdan Supabase Vault'a da yazacaksınız.

# /generate-journals — aynı CRON_SECRET'ı kullanır (yukarıda set edildiyse yeterli)
# Henüz set edilmediyse:
supabase secrets set CRON_SECRET="<above value>" --project-ref <prod-ref>

# /find-vets — Google Places (CR #12)
supabase secrets set PLACES_API_KEY="$PLACES_API_KEY" --project-ref <prod-ref>

# /analyze-anonymous — Turnstile + Upstash (fail-closed)
supabase secrets set \
  TURNSTILE_SECRET_KEY="$TURNSTILE_SECRET_KEY" \
  UPSTASH_REDIS_REST_URL="$UPSTASH_REDIS_REST_URL" \
  UPSTASH_REDIS_REST_TOKEN="$UPSTASH_REDIS_REST_TOKEN" \
  --project-ref <prod-ref>

# /invite-family-member — Resend (Phase 6.3.1)
supabase secrets set \
  RESEND_API_KEY="$RESEND_API_KEY" \
  RESEND_FROM="$RESEND_FROM" \
  INVITE_LINK_BASE_URL="$INVITE_LINK_BASE_URL" \
  --project-ref <prod-ref>
```

> Komutları **`doppler run --project pawdoc --config prd -- <komut>`** ile sarmak en güvenlisidir — değerler env'e enjekte edilir, history'de açıkta kalmaz.

### D.4 — Supabase Vault (Phase 3.3 P2 + 5.3 cron için)

`pg_cron` + `pg_net` reminders ve journal cron'ları, **Supabase Vault**'tan project URL + cron secret'ı okur (git'e hiçbir şey commit etmemek için).

Supabase dashboard → **SQL Editor**:

```sql
-- 1) Vault'a project URL'ini yaz
select vault.create_secret('project_url', 'https://<prod-ref>.supabase.co');

-- 2) Vault'a cron secret'ı yaz (D.3'te /process-reminders'a set ettiğin DEĞERİN AYNISI)
select vault.create_secret('cron_secret', '<CRON_SECRET aynı değer>');
```

> Bu iki satır olmadan `/process-reminders` ve `/generate-journals` cron migration'ları çalışmaz; `pg_net` çağrısı 401 alır.

### D.5 — Cloudflare Pages Environment Variables (web)

> Web build Blok H'de yapılacak. Burada yalnızca env tarafı.

Cloudflare Pages dashboard → **Projects → (proje seçimi) → Settings → Environment variables**:

| Key | Tip | Değer |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Public, build-time | Supabase prod URL'i |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Public, build-time | Supabase prod anon key |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | Public, build-time | Turnstile **site** key (Cloudflare Turnstile sayfasından) |

> **Hiçbir `service_role` / `SECRET_KEY` Cloudflare Pages env'ine konmaz.** Yalnızca `NEXT_PUBLIC_*` prefix'li, tarayıcıya bundle edilecek public değerler.

### D.6 — GitHub Actions Repo Secrets (build/release)

GitHub → Settings → Secrets and variables → Actions:

| Secret | Kim okur? | Kaynak |
|---|---|---|
| `DOPPLER_TOKEN` | Tüm workflow'lar (Doppler sync için) | Doppler service token (B.3) |
| `FLY_API_TOKEN` | `deploy.yml` | `fly tokens create deploy` (C.9) |
| `MATCH_PASSWORD` | `release.yml` | Blok I — Fastlane match setup |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `release.yml` | Blok I |
| `APP_STORE_CONNECT_API_KEY_KEY_ID` | `release.yml` | Blok I |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | `release.yml` | Blok I |
| `APP_STORE_CONNECT_API_KEY_KEY` | `release.yml` | Blok I (`.p8` içeriği) |
| `GOOGLE_PLAY_JSON_KEY_FILE` | `release.yml` | Blok I (Play service account JSON) |
| `FASTLANE_APPLE_ID` | `release.yml` | Apple Developer email (A.1) |
| `APPLE_DEVELOPER_TEAM_ID` | `release.yml` | Apple Developer Team ID (A.1) |

### D.7 — Çevresel Değişken Akış Diyagramı (özet)

```
                  ┌────────────────────────┐
                  │       DOPPLER          │
                  │  (tek doğruluk kaynağı) │
                  └─────────────┬──────────┘
                                │
   ┌────────────────────┬───────┴───────┬────────────────────┐
   │                    │               │                    │
   ▼                    ▼               ▼                    ▼
GitHub Actions     Fly.io secrets  Supabase secrets    Cloudflare Pages
(CI/CD)            (AI service)    (per-function)      (build-time public)
                                       │
                                       ▼
                              Supabase Vault
                          (project_url + cron_secret)
```

Build-time `--dart-define` (mobil) Doppler'dan **lokal shell** üzerinden okunur:
```bash
doppler run --project pawdoc --config prd -- bash -c '
  flutter build apk --release \
    --dart-define=SUPABASE_URL=$SUPABASE_URL \
    --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
    --dart-define=SENTRY_DSN=$SENTRY_DSN \
    --dart-define=POSTHOG_API_KEY=$POSTHOG_API_KEY \
    --dart-define=POSTHOG_HOST=$POSTHOG_HOST \
    --dart-define=ONESIGNAL_APP_ID=$ONESIGNAL_APP_ID \
    --dart-define=REVENUECAT_PUBLIC_SDK_KEY=$REVENUECAT_PUBLIC_SDK_KEY_ANDROID \
    --dart-define=AIRVET_AFFILIATE_URL=$AIRVET_AFFILIATE_URL \
    --dart-define=PET_INSURANCE_AFFILIATE_URL=$PET_INSURANCE_AFFILIATE_URL
'
```

---

## Blok E — Veritabanı Migration ve Test Scriptleri

> Bu blok **kesin bir sıra ister**: önce extensions → schema → RLS, sonra her faza ait migration. Bütün migration'ları tek bir `supabase db push` ile uygulayabilirsiniz, ama önce Supabase CLI'ı projeye bağlamanız gerek.

### E.1 — Supabase CLI Setup ve Proje Bağlama

```bash
# CLI yüklü mü?
supabase --version   # v1.150+ beklenir
# Yüklü değilse: https://supabase.com/docs/guides/cli/getting-started

# Yetkilendirme (B.5'te alınan token):
export SUPABASE_ACCESS_TOKEN="sbp_..."

# Repo köküne git, dev projesine bağla:
cd /home/emre/Downloads/PawDoc
supabase link --project-ref <dev-ref>
# Veritabanı parolasını ister (C.1 sonunda kaydettiğin)
```

> Aynı `link` komutunu prod ve EU için **sırayla** çalıştırırsanız son link'lediğiniz aktif olur. Production'a push yapmadan önce mutlaka `supabase link --project-ref <prod-ref>` deyip doğrulayın.

### E.2 — Tüm Migration'ları Uygulama (canlı projede)

```bash
supabase db push --project-ref <dev-ref>
# Bu, supabase/migrations/ altındaki TÜM .sql dosyalarını sırayla uygular:
#   20260527000000_enable_extensions.sql
#   20260527010000_initial_schema.sql
#   20260527010001_rls_policies.sql
#   20260527020000_semantic_cache.sql
#   20260527030000_referrals.sql
#   20260527040000_reminders_engagement.sql
#   20260527040001_schedule_reminders_cron.sql       <-- pg_cron + pg_net + Vault gerekir
#   20260527050000_followup.sql
#   20260527070000_health_journals.sql
#   20260527070001_schedule_generate_journals_cron.sql  <-- pg_cron + Vault gerekir
#   20260528010000_b2b_lite.sql
#   20260528010001_b2b_lite_journal_eligibility.sql
#   20260528020000_accuracy_views.sql
#   20260528030000_family_sharing.sql                 <-- per-family-group RLS!
#   20260528030001_pdf_report_addon.sql
#   20260528040000_family_invites.sql
```

> **pg_cron + pg_net + Vault** gerektiren migration'lar **yalnızca yönetilen Supabase projesinde** çalışır (yerel Docker testlerimizde değil). D.4'te Vault'a `project_url` ve `cron_secret` yazılmış olmalıdır; aksi halde cron çağrısı 401 alır.

Prod projesine push (E.1'de tekrar link'leyin):
```bash
supabase link --project-ref <prod-ref>
supabase db push --project-ref <prod-ref>
```

EU projesi için aynı:
```bash
supabase link --project-ref <eu-ref>
supabase db push --project-ref <eu-ref>
```

### E.3 — Yerel Docker Test Script'leri (önce dev'de çalıştırın)

Bu script'ler **gerçek bir Postgres + pgvector container'ında** migration'ları + test SQL'lerini uygulayıp **doğrulama** yapar. Docker gerekir.

> Sıra:

```bash
# 1. RLS izolasyonu + Family Sharing + Family Invites — en kritik
./scripts/test-rls.sh

# 2. Referral fraud + transaction kontrolü
./scripts/test-referral.sh

# 3. Reminders + re-engagement
./scripts/test-reminders.sh

# 4. 72h follow-up eligibility
./scripts/test-followup.sh

# 5. Semantic cache (text-only, same-user, same-species)
./scripts/test-semantic-cache.sh

# 6. AI Health Journal eligibility + RLS + lockdown (B2B-Lite dahil)
./scripts/test-journals.sh

# 7. Accuracy views (FP/FN/TP/TN + lockdown)
./scripts/test-accuracy-views.sh
```

Hepsi **PASS** dönmelidir. Herhangi biri FAIL döndüyse migration'ı prod'a uygulamayın — önce diagnose edin.

### E.4 — Golden-Set AI Safety Eval (Phase 6.1)

```bash
ai-service/.venv/bin/python scripts/run-eval.py
# Beklenen: 12/12 PASS, FN-on-EMERGENCY=0
```

Bu script gerçek AI çağrısı yapmaz — pipeline'ı stub provider'larla çalıştırıp **EMERGENCY false-negative regression**'ını yakalar. Her büyük prompt değişikliğinden sonra çalıştırın.

### E.5 — Tüm Faz Verifier'larını Çalıştırma (opsiyonel, ama önerilir)

```bash
for f in scripts/verify-phase-*.sh; do
  echo "=== $f ==="
  bash "$f" || echo "[!!! $f failed]"
done
```

Hepsi yeşil olmalıdır. Bir tanesi FAIL döndüyse `/tmp/pawdoc_*.log` altındaki çıktıya bakın.

### E.6 — Email/Disclaimer Sınırı Doğrulaması

```bash
./scripts/verify-disclaimers.sh
```

`disclaimer_required` flag'inin **API tarafında zorlandığını** ve UI'da yalnızca okunduğunu doğrular. CR #16 — bu hiçbir zaman istemci tarafında kaldırılamaz.

---

## Blok F — Supabase Edge Functions Deploy

> 13 Edge Function var. Her birini ayrı deploy edin. Her birinin **kendi secret seti** D.3'te belirlendi.

### F.1 — Tek Tek Deploy

```bash
# Sıralama bağımlı değil ama mantıksal akış:
supabase functions deploy auth-webhook            --project-ref <prod-ref>
supabase functions deploy generate-upload-url     --project-ref <prod-ref>
supabase functions deploy analyze                 --project-ref <prod-ref>
supabase functions deploy revenuecat-webhook      --project-ref <prod-ref>
supabase functions deploy delete-account          --project-ref <prod-ref>
supabase functions deploy claim-referral          --project-ref <prod-ref>
supabase functions deploy process-reminders       --project-ref <prod-ref>
supabase functions deploy find-vets               --project-ref <prod-ref>
supabase functions deploy generate-journals       --project-ref <prod-ref>
supabase functions deploy analyze-anonymous       --project-ref <prod-ref>
supabase functions deploy generate-pdf-report     --project-ref <prod-ref>
supabase functions deploy invite-family-member    --project-ref <prod-ref>
supabase functions deploy accept-family-invite    --project-ref <prod-ref>
```

> `supabase/config.toml` her function için `verify_jwt = true/false` ayarını taşır. Deploy edildikten sonra Supabase dashboard → **Edge Functions → (function) → Settings**'te doğrulayın.

### F.2 — Webhook'ları Bağlama

#### Auth Webhook
1. Supabase dashboard → **Authentication → Hooks → Add hook**.
2. Event: **After user signup**.
3. URL: `https://<prod-ref>.supabase.co/functions/v1/auth-webhook`.
4. **Signing secret** üretin (`v1,whsec_...` formatında) → kopyalayın.
5. Kopyaladığınız değeri D.3'te set ettiğiniz `SUPABASE_AUTH_WEBHOOK_SECRET` ile **AYNI** yapın:
   ```bash
   supabase secrets set SUPABASE_AUTH_WEBHOOK_SECRET="v1,whsec_..." --project-ref <prod-ref>
   ```

#### RevenueCat Webhook
1. RevenueCat dashboard → **Integrations → Webhooks → New webhook**.
2. URL: `https://<prod-ref>.supabase.co/functions/v1/revenuecat-webhook`.
3. **Authorization header**: D.3'te set ettiğiniz `REVENUECAT_WEBHOOK_SECRET` ile aynı değeri yazın.
4. **Save**.

### F.3 — Deploy Doğrulaması

```bash
# Yetkili kullanıcı JWT'si olmadan 401 dönmeli (verify_jwt=true)
curl -i https://<prod-ref>.supabase.co/functions/v1/analyze
# 401 beklenir

# verify_jwt=false olanlar (auth-webhook, revenuecat-webhook, analyze-anonymous, generate-journals, process-reminders)
# kendi secret kontrolünü yapmadan 401/403 dönmeli — body yoksa 400.

# Sağlık kontrolü için anonim test:
curl -X POST https://<prod-ref>.supabase.co/functions/v1/analyze-anonymous \
  -H "content-type: application/json" \
  -d '{}'
# Beklenen: 503 temporarily_unavailable (Turnstile + Upstash henüz secret'ları yoksa fail-closed)
```

---

## Blok G — AI Service (Fly.io) Deploy

### G.1 — İlk Deploy

`fly.toml` zaten repo'da. Tek yapacağınız:

```bash
cd ai-service

# İlk kuruluş — mevcut fly.toml korunur:
fly launch --no-deploy --copy-config --name pawdoc-ai --region iad
# Eğer 'pawdoc-ai' alınmışsa, başka bir ad seçin ve fly.toml'da `app = ` değerini güncelleyin.
# --region: prod Supabase region'ınıza yakın olsun.

# Sırları set edin (D.2)
# Sonra deploy:
fly deploy
```

### G.2 — Doğrulama (always-warm)

```bash
curl https://pawdoc-ai.fly.dev/health
# {"status":"ok","service":"pawdoc-ai","version":"x.y.z"}

fly status
# 1 machine, started — auto-stopped DEĞİL olmalı

fly scale show
# count 1, NOT 0
```

`fly.toml` içinde `min_machines_running = 1` ve `auto_stop_machines = "off"` ile **soğuk start yoktur** — bu, EMERGENCY override + Tier 2/3 routing latency bütçesi (P95 < 10s) için zorunludur.

### G.3 — Live Inference Smoke Test

```bash
curl -X POST https://pawdoc-ai.fly.dev/analyze \
  -H 'content-type: application/json' \
  -d '{
    "input_type": "text",
    "text_description": "my dog had a seizure this morning",
    "pet": {"species": "dog", "age_years": 5},
    "locale": "en"
  }'
# Beklenen: {"result": {"triage_level": "EMERGENCY", ...}, "meta": {"emergency_override_applied": true, "tier_used": 0, ...}}
# EMERGENCY override hardcoded — AI çağrısı yapılmadan EMERGENCY döner (latency çok kısa olmalı).
```

### G.4 — Edge Function `/analyze` → AI Service Bağlantısı

D.3'te zaten set edildi:
```bash
supabase secrets set AI_SERVICE_URL="https://pawdoc-ai.fly.dev" --project-ref <prod-ref>
```

> Edge analyze artık AI service'i çağırır; client'a `meta.tier_used` ve `meta.model_used` döner.

### G.5 — Dynamic Kill-Switch (CR #19)

Bir sorun yaşanırsa **AI çağrılarını redeploy etmeden** kapatmak için Upstash'a flag yazın:

```bash
curl -X POST "$UPSTASH_REDIS_REST_URL/set/pawdoc:ai_kill_switch/1" \
  -H "Authorization: Bearer $UPSTASH_REDIS_REST_TOKEN"
# Flag açıkken pipeline degraded MONITOR sonucu döner — sistem stable kalır.

# Kapatmak:
curl -X POST "$UPSTASH_REDIS_REST_URL/del/pawdoc:ai_kill_switch" \
  -H "Authorization: Bearer $UPSTASH_REDIS_REST_TOKEN"
```

---

## Blok H — Web (pawdoc.app/check ve marketing) Deploy

> Web `output: 'export'` ile static Next.js — Cloudflare Pages free tier'da host edilir.

### H.1 — Yerel Build

```bash
cd web
npm install
npm run build
# `out/` klasörü üretilir (static export)
```

### H.2 — Cloudflare Pages'e Bağlama

1. Cloudflare dashboard → **Workers & Pages → Create application → Pages → Connect to Git**.
2. **GitHub authorize** → `emredogan-cloud/PawDoc` repository'i seçin.
3. Branch: `main`. Root directory: `/web`.
4. Build command: `npm run build`. Output directory: `out`.
5. **Environment variables**: D.5'te listelenen 3 `NEXT_PUBLIC_*` değişkeni ekleyin.
6. **Save and Deploy**.
7. Cloudflare DNS → **pawdoc.app**'i Pages projesine bağlayın (Custom domains).

### H.3 — Web Symptom Checker (Phase 5.2) Doğrulaması

1. `https://pawdoc.app/check` açılır.
2. Turnstile widget'ı görünür → bot olmadığınızı doğrular.
3. Forma `my dog had a seizure` girin → submit → **EMERGENCY** sonucu döner.
4. Aynı IP'den 3'ten fazla istek yaparsanız **429** rate limit dönmeli.

> Turnstile veya Upstash secret'ları yoksa Edge `/analyze-anonymous` fail-closed olur — 503 döner.

---

## Blok I — Mobil Build, Gerçek Cihazda Test ve Fastlane

### I.1 — Flutter SDK Doğrulaması

```bash
cd /home/emre/Downloads/PawDoc/mobile
flutter --version    # Flutter 3.41.x stable beklenir
flutter pub get      # tüm dependency'leri çeker + l10n dosyalarını üretir
flutter analyze      # No issues found
flutter test         # 91 tests pass
```

### I.2 — iOS Setup (macOS gerekir)

1. **Xcode** kurulu olsun (Mac App Store → en yeni stable).
2. **CocoaPods** kurulu olsun: `sudo gem install cocoapods`.
3. iOS bundle id'i set et:
   ```bash
   cd mobile/ios
   open Runner.xcworkspace
   ```
   Xcode → Runner project → **Signing & Capabilities**:
   - **Bundle Identifier:** `app.pawdoc`
   - **Team:** Apple Developer Team'inizi seçin (A.1).
   - **Capabilities**: `Sign in with Apple`, `Push Notifications`, `Associated Domains` (Universal Links — `applinks:pawdoc.app`), `In-App Purchase` aktif olsun.

4. **AASA** (Apple App Site Association) dosyasını web tarafında host edin:
   - `web/app/well-known/apple-app-site-association/route.ts` benzeri Next.js route'u ile veya doğrudan `web/out/.well-known/apple-app-site-association` statik dosyası ile:
     ```json
     {
       "applinks": {
         "apps": [],
         "details": [{
           "appID": "<TEAM_ID>.app.pawdoc",
           "paths": ["/invite/*", "/r/*"]
         }]
       }
     }
     ```
5. `Info.plist` → URL Types: `pawdoc` scheme zaten ekli olmalı (referral + invite deep-link için).

### I.3 — Android Setup

1. **Android Studio** kurulu olsun (veya yalnızca **Android command line tools** + JDK 17).
2. `mobile/android/app/build.gradle.kts`:
   - `applicationId = "app.pawdoc"`
   - `signingConfigs` üretim için release key'i ile doldurulur (Fastlane I.6'da set eder).
3. `AndroidManifest.xml` → intent-filter'lar:
   ```xml
   <!-- Custom scheme: pawdoc://invite/<token> -->
   <intent-filter>
     <action android:name="android.intent.action.VIEW" />
     <category android:name="android.intent.category.DEFAULT" />
     <category android:name="android.intent.category.BROWSABLE" />
     <data android:scheme="pawdoc" android:host="invite" />
   </intent-filter>
   <!-- Universal link: https://pawdoc.app/invite/<token> (autoVerify) -->
   <intent-filter android:autoVerify="true">
     <action android:name="android.intent.action.VIEW" />
     <category android:name="android.intent.category.DEFAULT" />
     <category android:name="android.intent.category.BROWSABLE" />
     <data android:scheme="https" android:host="pawdoc.app" android:pathPrefix="/invite/" />
   </intent-filter>
   ```
4. `web/out/.well-known/assetlinks.json` host edin:
   ```json
   [{
     "relation": ["delegate_permission/common.handle_all_urls"],
     "target": {
       "namespace": "android_app",
       "package_name": "app.pawdoc",
       "sha256_cert_fingerprints": ["<RELEASE_SHA256>"]
     }
   }]
   ```
   Release SHA256, Fastlane match release key'inden alınır.

### I.4 — Gerçek Cihaz Üzerinde Çalıştırma (dev modu)

```bash
cd mobile

# Doppler'dan envleri okuyup direkt çalıştırma
doppler run --project pawdoc --config dev -- bash -c '
  flutter run \
    --dart-define=SUPABASE_URL=$SUPABASE_URL \
    --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
    --dart-define=SENTRY_DSN=$SENTRY_DSN \
    --dart-define=POSTHOG_API_KEY=$POSTHOG_API_KEY \
    --dart-define=POSTHOG_HOST=$POSTHOG_HOST \
    --dart-define=ONESIGNAL_APP_ID=$ONESIGNAL_APP_ID \
    --dart-define=REVENUECAT_PUBLIC_SDK_KEY=$REVENUECAT_PUBLIC_SDK_KEY_IOS \
    --dart-define=AIRVET_AFFILIATE_URL=$AIRVET_AFFILIATE_URL \
    --dart-define=PET_INSURANCE_AFFILIATE_URL=$PET_INSURANCE_AFFILIATE_URL
'
```

> iOS için: bir USB kablosuyla iPhone'u Mac'e bağlayın, Mac'te ayarlardan **Developer mode**'u açın (iPhone → Settings → Privacy & Security → Developer Mode → ON, reboot). Flutter `iPhone XX` cihazını listeler.
>
> Android için: **USB debugging** açın (Developer options → USB debugging), cihazı kabloyla bağlayın, `adb devices` ile görünür olmalı.

### I.5 — Cihazda Doğrulama Akışı (Faz 1 — 6.3.1 hepsi tek seferde)

Cihazda şu test akışını yapın:

1. **Sign in with Apple** veya **Google** ile giriş.
2. Onboarding → pet bilgilerini girin (kedi/köpek + tavşan/kuş gibi exotic test'ler için en az 2 pet).
3. **Photo capture** → kameradan bir fotoğraf çekin → upload → analyze → sonucu görün.
4. **EMERGENCY override**: text input ile "my dog had a seizure" yazın → kırmızı emergency screen + acknowledgment gate açılmalı.
5. **DE locale testi**: cihaz dilini Almanca'ya alın → "Krampfanfall" içerikli analyze → EMERGENCY override yine tetiklenmeli.
6. **MONITOR + telehealth CTA**: bir analiz sonucu MONITOR olduğunda telehealth + insurance affiliate kartları görünür (env varsa).
7. **Paywall**: ücretsiz limiti tüketin → paywall açılmalı.
8. **Reminders**: bir reminder oluşturun → cron çalıştığında push gelmeli (cihaz fiziksel olmalı).
9. **Health Journal**: bir pet için **Premium tier + opt-in** → bir Pazar gecesi cron çalıştığında journal görünmeli.
10. **PDF Report**: `Health history → PDF` butonuna basın → premium ise PDF inmeli, free ise paywall.
11. **Family Sharing**: Family tier'a yükseltin → Home → menü → Family sharing → invite → magic link → ikinci cihazdan aç → join.
12. **Account deletion**: Home → menü → Delete account → DELETE yazın → tüm satırlar silinmeli (Supabase → Authentication → Users boş).

### I.6 — Fastlane Setup (TestFlight + Play Internal)

Apple Developer onayı geldikten sonra:

1. **App Store Connect API key** (`.p8`):
   - <https://appstoreconnect.apple.com> → **Users and Access → Integrations → App Store Connect API → Generate API Key**.
   - Role: **App Manager**.
   - Key ID + Issuer ID'yi not edin; `.p8` dosyasını **tek seferde** indirin.
   - GitHub Actions secret olarak:
     - `APP_STORE_CONNECT_API_KEY_KEY_ID` = Key ID
     - `APP_STORE_CONNECT_API_KEY_ISSUER_ID` = Issuer ID
     - `APP_STORE_CONNECT_API_KEY_KEY` = `.p8` dosyasının **ham içeriği**

2. **Fastlane match** (özel signing cert repo'su):
   - GitHub'da **boş ve PRIVATE** bir repo açın: `emredogan-cloud/pawdoc-certs`.
   - `fastlane/Matchfile`'a bu repo URL'sini `MATCH_GIT_URL` env değişkeniyle bildirin (zaten boş Matchfile var; değiştirin).
   - Lokalde bir kez cert üretin:
     ```bash
     cd mobile/ios   # Phase 1.1 sonrası ios klasörü ortaya çıkar
     export MATCH_PASSWORD="<güçlü-parola>"
     export MATCH_GIT_URL="https://github.com/emredogan-cloud/pawdoc-certs.git"
     export MATCH_GIT_BASIC_AUTHORIZATION=$(echo -n "<github-username>:<github-pat>" | base64)
     bundle install
     bundle exec fastlane match appstore
     ```
   - GitHub Actions secret olarak `MATCH_PASSWORD`, `MATCH_GIT_BASIC_AUTHORIZATION` ekleyin.

3. **Google Play service account**:
   - **<https://play.google.com/console>** → **Setup → API access** → Google Cloud projesini bağlayın → bir **service account** oluşturun.
   - Service account'a **Release manager** yetkisi verin.
   - JSON key'i indirin → GitHub Actions secret olarak `GOOGLE_PLAY_JSON_KEY_FILE` ekleyin (JSON içeriği).

4. **GitHub Actions secret'larını tamamlayın** (D.6 listesi).

### I.7 — Release Build Komutları

#### iOS (TestFlight)
```bash
cd mobile
flutter build ipa --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=SENTRY_DSN=$SENTRY_DSN \
  --dart-define=POSTHOG_API_KEY=$POSTHOG_API_KEY \
  --dart-define=POSTHOG_HOST=$POSTHOG_HOST \
  --dart-define=ONESIGNAL_APP_ID=$ONESIGNAL_APP_ID \
  --dart-define=REVENUECAT_PUBLIC_SDK_KEY=$REVENUECAT_PUBLIC_SDK_KEY_IOS \
  --dart-define=AIRVET_AFFILIATE_URL=$AIRVET_AFFILIATE_URL \
  --dart-define=PET_INSURANCE_AFFILIATE_URL=$PET_INSURANCE_AFFILIATE_URL

cd ios
bundle exec fastlane beta
```

#### Android (Play Internal Track)
```bash
flutter build appbundle --release \
  --dart-define=... # aynı tanımlar, REVENUECAT_PUBLIC_SDK_KEY_ANDROID
cd android
bundle exec fastlane play_internal
```

#### CI Üzerinden Otomatik (önerilen)

Bir git tag push edin:
```bash
git tag v1.0.0
git push origin v1.0.0
```

`release.yml` workflow'u çalışır, `beta` ve `play_internal` lane'lerini sırayla execute eder.

---

## Blok J — Manuel ve Yasal Süreçler (Yayın Kapısı)

> Bu liste **`docs/runbooks/18-legal-and-launch-gate.md`** dosyasının özetidir. Her madde halka açık çıkıştan önce **TAMAMLANMIŞ** olmalıdır.

### J.1 — Blokerler (Public availability açılmadan TAMAMLANMASI ZORUNLU)

- [ ] **E&O (Errors & Omissions) Sigortası** — en az $100K limit, **bound** (kuponu kesilmiş, geçerli). AI sağlık ürünleri için underwriting haftalar sürebilir; "information, not diagnosis" çerçevemizi soracaklar. **Erken başlayın** (Apple onayı beklerken de yapılabilir).
- [ ] **Avukat İnceleme + Onayı** — `docs/legal/terms-of-service.md` ve `docs/legal/privacy-policy.md` **şablondur**. ABD + AB (GDPR) consumer/health deneyimli bir avukat bunları finalize etmelidir. Her `[BRACKETED]` placeholder doldurulmalıdır.
- [ ] **CR #24 — Veteriner Pratik Hukuk İncelemesi (her ülke için)** — ABD'nin bazı eyaletlerinde VCPR (Veterinarian-Client-Patient Relationship) olmadan "veteriner tavsiyesi" vermek lisansiz uygulama sayılabilir. Avukatınız her açılacak pazar için "information & guidance, not diagnosis" çerçevesinin yeterli olduğunu onaylasın; ToS/UX metni ona göre güncellensin.
- [ ] **CR #9 — Veri Saklama Politikası Kararı** — Privacy Policy §6: ya (a) **silme üzerine tam erasure + tanımlı purge penceresi**, ya (b) **anonimleştirip sakla**. Kod şu an (a)'yı uyguluyor (ON DELETE CASCADE). Policy ile kodu hizalayın.

### J.2 — App Store Connect Kayıt + Submission

1. **<https://appstoreconnect.apple.com>** → **My Apps → +** → **New App**.
2. Platform: **iOS**. Name: `PawDoc`. Bundle ID: `app.pawdoc`. SKU: kendi seçtiğiniz.
3. **App Information**:
   - Category: **Health & Fitness** (or **Medical** — App Store Review katı). Önerilen: **Health & Fitness** + ToS/UX "information not diagnosis" çerçevesi.
   - **"Diagnosis"** kelimesini görsel açıklamada, reklam metinlerinde, screenshot'larda **KULLANMAYIN** — Phase 2.3 strict rule (`scripts/verify-disclaimers.sh` bunu kontrol eder).
4. **Pricing and Availability**: Free with in-app purchases.
5. **App Privacy** (Privacy Manifest): hangi verileri topladığınızı tam doldurun (Sağlık verisi, fotoğraf, konum — find vets için).
6. **In-App Purchases**: C.12'de planlanan tüm ürünleri burada **App Store Connect** üzerinden oluşturun ve RevenueCat'le bağlayın.
7. **App Review Information**: test hesabı, demo videosu — beta testçilerden ekran kayıtları toplayın.
8. **Build**: Fastlane ile yüklediğiniz TestFlight build'i seçin.
9. **Screenshots**: `docs/store_metadata/ios_app_store.md` sırasına göre 5 slot.
10. **Submit for Review**.

### J.3 — Google Play Console Kayıt + Submission

1. **<https://play.google.com/console>** → **All apps → Create app**.
2. App name: `PawDoc`. Default language: English (US). Free / Paid: **Free**. Declarations: Health.
3. **Set up your app** checklist:
   - **App access**: review için test login bilgileri sağlayın.
   - **Ads**: contains ads? Hayır.
   - **Content rating**: questionnaire'i doldurun (sağlık → 12+).
   - **Target audience**: 18+.
   - **News app**: Hayır.
   - **Health declaration**: Evet — "information & guidance, not diagnosis" copy'sini taşıyın.
4. **App content**:
   - Privacy Policy URL: `https://pawdoc.app/privacy`.
   - Data safety form: hangi verileri topladığınızı + dış aktarımları (Anthropic, Google AI, OpenAI) tam doldurun.
5. **Set pricing & distribution**: ülkeleri seçin.
6. **In-app products**: Play Console üzerinden ürünleri oluşturup RevenueCat'le bağlayın.
7. **App bundle**: Fastlane `play_internal` lane'i AAB'yi yükler. Internal → Closed → Open → Production yolu izlenir.
8. **Submit**.

### J.4 — Beta (Phase 2.3 / runbook 19)

- TestFlight'a **en az 50 internal/external tester** ekleyin.
- En az **1 hafta beta** çalıştırın.
- **Crash rate < 1%**, **app rating ≥ 4.0** kapısı geçilmeden public availability açılmaz.

### J.5 — Public Launch

**Tüm** J.1 blokerleri çözüldükten sonra:

1. App Store Connect → **Release** butonu.
2. Play Console → **Production track → Submit**.
3. Cloudflare DNS → `pawdoc.app` apex'i Pages'e bağlı, MX/SPF/DKIM/DMARC `support@pawdoc.app` için live, ToS/Privacy sayfaları erişilebilir.
4. RevenueCat'te ürünler **Live** flag'iyle açık.
5. Better Uptime monitor'ları **All green**.

---

## Blok K — Çıkıştan Sonra Operasyonel Rutinler

### K.1 — Haftalık (her Pazar)

- **AI Health Journal cron** Pazar 00:00 UTC çalışır. Pazartesi sabahı Supabase logs → `generate-journals` çıktısını gözden geçirin.
- **Outcome dataset export**:
  ```bash
  doppler run --project pawdoc --config prd -- \
    ai-service/.venv/bin/python scripts/export-training-dataset.py
  # /tmp/pawdoc-training-YYYYMMDD.jsonl üretilir.
  ```
- **False-Negative-Proxy satırlarını inceleyin** (stderr ile birlikte yazılır). Bunları `ai-service/tests/golden_set.json`'a yeni EMERGENCY case olarak ekleyin → Phase 6.1 safety eval canlı incident'lardan büyüsün.

### K.2 — Aylık

- **Anthropic + OpenAI + Google AI billing dashboard**'larını gözden geçirin. Spike olmuş mu?
- **RevenueCat charts** — MRR + churn + tier dağılımı.
- **PostHog funnels** — onboarding → first analysis → paywall → conversion.
- **Supabase Edge logs** — `analyze-anonymous` 429'lar, `process-reminders` cron başarıları, `generate-journals` skipped/written sayıları.

### K.3 — Acil Durum Playbook'ları

| Olay | İlk eylem |
|---|---|
| AI service çöktü / latency > 30s | `fly logs -a pawdoc-ai` + dynamic kill-switch aç (G.5). UI degraded MONITOR gösterir, sistem kararlı kalır. |
| Anthropic billing alarm tetiklendi | Kill-switch aç + Gemini tier-2-only mode'a düş (CR #5). |
| Cross-family RLS leak şüphesi | `./scripts/test-rls.sh` çalıştır + Supabase log'larında auth.uid + family_group_id kombinasyonlarını izleyin. |
| Negatif app review burst | PostHog event'lerini inceleyin, EMERGENCY false-negative pattern arayın, golden set'e ekleyin, eval'ı çalıştırın. |
| Çocuklara yönelik şikayet / yanlış-yaş hesabı | Apple/Google content rating'i gözden geçirin; gerekirse store listing'i güncelleyin. |

### K.4 — Sürüm Çıkarma (her yeni faz / büyük özellik için)

1. Branch'inizi `phase-X.Y-slug` formatında açın.
2. PR oluşturun, CI yeşil, en az 1 reviewer onayı (kendi başınıza geliştiriyorsanız "Ultrareview" kullanın).
3. `main`'e squash-merge.
4. Yeni bir git tag (`v1.x.0`) push edin → `release.yml` workflow'u TestFlight + Play Internal'a yükler.
5. Beta testçi grubuyla 3–5 gün doğrulama; sonra production'a release.

---

## Ekler: Tüm Çevresel Değişkenler ve Sırların Sahip Olduğu Yerler Matrisi

> Tek satır referans. **Detay için `/ENVIRONMENT_VARS.md`.**

| Değişken | Nerede saklanır | Hangi servis okur | Notlar |
|---|---|---|---|
| `SUPABASE_URL` | Doppler, `--dart-define` | Mobile, Web, Edge, AI service | public; RLS gates |
| `SUPABASE_ANON_KEY` | Doppler, `--dart-define`, Cloudflare Pages env | Mobile, Web | public |
| `SUPABASE_SERVICE_ROLE_KEY` 🔒 | Doppler, Fly env, Supabase function secret | AI service, Edge | bypass RLS — server-only |
| `SUPABASE_JWT_SECRET` 🔒 | Doppler, Fly env | AI service | JWT verify |
| `SUPABASE_DB_URL` 🔒 | Doppler | Local supabase CLI | migrations |
| `SUPABASE_EU_*` | Doppler `prd` | EU residency switch | future use |
| `ANTHROPIC_API_KEY` 🔒 | Doppler, Fly secrets | AI service | Tier 3 Claude |
| `GOOGLE_AI_API_KEY` 🔒 | Doppler, Fly secrets | AI service | Tier 2 Gemini + embeddings |
| `OPENAI_API_KEY` 🔒 | Doppler, Fly secrets | AI service | AI Health Journal |
| `OPENAI_MODEL` | Doppler, Fly secrets | AI service | default `gpt-4o-mini` |
| `R2_ACCOUNT_ID` | Doppler, Supabase function secrets | `generate-upload-url`, `analyze` | server-only |
| `R2_ACCESS_KEY_ID` 🔒 | Doppler, Supabase function secrets | aynı | server-only |
| `R2_SECRET_ACCESS_KEY` 🔒 | Doppler, Supabase function secrets | aynı | server-only |
| `R2_BUCKET` | Doppler, Supabase function secrets | aynı | `pawdoc-uploads-prod` |
| `UPSTASH_REDIS_REST_URL` 🔒 | Doppler, Fly secrets, Supabase secrets | AI service, `analyze-anonymous` | cache + rate-limit |
| `UPSTASH_REDIS_REST_TOKEN` 🔒 | Doppler, Fly secrets, Supabase secrets | aynı | auth |
| `CRON_SECRET` 🔒 | Doppler, Supabase function secrets, **Supabase Vault** | `process-reminders`, `generate-journals` | Vault değeri Edge değeriyle aynı olmalı |
| `ONESIGNAL_APP_ID` | Doppler, `--dart-define`, Supabase function secret | Mobile, `process-reminders` | public |
| `ONESIGNAL_REST_API_KEY` 🔒 | Doppler, Supabase function secret | `process-reminders` | server-only |
| `PLACES_API_KEY` 🔒 | Doppler, Supabase function secret | `find-vets` | API key kısıtlamalı |
| `TURNSTILE_SECRET_KEY` 🔒 | Doppler, Supabase function secret | `analyze-anonymous` | bot block |
| `NEXT_PUBLIC_TURNSTILE_SITE_KEY` | Doppler, Cloudflare Pages env | Web | public |
| `NEXT_PUBLIC_SUPABASE_URL` | Cloudflare Pages env | Web | build-time public |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Cloudflare Pages env | Web | build-time public |
| `SUPABASE_AUTH_WEBHOOK_SECRET` 🔒 | Doppler, Supabase function secret | `auth-webhook` | signature verify |
| `REVENUECAT_API_KEY` 🔒 | Doppler | Manual ops / future server calls | secret |
| `REVENUECAT_WEBHOOK_SECRET` 🔒 | Doppler, Supabase function secret | `revenuecat-webhook` | shared authz |
| `REVENUECAT_PUBLIC_SDK_KEY_IOS` | Doppler, `--dart-define` | Mobile iOS | public SDK |
| `REVENUECAT_PUBLIC_SDK_KEY_ANDROID` | Doppler, `--dart-define` | Mobile Android | public SDK |
| `SUPABASE_AUTH_EXTERNAL_APPLE_CLIENT_ID` | Doppler | Supabase dashboard config | Apple Services ID |
| `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET` 🔒 | Doppler | Supabase dashboard config | imzalı JWT |
| `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` | Doppler | Supabase dashboard config | OAuth client |
| `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` 🔒 | Doppler | Supabase dashboard config | OAuth secret |
| `RESEND_API_KEY` 🔒 | Doppler, Supabase function secret | `invite-family-member` | optional — fallback magic-link |
| `RESEND_FROM` | Doppler, Supabase function secret | `invite-family-member` | sender id |
| `INVITE_LINK_BASE_URL` | Doppler, Supabase function secret | `invite-family-member` | default `https://pawdoc.app/invite` |
| `AIRVET_AFFILIATE_URL` | Doppler, `--dart-define` | Mobile | self-hides if empty |
| `PET_INSURANCE_AFFILIATE_URL` | Doppler, `--dart-define` | Mobile | self-hides if empty |
| `SENTRY_DSN` | Doppler, `--dart-define`, Fly secrets | Mobile + AI service | crash report |
| `POSTHOG_API_KEY` | Doppler, `--dart-define` | Mobile | analytics |
| `POSTHOG_HOST` | Doppler, `--dart-define` | Mobile | `https://us.i.posthog.com` |
| `FLY_API_TOKEN` 🔒 | Doppler, GitHub Actions secret | CI `deploy.yml` | non-interactive deploy |
| `MATCH_PASSWORD` 🔒 | GitHub Actions secret | CI `release.yml` | cert decrypt |
| `MATCH_GIT_BASIC_AUTHORIZATION` 🔒 | GitHub Actions secret | CI `release.yml` | certs repo auth |
| `APP_STORE_CONNECT_API_KEY_*` 🔒 | GitHub Actions secret | CI `release.yml` | TestFlight upload |
| `GOOGLE_PLAY_JSON_KEY_FILE` 🔒 | GitHub Actions secret | CI `release.yml` | Play upload |
| `FASTLANE_APPLE_ID` | GitHub Actions secret | CI `release.yml` | Appfile |
| `APPLE_DEVELOPER_TEAM_ID` | GitHub Actions secret | CI `release.yml` | Appfile |
| `DOPPLER_TOKEN` 🔒 | GitHub Actions secret, Fly secret | CI sync | read-only |
| `SUPABASE_ACCESS_TOKEN` 🔒 | Local shell, Doppler | CLI / migrations | management API |

---

## Son Kontrol Listesi (Çıkıştan Önce)

- [ ] Apple Developer + Google Play onaylı
- [ ] Doppler tüm slot'larda gerçek değerler (no `SET_IN_PHASE_*` placeholder)
- [ ] Fly AI service `/health` → 200, single warm machine
- [ ] Supabase: 16 migration uygulandı (dev + prod + EU), tüm test-rls.sh PASS
- [ ] Tüm Edge Functions deploy edildi, webhook'lar bağlandı
- [ ] Vault: `project_url` + `cron_secret` yazıldı (Phase 3.3 P2 + 5.3 için)
- [ ] Cloudflare Pages: `pawdoc.app` ve `/check` canlı, AASA + assetlinks.json host edildi
- [ ] iOS TestFlight build yüklendi, dahili testten ≥4.0 rating
- [ ] Android Play Internal Track build yüklendi, hazır
- [ ] **E&O Insurance bound, attorney-reviewed ToS/Privacy live, CR #24 + CR #9 kararları belge ile**
- [ ] App Store + Play submission gönderildi, review onayı bekleniyor / alındı
- [ ] Better Uptime tüm monitor'lar **green**
- [ ] PostHog test event görüldü, Sentry test event görüldü

Bu listenin **tamamı tıklanmadan** halka açık çıkış yapılmaz.

---

🐾 **PawDoc Solo Founder Roadmap — Mühendislik tarafı tamam.** Bu rehberi adım adım takip ettiğinizde operasyonel altyapı da tamamlanmış olur. İyi şanslar.
