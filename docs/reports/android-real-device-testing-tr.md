# PawDoc — Android Gerçek Cihaz Test Rehberi

**Hazırlanma tarihi:** 2026-05-16
**Sprint durumu:** Faz 0 → Sprint B3 tamamlandı
**Amaç:** PawDoc'u kendi Android telefonunda elle, gerçek ağ koşullarında
test etmek. Bu döküman uzun bir mimari belgesi değildir — pratik bir
yürütme listesidir.

> Bu rehber yazılırken Android manifest eksik izinler vardı
> (`INTERNET`, `CAMERA`, `ACCESS_NETWORK_STATE`, `url_launcher`
> sorgu blokları) ve Gradle build Kotlin 1.6 yüzünden patlıyordu.
> Her ikisi de düzeltildi — `app-debug.apk` artık temiz biçimde
> derleniyor.

---

## 1. Kısa Genel Durum Özeti

**Şu ana kadar tamamlananlar (Phase 0 → Sprint B3):**

- **Phase 0**: Flutter mobil + Python AI servis + Supabase + Fly.io
  + CI iskeleti.
- **Phase 1A/B/C/D**: Veritabanı (RLS + pgTAP), AI orchestration
  (Tier-2 Gemini + Tier-3 Claude + emergency keyword override),
  mobil analyze akışı (kamera → upload → analiz → sonuç),
  RevenueCat + Sentry + OneSignal + Apple Sign-In.
- **Sprint A1/A2**: App Store uyumu, free-tier quota refund,
  paywall ToS/Privacy URL, Apple Sign-In production hazırlığı,
  PostHog event hierarchy, operasyonel runbook.
- **Sprint B1**: Bağlantı kopması/timeout/offline UX, upload
  retry güvenliği (storage key cache), orphan upload temizliği,
  yaşam döngüsü kurtarma.
- **Sprint B2**: Magic-byte ile dosya doğrulama, prompt-injection
  korumaları (`<OWNER_DESCRIPTION>` delimitre + sistem promptu),
  text uzunluk sınırı.
- **Sprint B3**: AI ton tutarlılığı (merkezi copy modülü),
  `/ready` endpoint, AI servisi prod başlangıç doğrulaması,
  Sentry breadcrumbs, compression OOM koruması, provider outage
  triage runbook.

**Sistem seviyesi:** Kapalı TestFlight beta için mühendislik
tarafı yeşil. Tüm Phase 1 launch blocker'lar kapandı.

**Test edilmeye hazır olanlar:** Auth (OTP), pet ekleme, foto
yükleme, AI analiz, paywall görünümü, offline davranış, emergency
override, retry güvenliği.

---

## 2. Android Telefonda İlk Çalıştırma

### 2.1 Telefonda hazırlık (1 kere)

1. **Geliştirici seçeneklerini aç**: Ayarlar → Telefon hakkında →
   Yapı numarasına 7 kez dokun.
2. **USB Hata Ayıklama**: Ayarlar → Sistem → Geliştirici
   seçenekleri → "USB Hata Ayıklama" → Açık.
3. **USB konfigürasyonu**: Telefonu kabloyla bağlayıp, USB modunu
   "Dosya transferi" yap.
4. İlk bağlantıda telefon "Bu bilgisayara güveniyor musun?" diye
   sorar → **Daima izin ver** seç.

### 2.2 Bilgisayarda doğrulama

```bash
cd /home/emre/Downloads/PawDoc/mobile
flutter doctor          # Android toolchain: ✓ olmalı
flutter devices         # Telefonun adı listede görünmeli
```

Beklenen çıktı (örnek):
```
22095RA98C (mobile) • jfzxugsgnnvsrsg6 • android-arm64 • Android 13 (API 33)
```

### 2.3 Uygulamayı çalıştır

`env/dev.json` dosyasını oluşturduktan sonra (bkz. §3):

```bash
cd /home/emre/Downloads/PawDoc/mobile
flutter run --dart-define-from-file=env/dev.json -d <device-id>
```

