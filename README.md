# HKD

HKD mobil uygulamasi (Hatay Motorsikletli Kuryeler Dernegi).

## Runtime ENV

Uygulama env parametreleri `--dart-define` ile verilir:

```bash
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=SUPABASE_URL=https://mhhochzmidrouurzhrxy.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=HKD_UPDATE_MANIFEST_URL=https://YOUR_PUBLIC_HOST/version.json
```

Production:

```bash
flutter run \
  --dart-define=APP_ENV=prod \
  --dart-define=SUPABASE_URL=https://mhhochzmidrouurzhrxy.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=HKD_UPDATE_MANIFEST_URL=https://YOUR_PUBLIC_HOST/version.json
```

Notlar:
- `SUPABASE_SERVICE_ROLE_KEY` mobil client tarafina koyulmaz.
- Service role sadece Supabase Edge Function env tarafinda kullanilir.

## Local Run

```bash
flutter pub get
flutter analyze
flutter test
```

PowerShell hizli kontrol:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\local_ready_check.ps1
```

Release readiness kontrol:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release_readiness_check.ps1
```

## Supabase Setup

1. Migrationlari uygula:
- `supabase/migrations/0001_init.sql`
- `supabase/migrations/0002_rls.sql`
- `supabase/migrations/0005_job_marketplace_init.sql`
- `supabase/migrations/0006_job_marketplace_rls.sql`
- `supabase/migrations/0007_ops_features_init.sql`
- `supabase/migrations/0008_ops_features_rls.sql`
- `supabase/migrations/0009_community_features_init.sql`
- `supabase/migrations/0010_community_features_rls.sql`
- `supabase/migrations/0011_events_rls_fix.sql`

2. Edge functionlari deploy et:

```bash
supabase functions deploy create_invite --project-ref mhhochzmidrouurzhrxy
supabase functions deploy accept_invite --project-ref mhhochzmidrouurzhrxy
supabase functions deploy approve_membership --project-ref mhhochzmidrouurzhrxy
supabase functions deploy admin_approve_user --project-ref mhhochzmidrouurzhrxy
supabase functions deploy create_payment_checkout --project-ref mhhochzmidrouurzhrxy
supabase functions deploy confirm_payment --project-ref mhhochzmidrouurzhrxy
supabase functions deploy send_notification --project-ref mhhochzmidrouurzhrxy
```

PowerShell tek komut deploy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_supabase.ps1
```

3. Function secretlarini tanimla:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `INVITE_BASE_URL` (opsiyonel; verilmezse `hkd://invite?token=...` kullanilir)
- `PAYMENT_PROVIDER` (`manual` varsayilan; opsiyonel dis saglayici modu)
- `PAYMENT_CHECKOUT_BASE_URL` (opsiyonel odeme checkout URL tabani)
- `PUSH_WEBHOOK_URL` (opsiyonel; harici push servisine POST endpoint)
- `PUSH_WEBHOOK_AUTH` (opsiyonel; webhook bearer token)
- `FCM_SERVICE_ACCOUNT_JSON` (opsiyonel ama gercek Android push icin gerekli; FCM HTTP v1 service account JSON)

## Davet Akisi (Kurye)

1. Organization owner/manager, `create_invite` ile davet olusturur.
2. Kurye uygulamada `Davet Kabul Et` ekranindan token + ad soyad + telefon + sifre ile daveti kabul eder.
3. `accept_invite` fonksiyonu hesap olusturur ama kullanici `is_active=false` kalir.
4. Dernek admin/president `admin_approve_user` ile onay verince hesap aktif olur.

Not:
- Onay akisinda admin sifre alanini bos birakabilir.
- Bu durumda sistem guclu gecici sifre uretir ve panelde kopyalanabilir olarak gosterir.

## OTP Login (Opsiyonel)

- Login ekraninda `Sifre` ve `OTP` modlari vardir.
- OTP modunda once `OTP Kodu Gonder`, sonra gelen kodla `OTP ile Giris Yap` kullanilir.
- OTP teslimati Supabase Phone Auth ayarina baglidir.
- Supabase tarafinda SMS provider tanimli degilse OTP gonderimi basarisiz olur; sifre login calismaya devam eder.

## Is Pazari (MVP)

- Ana sayfadan `Is Pazari` ekranina girilir.
- `Is Bul` sekmesi:
  - Acik ilanlari listeler.
  - Uygun ilanda `Basvur` ile basvuru olusturur.
  - Owner/manager/admin kullanicilar `Ilan Ver` ile yeni ilan acabilir.
- `Kurye Ara` sekmesi:
  - Acik kurye profillerini listeler.
  - Arama/sehir/arac tipine gore filtreleme yapar.
  - Kullanici kendi kurye profilini `Profil Duzenle` ile guncelleyebilir.

