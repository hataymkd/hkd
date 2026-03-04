# HKD Public Deploy Guide

Bu dokuman, domain/DNS olmadan HKD APK indirme ve version manifest yayinini canliya almak icindir.

## A) Cloudflare Pages Kurulumu

1. Cloudflare paneline girin.
2. `Pages` -> `Create project` secin.
3. GitHub reponuzu baglayin.
4. Build ayarlari:
   - Framework preset: `None`
   - Build command: bos birakin
   - Output directory: `public`
5. Deploy tamamlandiginda host adresini alin:
   - `https://<project>.pages.dev`

Not:
- Android app link icin Flutter tarafinda `hkdAppLinkHost` degerini bu host ile ayni yapin.
- Repository kokunden host ayari icin:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\set_android_app_link_host.ps1 -AppLinkHost "<project>.pages.dev"
```

## B) GitHub Release ile APK Yukleme

1. GitHub repoda `Releases` sekmesine gidin.
2. `New release` olusturun.
3. APK dosyasini yukleyin (ornek: `hkd-1.0.0.apk`).
4. Release sayfasinda APK dosyasinin `Download URL` linkini kopyalayin.

## C) version.json Guncelleme

`public/version.json` dosyasini su alanlarla guncelleyin:

- `apk_url`: GitHub Release download linki
- `latest_version`: yeni uygulama surumu (ornek `1.0.1`)
- `release_notes`: yeni surume ait maddeler
- `published_at`: UTC zaman (ornek `2026-02-28T00:00:00Z`)

Sonra commit + push yapin. Cloudflare Pages otomatik redeploy olur.

Tek komutla guncellemek icin (repo kokunden):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\publish_public_release.ps1 `
  -ApkUrl "https://github.com/<owner>/<repo>/releases/download/v1.0.0/hkd-1.0.0.apk" `
  -LatestVersion "1.0.0" `
  -MinSupportedVersion "1.0.0" `
  -ReleaseNotes "Ilk surum"
```

## D) index.html Guncelleme

`public/index.html` icindeki asagidaki yeri guncelleyin:

- `REPLACE_WITH_APK_URL` -> GitHub Release APK linki

Sonra commit + push yapin.

## E) Test

1. Tarayicidan su adres aciliyor mu kontrol edin:
   - `https://<pages-host>/version.json`
   - `https://<pages-host>/web/`
2. `index.html` sayfasindaki `APK Indir` butonu calisiyor mu test edin.
3. `Web'de Kullan` butonu Flutter web uygulamasini aciyor mu test edin.
4. Flutter uygulamada update check testi:
   - Build/run komutunda su parametre verilmeli:

```bash
flutter run \
  --dart-define=APP_ENV=prod \
  --dart-define=SUPABASE_URL=https://mhhochzmidrouurzhrxy.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=HKD_UPDATE_MANIFEST_URL=https://<your-pages-host>/version.json
```

Beklenen:
- Yeni surum varsa uygulama guncelleme popupi gorunur.
- `Indir` butonu GitHub Release APK linkine yonlendirir.

## E.1) Flutter Web Build ve Publish

Repo kokunden:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_release_web.ps1 `
  -SupabaseUrl "https://mhhochzmidrouurzhrxy.supabase.co" `
  -SupabaseAnonKey "YOUR_ANON_KEY" `
  -UpdateManifestUrl "https://<pages-host>/version.json"

powershell -ExecutionPolicy Bypass -File .\scripts\publish_web_bundle.ps1
```

Sonra Cloudflare'a tekrar deploy edin:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_cloudflare_pages.ps1 -ProjectName "<project>" -Directory "public"
```

Release oncesi kontrol (repo kokunden):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\release_readiness_check.ps1
```

## F) Tam Otomatik (Opsiyonel)

GitHub Release + Cloudflare Pages + public dosya guncelleme tek komut:

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