İlk derleme 2–4 dakika sürer (sonraki hot-reload'lar saniyeler).
APK telefona kurulur, otomatik açılır.

**Pratik kısayollar (terminal çalışırken):**
- `r` — hot reload
- `R` — hot restart
- `q` — durdur

---

## 3. Gerekli ENV Ayarları

`env/dev.json.example` dosyasını kopyala:

```bash
cp env/dev.json.example env/dev.json
```

Sonra aşağıdaki değerleri doldur. `env/dev.json` gitignore'da, yani
sırlar repo'ya gitmez.

### ZORUNLU (uygulama yoksa açılmaz / temel akış kırılır)

| Anahtar | Nereden | Notu |
|---------|---------|------|
| `SUPABASE_URL` | Supabase Cloud dev projesi | Telefonda `127.0.0.1` çalışmaz! Aşağıya bak. |
| `SUPABASE_ANON_KEY` | Supabase Dashboard → Settings → API | `eyJ...` ile başlayan uzun string |
| `APP_ENV` | Sabit | `dev` bırak |

### Supabase URL — kritik nokta

- **Yerel Supabase (CLI) kullanıyorsan:** Telefonun bilgisayara
  ulaşabilmesi için **bilgisayarın LAN IP'sini** kullan, `127.0.0.1`
  DEĞİL. Bu makinenin IP'si şu an: **`192.168.1.109`**.
  `env/dev.json` içine şöyle yaz:
  ```
  "SUPABASE_URL": "http://192.168.1.109:54321"
  ```
  Telefonun **aynı Wi-Fi ağında** olduğundan emin ol.

- **Supabase Cloud dev projesi kullanıyorsan:** Dashboard'daki
  HTTPS URL'i direkt yapıştır.

### OPSİYONEL (boş bırakılabilir; özellik devre dışı olur)

| Anahtar | Boş bırakırsan ne olur |
|---------|------------------------|
| `AI_SERVICE_URL` | Analyze akışı için gerekli; Fly.io dev deploy URL'i veya yerel `make ai-dev` URL'i |
| `SENTRY_DSN` | Hata raporlama kapanır (dev'de zaten gereksiz) |
| `POSTHOG_API_KEY` | Analytics no-op service'e düşer (B3'te test edildi) |
| `REVENUECAT_PUBLIC_KEY_ANDROID` | Paywall ekranı "abone olma yapılandırılmadı" der; restore çalışmaz |
| `ONESIGNAL_APP_ID` | Push notification yok (Phase 1 zaten kullanmıyor) |
| `APPLE_SIGN_IN_ENABLED` | Android'de zaten `false` kalmalı |
| `TOS_URL`, `PRIVACY_URL` | Default `https://pawdoc.app/terms` ve `/privacy` |

Minimum çalışan örnek:
```json
{
  "APP_ENV": "dev",
  "SUPABASE_URL": "http://192.168.1.109:54321",
  "SUPABASE_ANON_KEY": "eyJ...",
  "AI_SERVICE_URL": "http://192.168.1.109:8080",
  "POSTHOG_API_KEY": "",
  "POSTHOG_HOST": "https://eu.posthog.com",
  "APPLE_SIGN_IN_ENABLED": "false",
  "TOS_URL": "https://pawdoc.app/terms",
  "PRIVACY_URL": "https://pawdoc.app/privacy",
  "APP_VERSION": "0.1.0",
  "APP_BUILD": "local"
}
```

---

## 4. Gerçek Test Senaryoları

Her senaryo bağımsız bir checklist. Hot restart (`R`) ile başlangıç
durumuna dönebilirsin.

### ☐ A. Kayıt akışı (OTP)
1. Uygulamayı aç → e-posta giriş ekranı.
2. Geçerli bir e-posta yaz → "Code Sent" ekranına geçişi gör.
3. Yerel Supabase kullanıyorsan: **Mailpit** (`http://127.0.0.1:54324`)
   üzerinde gelen OTP kodunu al.
4. Kodu gir → home ekranına yönlendirme.

### ☐ B. Pet oluştur
1. Home → "Add a pet".
2. Onboarding 4 adımı: species → name → birthDate (opsiyonel) → submit.
3. Pet listesinde yeni kartı gör.

### ☐ C. Foto yükleme + analiz
1. Pet kartından "Check on <name>" → analyze capture ekranı.
2. "Take photo" → kamera açılır (ilk seferde izin sor).
3. Foto çek → ekranda önizleme.
4. (Opsiyonel) "What did you notice?" alanına metin gir.
5. "Analyze" → loading ekranı → result ekranı (EMERGENCY / MONITOR
   / NORMAL).

**Beklenti:** ~5–15 saniye toplam latency. Result'ta `tier_used`
metadata'sını Sentry / log'lardan görebilirsin.

### ☐ D. Offline davranış
1. Capture ekranında uçak modunu aç.
2. Üst kısımda kırmızı "You're offline. Reconnect to analyze."
   banner'ı çıkmalı.
3. "Analyze" butonu disabled olmalı.
4. Uçak modunu kapat → banner kaybolur, buton tekrar aktif.

### ☐ E. Retry güvenliği (B1 hardening)
1. Foto seç + bağlantıyı kes (uçak modu) + "Analyze" → 
   `uploadInterrupted` mesajı.
2. Bağlantıyı geri aç, hot restart YAPMA → "Analyze"ı tekrar bas.
3. **Beklenti:** Aynı foto için ikinci upload OLMAMALI (storage
   key cache). Supabase Studio → Storage → `pet-uploads` klasörüne
   bak: bir tek dosya olmalı.

### ☐ F. App'i arkaplana atma (lifecycle recovery)
1. Foto seç → "Analyze"a bas → loading ekranındayken **home tuşuna
   bas** ve 6+ dakika bekle.
2. Uygulamaya geri dön.
3. **Beklenti:** "Connection was lost while uploading. Try again
   — we kept your photo." mesajı çıkmalı. Stuck loading ekranı
   OLMAMALI.

### ☐ G. Emergency override
1. Capture ekranında "What did you notice?" alanına şunu yaz:
   `my dog had a seizure`
2. "Analyze" → AI çağrısı **olmadan** doğrudan kırmızı EMERGENCY
   ekranı çıkmalı.
3. "I understand" butonu zorunlu — back tuşu çalışmamalı (PopScope
   bloğu).

### ☐ H. Paywall tetikle
1. Aynı kullanıcıyla 3 başarılı analiz yap.
2. 4. analyze denemesi → paywall ekranına yönlendirme.
3. ToS ve Privacy linklerini test et (tarayıcı açılmalı).
4. "Maybe later" → capture'a geri dön. "Restore purchases" →
   RevenueCat yapılandırılmadıysa "In-app purchases are not
   configured for this build."

### ☐ I. Image hygiene (B2 hardening)
1. Galeri'den **çok küçük** bir foto seç (200x200'den ufak).
2. **Beklenti:** "That image is too small..." mesajı + analiz
   başlamamalı.