Yetki notu:
- Ilan olusturma: admin/president veya aktif organization owner/manager.
- Ilan gorme/basvurma: aktif kullanicilar.

## Etkinlik Takvimi

- `community_events` + `community_event_rsvps` tablolari ile etkinlik planlama.
- Tum aktif uyeler etkinlik listesi gorur ve RSVP (katilacagim/ilgileniyorum/katilmayacagim) secimi yapar.
- Admin/president etkinlik olusturabilir ve durum guncelleyebilir (taslak/yayinda/iptal/tamamlandi).

## Destek Merkezi ve SOS

- `support_tickets`: uye destek talepleri.
- `safety_incidents`: acil durum/SOS kayitlari.
- Uye kendi kayitlarini gorur; admin/president tum kayitlari gorup durum gunceller.
- Organizasyon owner/manager tarafi icin RLS tabanli gorunurluk hazir.

## Bildirim Altyapisi

- `user_notifications`: uygulama icinde kullanici bildirim kutusu.
- `device_push_tokens`: push token kaydi (FCM/APNS gibi dis servisler icin hazir).
- `send_notification` edge function:
  - admin/president tum aktif uyelere veya tek bir user'a bildirim gonderebilir.
  - `PUSH_WEBHOOK_URL` tanimliysa aktif `device_push_tokens` uzerinden dis push servisine dispatch eder.
  - webhook tarafinda `FCM_SERVICE_ACCOUNT_JSON` varsa Android FCM dispatch yapar.
- `announcements` insert trigger:
  - yayinlanan duyuru icin aktif uyelere otomatik bildirim olusturur.

### Cloudflare Push Worker (FCM)

Worker kodu: `cloudflare/workers/hkd-push-webhook/worker.mjs`

Canliya tek komut deploy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_push_worker.ps1
```

Gerekli env/secrets:
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `PUSH_WEBHOOK_AUTH`

Gercek Android push icin ek olarak:
- `FCM_SERVICE_ACCOUNT_JSON`

Not:
- `FCM_SERVICE_ACCOUNT_JSON` tanimli degilse worker auth calisir ama provider dispatch basarisiz doner.
- Supabase `send_notification` fonksiyonu bu durumda `push_failed` arttirir.
- `deploy_push_worker.ps1` scripti `.secrets` altindaki kayitli degerleri otomatik yukler.

## Odeme Saglayici Koprusu

- `create_payment_checkout` edge function:
  - invoice bazli odeme talebi olusturur.
  - `PAYMENT_CHECKOUT_BASE_URL` varsa checkout linki dondurur.
  - yoksa manual odeme talimatiyla fallback yapar.
- `confirm_payment` edge function:
  - admin/president odeme durumunu (`succeeded/failed/refunded`) isler.
  - `dues_invoices` durumunu senkron gunceller.
- `payment_checkout_sessions`:
  - odeme oturum audit/izleme tablosu.
- `payment_reconciliation_logs`:
  - admin odeme mutabakat gecmisi (onceki/yeni durum, neden, ref).

## Admin Raporlama

- `admin_report_snapshot` RPC:
  - aktif/pending uye, org sayisi, bekleyen basvuru, acik is, aidat metrikleri, okunmamis bildirim toplamlarini dondurur.
- Flutter tarafinda:
  - `Yonetim Paneli -> Raporlar` ekrani KPI kartlariyla gosterir.

### Deep Link Test (Android)

`hkd://invite?token=YOUR_TOKEN` ile uygulama davet ekranini token dolu acar.

```bash
adb shell am start -a android.intent.action.VIEW -d "hkd://invite?token=YOUR_TOKEN"
```

HTTPS App Link icin `android/app/build.gradle.kts` icindeki host degerini gercek domain ile degistirin:

`manifestPlaceholders["hkdAppLinkHost"] = "your-domain.com"`

Domain linki ornekleri:
- `https://your-domain.com/invite?token=YOUR_TOKEN`
- `https://your-domain.com/hkd/invite/YOUR_TOKEN`

ADB ile test:

```bash
adb shell am start -a android.intent.action.VIEW -d "https://your-domain.com/invite?token=YOUR_TOKEN"
```

Android host ayari script:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\set_android_app_link_host.ps1 -AppLinkHost "your-project.pages.dev"
```

## APK Dagitimi (Manifest)

1. `public/version.json` dosyasini public hosta koyun (Cloudflare Pages / Firebase Hosting / GitHub Pages).
2. Yeni APK cikisinda `apk_url` alanini guncelleyin.
3. `latest_version` alanini yeni uygulama surumune cekin.
4. Zorunlu guncelleme istiyorsaniz `min_supported_version` alanini yukselterek eski versiyonlari bloke edin.
5. Flutter `pubspec.yaml` icindeki `version` alanini bump edin (ornek: `1.0.3+4`).

`public/version.json` ve `public/index.html` dosyalarini tek komutla guncellemek icin:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish_public_release.ps1 `
  -ApkUrl "https://github.com/<owner>/<repo>/releases/download/v1.0.0/hkd-1.0.0.apk" `
  -LatestVersion "1.0.0" `
  -MinSupportedVersion "1.0.0" `
  -ReleaseNotes "Ilk surum","Duyuru modulu eklendi"
```

