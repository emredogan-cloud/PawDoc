# PawDoc — Resmî Ürün Dokümanı

*Bu belge; kurucu, yatırımcılar, iş ortakları, uygulama mağazası incelemecileri ve gelecekteki ekip üyeleri için hazırlanmıştır. Teknik bilgi gerektirmeden PawDoc'un ne olduğunu, ne yaptığını ve neyi bilinçli olarak yapmadığını anlatır.*

**Tarih:** 2026-07-18 · **Sürüm:** Yayın Adayı (Release Candidate)

---

## 1. PawDoc nedir?

PawDoc, evcil hayvan sahiplerinin **"Şu an veterinere gitmeli miyim, yoksa bekleyebilir miyim?"** sorusuna sakin, güvenilir ve saniyeler içinde yanıt bulmasını sağlayan bir mobil uygulamadır.

En önemli nokta şudur: PawDoc **teşhis koymaz**. Bir hastalığın adını söylemez, "her şey normal" demez, "hayvanınız iyi" gibi rahatlatıcı bir hüküm vermez. Bunun yerine:

1. Sahibin anlattığını (veya fotoğrafı) **sade bir dille gözlemler**,
2. **Net bir eylem** önerir — *"bugün veterinerinizi arayın"*, *"randevu alın"*, *"şu belirtileri izleyin ve 24 saat içinde tekrar kontrol edin"* gibi,
3. Ve bir **zaman çizelgesi** verir.

Ayrıca her kontrolü evcil hayvanın **sağlık kaydına** işler; böylece uygulama zamanla veterinerin gerçekten görmek isteyeceği bir geçmişe dönüşür.

Kısacası: **PawDoc bir "teşhis makinesi" değil, bir "ne zaman ve nasıl harekete geçeceğinizi söyleyen sakin bir rehber ve sağlık defteridir."**

---

## 2. Hangi problemi çözer?

Evcil hayvan sahipleri sürekli bir belirsizlik yaşar:

- Köpeğim topallıyor — acil mi, yoksa dinlenirse geçer mi?
- Kedim iki gündür az yiyor — endişelenmeli miyim?
- Gece yarısı bir şey oldu — nereye başvurmalıyım?

Bu belirsizliğin iki kötü sonucu vardır:
- **Panikle gereksiz acil servis ziyaretleri** (zaman, para, stres),
- Ya da tam tersi, **ciddi bir durumu "geçer" diye erteleme** (asıl tehlikeli olan budur).

PawDoc bu boşluğu doldurur: internetteki dağınık ve korkutucu bilgilerin veya rastgele tahminlerin yerine, **belirtiyi bir eyleme ve bir zamana bağlayan** tutarlı bir yön verir. Amaç veterineri **değiştirmek değil**, sahibin veterinere **ne zaman ve nasıl** ulaşacağını netleştirmektir.

---

## 3. Nasıl çalışır?

Kullanıcı deneyimi kasıtlı olarak basittir:

1. **Evcil hayvan profili oluştur** — tür, isim, cinsiyet, kilo, kısa tıbbi notlar.
2. **Kontrol başlat ("Check")** — iki yol vardır:
   - **Belirtileri yaz** (ücretsiz ve sınırsız): "Köpeğim sabahtan beri arka ayağını basmıyor."
   - **Fotoğraf çek** (premium/aylık sınırlı): deri, göz, yara gibi görsel durumlar için.
3. **Sonuç ekranı** — bir *eylem merdiveni* değeri döner:
   - `ACİL YARDIM AL` → gerçek acil durum,
   - `BUGÜN ARA` → aynı gün veterineri ara,
   - `RANDEVU AL` → yakın zamanda muayene,
   - `İZLE VE TEKRAR KONTROL ET` → belirli işaretleri izle, belirli saat sonra tekrar bak.
   Sonuçta ayrıca: *ne gözlemlendiği*, *bir veterinerin neye bakacağı*, *nelere dikkat edileceği*, *ne yapılacağı adımları*, *zamanlama* ve **yasal uyarı** yer alır.