3. (Opsiyonel) Web tarayıcısından bir `.html` dosyasını `.jpg`
   olarak yeniden adlandırıp galeriye koy, sonra seç → "That file
   type isn't supported" mesajı.

---

## 5. Hata Çıkarsa

### `flutter devices` cihazı görmüyor
- USB kabloyu farklı port'a tak (USB 3'ten 2'ye veya tersi).
- Telefonda "USB Hata Ayıklama" gerçekten açık mı?
- `adb devices` çalıştır → telefon "unauthorized" görünüyorsa
  telefon ekranında çıkan onay diyaloğunu kabul et.
- Sandbox/permissions sebebiyle bilgisayar ADB ile konuşamıyorsa:
  `adb kill-server && adb start-server`.

### Gradle build fail
- İlk denemen ise: `flutter clean && flutter pub get` ardından
  `flutter run` tekrar.
- "Language version 1.6 is no longer supported" → bu B3'te
  düzeltildi (`android/build.gradle.kts` içindeki Kotlin
  `compilerOptions` bloğu). `flutter clean` yap, build tekrar.
- Disk dolu mu? (`df -h`) Gradle 5 GB+ harcayabiliyor.

### Supabase'e bağlanamıyor
- **En sık sebep:** `env/dev.json` içindeki `SUPABASE_URL`
  `127.0.0.1` veya `localhost` yazıyor. Telefon kendi `127.0.0.1`'ine
  bakar, bilgisayara DEĞİL. LAN IP kullan (`192.168.1.109`).