Release APK komutu (PowerShell script):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_release_apk.ps1 `
  -SupabaseUrl "https://mhhochzmidrouurzhrxy.supabase.co" `
  -SupabaseAnonKey "YOUR_ANON_KEY" `
  -UpdateManifestUrl "https://your-domain.com/version.json" `
  -AppLinkHost "your-project.pages.dev"
```

Not:
- Gercek imzali release icin `android/key.properties` dosyasini `android/key.properties.example` temel alarak olusturun.

Tek komut finalizasyon (host + public dosyalar + readiness + release build):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\finalize_release.ps1 `
  -AppLinkHost "your-project.pages.dev" `
  -ApkUrl "https://github.com/<owner>/<repo>/releases/download/v1.0.0/hkd-1.0.0.apk" `
  -LatestVersion "1.0.0" `
  -ReleaseNotes "Ilk surum" `
  -SupabaseUrl "https://mhhochzmidrouurzhrxy.supabase.co" `
  -SupabaseAnonKey "YOUR_ANON_KEY" `
  -UpdateManifestUrl "https://your-project.pages.dev/version.json"
```

Gercek dis servis publish otomasyonu (GitHub Release + Cloudflare Pages):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_external_services.ps1 `
  -PagesProjectName "your-project" `
  -AppLinkHost "your-project.pages.dev" `
  -RepoOwner "<github-owner>" `
  -RepoName "<github-repo>" `
  -ReleaseTag "v1.0.0" `
  -LatestVersion "1.0.0" `
  -ReleaseNotes "Ilk surum" `
  -SupabaseUrl "https://mhhochzmidrouurzhrxy.supabase.co" `
  -SupabaseAnonKey "YOUR_ANON_KEY" `
  -GithubToken "YOUR_GITHUB_TOKEN" `
  -CloudflareApiToken "YOUR_CLOUDFLARE_TOKEN" `
  -CloudflareAccountId "YOUR_CLOUDFLARE_ACCOUNT_ID"
```

Gerekli tokenlar:
- GitHub token: repo release yazma yetkisi
- Cloudflare token: Pages deploy yetkisi

Yerel sifreli saklama (token kaybolmasin):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\secrets_save.ps1 -Name GITHUB_TOKEN
powershell -ExecutionPolicy Bypass -File .\scripts\secrets_save.ps1 -Name CLOUDFLARE_API_TOKEN
powershell -ExecutionPolicy Bypass -File .\scripts\secrets_save.ps1 -Name CLOUDFLARE_ACCOUNT_ID
```

`deploy_external_services.ps1` calisirken bu sifreli degerleri otomatik yukler.

## CI/CD

- `flutter_ci.yml`: her push/PR icin `pub get + analyze + test`.
- `release_delivery.yml`:
  - tag veya manual trigger ile release APK build eder,
  - Java 17 + Gradle cache ile daha stabil release build calistirir,
  - GitHub Release asset yukler,
  - `app-release.apk.sha256` ozet dosyasini da release'e ekler,
  - `public/version.json` + `public/index.html` icindeki APK/release linklerini gunceller,
  - Cloudflare Pages deploy (secret'lar varsa) yapar.

Gerekli GitHub Actions secret'lari:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `HKD_UPDATE_MANIFEST_URL`
- `HKD_APP_LINK_HOST` (opsiyonel; varsayilan: `hkd-app.pages.dev`)
- `CLOUDFLARE_API_TOKEN` (opsiyonel deploy)
- `CLOUDFLARE_ACCOUNT_ID` (opsiyonel deploy)
- `CLOUDFLARE_PAGES_PROJECT` (opsiyonel deploy)

Manual calistirma notu:
- Workflow `pubspec.yaml` icindeki `version` alanindan beklenen tag'i otomatik cikarir (`vX.Y.Z`).
- `workflow_dispatch` icin `release_tag` bos birakilabilir; otomatik olarak `pubspec` tag'i kullanilir.
- `release_tag` verilirse de `pubspec` ile birebir ayni olmak zorundadir, aksi halde release fail olur.

## Dokumanlar

- Plan: `docs/plan.md`
- Karar kayitlari: `docs/decisions.md`
- Release checklist: `docs/release_checklist.md`
- Handover runbook: `docs/handover.md`
