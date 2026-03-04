# HKD Handover Runbook

Date: 2026-02-28

This runbook is the final operational checklist to move HKD from local to live usage.

## 1) Local Quality Gate

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\local_ready_check.ps1
```

Expected:
- `flutter analyze` clean
- `flutter test` all green

## 2) Supabase Deploy

Prerequisite:
- Supabase CLI login is completed.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_supabase.ps1
```

Opsiyonel:
- Uzak veritabani sifresi otomatik girilsin isterseniz:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_supabase.ps1 -DbPassword "YOUR_DB_PASSWORD"
```

This applies:
- migrations (`db push`)
- edge functions (`create_invite`, `accept_invite`, `approve_membership`, `admin_approve_user`, `create_payment_checkout`, `confirm_payment`, `send_notification`)
- includes migrations (`0005`, `0006`, `0007`, `0008`)
- includes migrations (`0005`, `0006`, `0007`, `0008`, `0009`, `0010`, `0011`)

## 3) Supabase Secrets

Set the following secrets in Supabase Functions:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `INVITE_BASE_URL` (optional)
- `PAYMENT_PROVIDER` (optional, default `manual`)
- `PAYMENT_CHECKOUT_BASE_URL` (optional)
- `PUSH_WEBHOOK_URL` (optional)
- `PUSH_WEBHOOK_AUTH` (optional)
- `FCM_SERVICE_ACCOUNT_JSON` (optional, required for real Android push dispatch)

## 3.2) Cloudflare Push Worker Deploy

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_push_worker.ps1
```

Required:
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `PUSH_WEBHOOK_AUTH`

Optional:
- `FCM_SERVICE_ACCOUNT_JSON` (if absent, webhook auth works but provider dispatch stays disabled)

## 3.1) Ilk Baskan Atamasi (Tek Sefer)

1. Uygulamaya kendi hesabinizla giris yapin.
2. `Onay Bekleniyor` ekraninda `Ilk Kurulum: Baskan Olarak Aktiflestir` butonuna basin.
3. Islem basariliysa hesap aktif olur ve dogrudan ana ekrana gecersiniz.

Not:
- Bu islem sadece sistemde henuz `president` yoksa calisir.
- Sonraki kullanicilar ayni islemle baskan olamaz.

## 4) Android App Link Host

Update host value in:
- `android/gradle.properties`
- `HKD_APP_LINK_HOST=your-domain.com`

Then publish `assetlinks.json` on your domain if Android verified links are needed.

Shortcut:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\set_android_app_link_host.ps1 -AppLinkHost "your-project.pages.dev"
```

## 4.1) Release Signing

1. `android/key.properties.example` dosyasini `android/key.properties` olarak kopyalayin.
2. Keystore ve sifre alanlarini gercek degerlerle doldurun.
3. Keystore dosyasini `android/` altina koyun.

## 5) Build Release APK

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_release_apk.ps1 `
  -SupabaseUrl "https://mhhochzmidrouurzhrxy.supabase.co" `
  -SupabaseAnonKey "YOUR_ANON_KEY" `
  -UpdateManifestUrl "https://your-domain.com/version.json"
```

Output:
- `build\app\outputs\flutter-apk\app-release.apk`

## 5.1) Build Release Web

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_release_web.ps1 `
  -SupabaseUrl "https://mhhochzmidrouurzhrxy.supabase.co" `
  -SupabaseAnonKey "YOUR_ANON_KEY" `
  -UpdateManifestUrl "https://your-project.pages.dev/version.json"

powershell -ExecutionPolicy Bypass -File .\scripts\publish_web_bundle.ps1
```

Output:
- `public\web\` (Cloudflare Pages tarafinda `https://your-project.pages.dev/web/`)

## 6) Update Manifest Publish

Update and publish:
- `public/version.json`

Or run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish_public_release.ps1 `
  -ApkUrl "https://github.com/<owner>/<repo>/releases/download/v1.0.0/hkd-1.0.0.apk" `
  -LatestVersion "1.0.0" `
  -MinSupportedVersion "1.0.0" `
  -ReleaseNotes "Ilk surum"
```

Required fields:
- `latest_version`
- `min_supported_version`
- `apk_url`
- `release_notes`
- `published_at`

## 7) Smoke Test (Production-like)

1. Login (active user)
2. Login (inactive user -> pending screen)
3. Membership apply + review approve/reject
4. Invite create + deep link accept
5. Admin approve invited user
6. Announcements list/create/update/delete (authorized roles)
7. Dues summary and period visibility
8. Is pazari: ilan olusturma/listeleme + basvuru + kurye profil arama
9. Etkinlikler: listeleme + RSVP + admin durum degisimi
10. Destek Merkezi: ticket olusturma/listeleme + SOS kaydi olusturma
11. Bildirimler: panelden bildirim gonderme + kullanici kutusunda okundu/okunmadi
12. Odeme: member `Odeme Baslat` + admin `confirm_payment` + mutabakat logu
13. Raporlar: `Yonetim Paneli -> Raporlar` KPI kontrolu
14. OTP login (SMS provider varsa) ve sifre login fallback
15. Update manifest optional + mandatory dialog behavior

## Optional: One-Command Finalization

Use:

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

## Optional: External Services Full Automation

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