- Telefon bilgisayar Wi-Fi'sinde değil mi? (Aynı SSID'de
  olduklarını kontrol et.)
- Yerel Supabase çalışıyor mu? Bilgisayarda:
  `supabase status` → "running" olmalı.
- Firewall portu engelliyor mu? `sudo ufw allow 54321/tcp` (Linux).

### Upload fail
- Mesaj: "We couldn't upload that image" → Magic-byte kontrolü
  reddetti VEYA Supabase Storage 5xx. Studio'da log'a bak.
- Mesaj: "Connection was lost while uploading. Try again — we
  kept your photo." → B1 timeout korumasının normal davranışı;
  tekrar dene.
- Mesaj: "That file type isn't supported" → B2 magic-byte gate;
  başka bir foto dene.

### Analyze fail
- "AI service is unavailable" → `AI_SERVICE_URL` boş veya AI
  servisi ayakta değil. Yerel test için: `make ai-dev` veya
  `cd ai-service && uv run uvicorn app.main:app --host 0.0.0.0 --port 8080`
- "Something went wrong" → Sentry breadcrumb'lara bak (B3'te
  wire'landı). Console log'da `analyze_unexpected` ara.
- "Free-tier analyses for this month are used up" → quota dolmuş;
  Supabase Studio → `public.users` → `free_analyses_used_this_month`
  sayacını 0'a çek (yerel dev için).

---

## 6. Hazır Olmayan Şeyler

Aşağıdakiler **kasıtlı olarak** hazır değil — kapalı beta için
gerekmiyorlar. Production cut'ında manuel adımlar gerekir
(bkz. `docs/reports/sprint-b3-ops-implementation.md` §7):

- **Production secrets** — `env/prod.json` Doppler'dan
  beslenecek; şu an boş.
- **App Store / Play Console publish** — Apple Developer kaydı,
  bundle ID, capability'ler, screenshots, metadata review (Sprint
  A1 dökümanına bak).
- **Better Uptime dashboards** — `/health` ve `/ready` endpoint'leri
  hazır, ama dashboard kurulumu manuel (runbook §8).
- **Sentry alert routing** — DSN konfigürasyonu hazır; alert
  kuralları manuel (runbook §8.3).
- **Live RevenueCat subscriptions** — sandbox'ta paywall görünür,
  ama gerçek satın alma için Apple/Google App Store onayı +
  RevenueCat dashboard wiring gerekiyor.
- **Live AI provider keys** — Anthropic ve Google AI spend cap'leri
  manuel set edilmeli (runbook §1).
- **OneSignal push notifications** — SDK hazır, ama Phase 3
  kampanyaları gelene kadar passive.
- **Apple Sign-In Android** — `APPLE_SIGN_IN_ENABLED=false`
  bırak; iOS-only.

---

## Hızlı referans: tek satır komutlar

```bash
# Cihaz listesi
flutter devices

# Yerel Supabase başlat (bilgisayar)
supabase start

# AI servisi başlat (bilgisayar, opsiyonel)
cd ai-service && uv run uvicorn app.main:app --host 0.0.0.0 --port 8080

# Uygulamayı telefonda çalıştır
cd mobile && flutter run --dart-define-from-file=env/dev.json

# Sadece debug APK derle (telefona elle yüklemek için)
cd mobile && flutter build apk --debug --dart-define-from-file=env/dev.json
# Çıktı: mobile/build/app/outputs/flutter-apk/app-debug.apk

# Hot reload (terminal aktifken): r
# Hot restart: R
# Durdur: q
```

Test sırasında bir şey kafa karıştırırsa, son sprint'in
implementation raporuna bak — her UX davranışının altında bir
F-code referansı var.