4. **Kayda işlenir** — "Rex'in geçmişine kaydedildi." Böylece kilo takibi, aşılar, hatırlatıcılar ve geçmiş kontroller tek yerde birikir.
5. **Veteriner Ziyareti Hazırlık Paketi** — tüm bu kaydı, veterinere gösterilebilecek temiz bir özet hâline getirir.

**Önemli tasarım kuralı:** Hiçbir sonuç "hiçbir şey yapma" ile bitmez. Her yanıt mutlaka bir **eylem** ve bir **zaman** içerir. Uygulama asla rahatlatıcı bir "yeşil / her şey yolunda" hükmü göstermez.

---

## 4. Yapay zekâyı nasıl kullanır?

Yapay zekâ, PawDoc'un **yardımcı motorudur — hâkimi değil.**

- **Katmanlı model mimarisi:** Önce hızlı ve ekonomik bir model (Google Gemini 2.0 Flash), gerektiğinde daha güçlü bir modele (Anthropic Claude Sonnet) yükseltme yapılır. Tüm sağlık analizleri **düşük sıcaklıkta (0.1)** çalışır — yani tutarlı ve savruk olmayan yanıtlar.
- **Yapılandırılmış çıktı:** Model serbest metin üretmez; katı bir sözleşmeye (eylem, gözlem, izlenecekler, zaman) uyan yapılandırılmış bir yanıt üretir. Sözleşmeye uymayan çıktı reddedilir.
- **Güven eşiği:** Model yeterince emin değilse (güven < 0.60), uygulama **uydurmaz** — "yeterli bilgi yok, şunları izleyin ve tekrar kontrol edin" gibi güvenli bir zemine iner.
- **Asla teşhis yok:** Sistem talimatı, modele bir hastalık adı vermeyi, "normal" demeyi veya kesin bir sonuç uydurmayı **yasaklar**. Model bir gözlemci gibi davranır.
- **Güvenli bozulma (fail-safe):** Yapay zekâ ulaşılamazsa veya hata verirse, uygulama çökmez; güvenli "izle ve tekrar kontrol et" zeminine iner. Yani "AI bozuldu" durumu bile sahibi tehlikeye atmaz.
- **Maliyet ve kötüye kullanım koruması:** Kullanıcı başına hız sınırı, istek başına zaman aşımı ve token maliyet ölçümü vardır.

**Acil durum yolu bir yapay zekâ özelliği DEĞİLDİR** (bkz. bölüm 6) — bu bilinçli bir güvenlik kararıdır.

---

## 5. Hangi özellikleri vardır?

- **Belirti kontrolü** (metin — ücretsiz; fotoğraf — premium).
- **Eylem merdiveni sonucu** + yasal uyarı, "yakın veteriner bul" ve "kaydı paylaş".
- **Sağlık kaydı / zaman çizelgesi:** kontroller, kilo takibi (grafik), aşılar, tıbbi notlar.
- **Cihaz üzerinde hatırlatıcılar:** aşı/ilaç zamanı için yerel bildirimler (sunucu gerekmez).
- **Veteriner Ziyareti Hazırlık Paketi:** muayeneye götürülecek temiz özet + sorulacak sorular.
- **Çevrimdışı Acil Durum ekranı:** kırmızı buton (bkz. bölüm 6).
- **Premium abonelik:** fotoğraf kayıtları ve tüm hafıza özellikleri.
- **Karanlık, sakin ve tutarlı arayüz;** erişilebilirlik (metin ölçekleme) desteği.

---

## 6. Neleri özellikle YAPMAZ? (bilinçli sınırlar)

Bu bölüm, ürünün kimliğinin kalbidir:

