# HKD Release Checklist

## 1) Guvenlik
- `SUPABASE_SERVICE_ROLE_KEY` sadece Edge Function env'de
- Mobil uygulamada sadece `SUPABASE_URL` + `SUPABASE_ANON_KEY`
- RLS policy smoke testleri tamamlandi
- Audit log kritik akislari dogrulandi

## 2) Veritabani ve Fonksiyonlar
- `0001_init.sql` uygulandi
- `0002_rls.sql` uygulandi
- `0005_job_marketplace_init.sql` uygulandi
- `0006_job_marketplace_rls.sql` uygulandi
- `0007_ops_features_init.sql` uygulandi
- `0008_ops_features_rls.sql` uygulandi
- `0009_community_features_init.sql` uygulandi
- `0010_community_features_rls.sql` uygulandi
- `0011_events_rls_fix.sql` uygulandi
- Edge function deploy tamam:
  - `create_invite`
  - `accept_invite`
  - `approve_membership`
  - `admin_approve_user`
  - `create_payment_checkout`
  - `confirm_payment`
  - `send_notification`
- Function secretleri tanimli:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `INVITE_BASE_URL` (opsiyonel)
  - `PAYMENT_PROVIDER` (opsiyonel)
  - `PAYMENT_CHECKOUT_BASE_URL` (opsiyonel)
  - `PUSH_WEBHOOK_URL` (opsiyonel)
  - `PUSH_WEBHOOK_AUTH` (opsiyonel)
  - `FCM_SERVICE_ACCOUNT_JSON` (opsiyonel, gercek Android push icin gerekli)
- Cloudflare push worker deploy tamam:
  - `.\scripts\deploy_push_worker.ps1`

## 3) Mobil Kalite Kapilari
- `flutter pub get`
- `flutter analyze` (temiz)
- `flutter test` (yesil)
- opsiyonel tek komut: `.\scripts\local_ready_check.ps1`
- Kritik akislar manuel test:
  - login/logout
  - inactive -> pending approval redirect
  - membership apply/status
  - admin approve/reject user
  - membership approve/reject
  - is pazari: ilan listele/basvur
  - is pazari: kurye profil duzenle/ara
  - etkinlikler: listele + RSVP
  - destek merkezi: ticket ac + SOS ac
  - organization invite olusturma/iptal
  - organization uye rol/durum guncelle
  - aidat ozet ekranlari
  - bildirim kutusu + panelden bildirim gonderme
  - odeme baslatma + admin odeme onay/red/iade + mutabakat kaydi
  - admin KPI rapor ekrani
  - OTP login (SMS provider varsa) + sifre login fallback

## 4) APK Dagitimi
- `pubspec.yaml` version bump yapildi
- Release APK build alindi
- APK dosyasi public hosta yuklendi
- `android/key.properties` ve release keystore dogrulandi
- `public/version.json` guncellendi:
  - `latest_version`
  - `min_supported_version`
  - `apk_url`
  - `release_notes`
  - `published_at`
- Uygulama acilisinda update popup davranisi test edildi (opsiyonel/zorunlu)
- release build script dogrulandi: `.\scripts\build_release_apk.ps1`
- readiness check script yesil: `.\scripts\release_readiness_check.ps1`
- CI workflow:
  - `flutter_ci.yml` (analyze+test)
  - `release_delivery.yml` (tag/manual release + artifact + optional Cloudflare deploy)

## 5) Uygulama Kimligi ve Dagitim
- Paket adi: `org.hataykuryeler.hkd`
- Uygulama ikon/splash dogrulamasi tamamlandi
- Ortam parametreleri (`--dart-define`) release pipeline ile uyumlu
- Android deep link host degeri (`hkdAppLinkHost`) gercek domain ile guncellendi