- **Teşhis koymaz.** Hastalık adı vermez. "Kesinlikle şu hastalık" demez.
- **"Her şey normal" demez.** Rahatlatıcı bir hüküm asla göstermez — çünkü en büyük risk, ciddi bir durumu "iyi" diye geçiştirmektir.
- **Güven skorunu kullanıcıya göstermez** (yanıltıcı bir kesinlik hissi yaratmamak için).
- **Acil durum ekranında para kazanmaz.** Acil durum yolunda reklam, satış ortaklığı (affiliate), premium teklif veya yapay zekâ **yoktur**. Yalnızca: yardım iletişimi, ilk yardım kartları, yasal uyarı ve onay adımı.
- **Acil sonucu asla ödeme duvarının arkasına koymaz.** Bir aciliyet tespit edilirse, kullanıcının abone olup olmadığına bakılmaksızın yardım gösterilir (hem sunucu hem istemci tarafında zorlanır).
- **İstemcide gizli anahtar taşımaz.** Yüklemeler kısa ömürlü imzalı bağlantılarla yapılır.
- **Kullanıcı verisini rızasız izlemez.** Analitik varsayılan olarak KAPALIDIR.

---

## 7. Acil durum modu nasıl çalışır?

Acil durum, kasıtlı olarak **yapay zekâdan ve internetten bağımsızdır**:

- Ana ekranda kalıcı bir **kırmızı "Acil mi? Hemen yardım al"** butonu vardır.
- İstemci tarafında yerleşik bir **anahtar kelime yönlendiricisi** (157 EN/DE acil terim) vardır: kullanıcı acil bir şey yazarsa, **herhangi bir ağ çağrısı yapılmadan önce** doğrudan kırmızı ekrana yönlendirilir. Yani telefon çevrimdışıyken bile çalışır.
- Kırmızı ekran şunları içerir: **acil veteriner bul** (harita bağlantısı), **zehir kontrol hattını ara** (ASPCA), ve **5 ilk yardım kartı** (boğulma, kanama, nöbet, mide dönmesi/şişkinlik, aşırı ısınma).
- Bu içerik cihazda gömülüdür; **çevrimdışı, uçak modunda test edilmiş ve doğrulanmıştır.**
- İlk yardım kartları ilaç adı/dozu vermez; her zaman veterinere yönlendirir.

*(Not: İlk yardım içeriğinin yayından önce lisanslı bir veteriner tarafından onaylanması gereken bir kurucu görevidir.)*

---

## 8. Güvenlik modeli

- **Satır düzeyinde güvenlik (RLS):** Her kullanıcı tablosunda, her kullanıcı yalnızca **kendi** verisine erişebilir. Bu, veritabanı düzeyinde zorlanır; uygulama koduna güvenilmez.
- **Sunucu tarafı yetkilendirme:** Kota kontrolü ve yapay zekâ çağrısı sunucudadır; istemciye güvenilmez.
- **Güvenli medya:** Fotoğraflar yüklenmeden önce EXIF/GPS bilgisi temizlenir ve içerik moderasyonundan geçer (şüpheli içerik reddedilir ve silinir).
- **Sırlar Doppler'da:** Gerçek anahtarlar depoda tutulmaz; CI sır taraması yapar.
- **Katmanlı güven sınırı:** Sunucular arası çağrılar paylaşılan bir gizli anahtarla doğrulanır.

---

## 9. Gizlilik modeli

- **Analitik varsayılan KAPALI:** Kullanıcı kayıt sırasında açıkça onay vermedikçe ürün analitiği çalışmaz; Hesap ekranından geri alınabilir.
- **Açık rıza:** Kayıt, Şartlar/Gizlilik onayına bağlıdır ve bu onay tarih olarak kaydedilir.
- **Hata izleme kişisel veri sızdırmaz** (PII kapalı).
- **Şeffaf işlemciler:** Gizlilik politikası, uygulamanın gerçekte kullandığı hizmetleri anlatır (kaldırılan tedarikçiler politikadan da çıkarılmıştır).
- **Hesap silme uygulama içindedir** ve verileri kalıcı olarak siler.
- **15 sayfalık yasal portal** (Gizlilik, Şartlar, Veteriner Uyarısı, Yapay Zekâ Şeffaflığı, Abonelik, GDPR, CCPA, Çocuk gizliliği, vb.) canlıdır ve uygulamadan bağlanır.

---

## 10. Premium özellikler ve iş modeli

**Felsefe: "Ücretsiz = güvenlik, Ücretli = hafıza."**

- **Ücretsiz:** metin belirti kontrolleri (sınırsız), çevrimdışı acil durum yolu, temel kayıt. Güvenlik asla ödeme duvarının arkasında değildir.
- **Premium (tek plan):** fotoğraf kayıtları (aylık sınır) ve tam sağlık hafızası / Hazırlık Paketi değeri. Yaklaşık $39.99/yıl veya $6.99/ay.
- Fotoğraf kayıtları **yapay zekâ çağrısından ÖNCE** ölçülür; yani kota dolduğunda hiçbir istek pahalı bir modele ulaşamaz (maliyet kök seviyede kontrol altındadır).
- **Tek, dürüst bir abonelik.** Karmaşık kademeler, ek satın alımlar veya "büyüme oyunları" yoktur.

---

## 11. Hedef kullanıcı kitlesi

- **Birinci öncelik: yeni ve endişeli evcil hayvan sahipleri** — özellikle ilk kez köpek/kedi sahibi olanlar; her belirtide ne yapacağını bilmeyenler.
- Çok yönlü hayvan sahipleri, veterinere hızlı erişimi olmayanlar (kırsal/gece), ve evcil hayvanının sağlık geçmişini düzenli tutmak isteyenler.
- Başlangıç pazarı: İngilizce/Almanca konuşulan bölgeler (güvenlik anahtar kelime altyapısı EN/DE'dir).

Her tasarım kararında sorulan soru: **"İlk kez evcil hayvan sahibi olan biri bunu sever miydi?"**

---

## 12. Neden farklı?

- **Dürüstlük:** Teşhis taklidi yapmaz; sınırlarını açıkça söyler. Bu hem etik hem de yasal olarak daha güvenlidir.
- **Güvenlik önce gelir:** Yanlış bir "iyi" (false negative) 1 numaralı iş riski kabul edilir; ürün buna göre tasarlanmıştır.
- **Sakinlik:** Panik yaratmaz; her yanıt bir eyleme ve bir zamana bağlanır.
- **Hafıza değeri:** Tek seferlik bir tahmin değil, zamanla değeri artan bir sağlık defteri.
- **Acil durumda ticari çıkar yok:** En hassas an, para kazanma girişiminden tamamen arındırılmıştır.

---

## 13. Gelecek vizyonu

- **Fotoğraf ilerleme çizelgesi** (yan yana "7 gün sonra tekrar fotoğrafla") — premium bağlılık döngüsünün tamamlanması.
- **Kalıcı "veterinere sorulacak sorular"**, yerel haftalık özet bildirimi, evcil hayvan profil fotoğrafı.
- **Almanca tam yerelleştirme** ve pazar genişlemesi.
- **Veteriner paylaşım bağlantısı** (salt-okunur güvenli özet).
- *Yalnızca ekip + hukuk danışmanı ile:* aile paylaşımı v2, tavsiye/referans v2, video, ve yalnızca "sakin" ekranlarda sigorta ortaklığı.
- **Kalıcı olarak dışarıda tutulanlar:** özel eğitilmiş tıbbi model, topluluk soru-cevap, B2B API, sigorta hasar dosyalama — hepsi tıbbi sorumluluğu şirketin üzerine yıkar; ancak bir ekip, hukuk ve mesleki sorumluluk sigortasıyla yeniden değerlendirilir.

---

*Bu doküman ürünün mevcut, doğrulanmış durumunu yansıtır. Yayın öncesi kurucu görevleri (üretim ortamı izolasyonu, imzalama, RevenueCat ürünleri, avukat + veteriner + sigorta onayları, mağaza varlıkları, iOS cihaz testi) için `PAWDOC_PRELAUNCH_CHECKLIST.md` belgesine bakınız.*
