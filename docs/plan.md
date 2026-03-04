# HKD Delivery Plan

Date: 2026-02-28
Scope: HKD Flutter + Supabase production backend migration (HKD-only, independent project)

## Phase Order (Fixed)

### FAZ-1: Supabase SQL Schema + RLS + Helper Functions
Status: Completed
Deliverables:
- `supabase/migrations/0001_init.sql`
- `supabase/migrations/0002_rls.sql`
- Production tables, constraints, indexes, triggers, role helpers, RLS policies
Acceptance criteria:
- President uniqueness enforced at DB level
- E.164 checks active for phone fields
- `is_active=false` users blocked from module tables
- Organization ownership/membership and invite schema ready

### FAZ-2: Edge Functions
Status: Completed
Deliverables:
- `create_invite`
- `accept_invite`
- `approve_membership`
- `admin_approve_user`
Acceptance criteria:
- Service role used only in Edge Function env
- Admin/president authorization checks are enforced
- Invite accept flow leaves user inactive until admin approval
- Audit logs written for critical actions

### FAZ-3: Flutter Mock -> Supabase
Status: Completed
Deliverables:
- Env-based Supabase init
- Repository pattern with Supabase implementations
- Inactive user guard and pending approval screen
- Management panel approval actions
- Organization panel (invite + member list)
Acceptance criteria:
- No service role in mobile app
- Supabase calls stay in repository/service layer
- Role/route guard preserved
- Login with inactive account always routes to pending approval screen

### FAZ-4: APK Update Manifest
Status: Completed
Deliverables:
- `public/version.json`
- `lib/features/update/*`
- Startup update check (mandatory/optional)
Acceptance criteria:
- Manifest fetch failure is fail-safe
- Mandatory update blocks app navigation
- Optional update is dismissible

### FAZ-5: Tests + CI + Release Checklist
Status: Completed
Deliverables:
- `flutter analyze` and `flutter test` green
- Basic CI pipeline for analyze/test
- Updated release checklist
Acceptance criteria:
- CI runs on push/PR
- Release checklist includes APK manifest/update flow and Edge deploy steps

### FAZ-6: Is Pazari (Job + Courier Marketplace)
Status: Completed
Deliverables:
- `supabase/migrations/0005_job_marketplace_init.sql`
- `supabase/migrations/0006_job_marketplace_rls.sql`
- `lib/features/jobs/*` (DTO, repository, page)
- Home + router entegrasyonu (`/jobs-marketplace`)
- Smoke test route coverage update
Acceptance criteria:
- Aktif kullanici acik ilanlari gorebilir ve basvuru yapabilir
- Owner/manager/admin ilan olusturabilir
- Kurye profili olusturma/guncelleme desteklenir
- Kurye havuzu filtreleme (metin/sehir/arac) calisir
- `flutter analyze` ve `flutter test` yesil

### FAZ-7: OTP + Bildirim + Odeme Koprusu + Admin KPI + Release Delivery
Status: Completed
Deliverables:
- `supabase/migrations/0007_ops_features_init.sql`
- `supabase/migrations/0008_ops_features_rls.sql`
- Edge functions:
  - `create_payment_checkout`
  - `confirm_payment`
  - `send_notification`
- Flutter:
  - Login OTP modu (sifre modu korunarak)
  - Bildirim kutusu (`/notifications`)
  - Admin KPI rapor ekrani (`/admin-reports`)
  - Odeme baslatma akisi (checkout/manual fallback)
- CI/CD:
  - `.github/workflows/release_delivery.yml`
Acceptance criteria:
- OTP gonderim/dogrulama akisinda sifre login fallback bozulmaz
- Kullanici sadece kendi bildirimlerini gorur/isaretler (RLS)
- Admin/president panelden hedefli veya toplu bildirim gonderebilir
- Odeme baslatma edge function ile kayit altina alinir, onay flow'u invoice durumunu gunceller
- Admin KPI metrikleri tek RPC cagrisiyla panelde goruntulenir
- Release workflow tag/manual tetiklemede APK + release + public deploy akisini kapsar

### FAZ-8: Etkinlik + Destek/SOS + Odeme Mutabakat Operasyonu
Status: Completed
Deliverables:
- `supabase/migrations/0009_community_features_init.sql`
- `supabase/migrations/0010_community_features_rls.sql`
- `supabase/migrations/0011_events_rls_fix.sql`
- Flutter:
  - `Etkinlikler` modulu (liste + RSVP + admin status yonetimi)
  - `Destek Merkezi` modulu (ticket + mesaj thread + SOS incident)
  - Yonetim panelinde odeme mutabakat kuyru gu + gecmis log gorunumu
  - Organizasyon panelinde uye rol/durum yonetimi
Acceptance criteria:
- Aktif uye etkinlikleri gorur ve RSVP secimi yapar
- Uye destek talebi/SOS kaydi acabilir
- Admin/president tum destek/incident kayitlarini gorebilir ve guncelleyebilir
- Ticket mesajlasma akisi (kullanici/admin) calisir
- SOS olusturmada konum izni varsa lat/lon otomatik kaydedilir
- `confirm_payment` her guncellemede `payment_reconciliation_logs` kaydi uretir
- `flutter analyze` ve `flutter test` yesil

## Key Risks

1. RLS misconfiguration risk
- Mitigation: central helper functions + explicit policies per table + admin smoke test list.

2. Multi-step Edge Function consistency risk
- Mitigation: best-effort rollback branches + audit trail for all critical transitions.

3. Membership status public query abuse risk
- Mitigation: ID-based lookup through a security-definer RPC with limited result shape.

4. Mobile UX mismatch with DB activation rules
- Mitigation: hard route guard for inactive users and dedicated pending approval screen.

5. Marketplace abuse/spam risk
- Mitigation: RLS + ownership policies + status constraints; sonraki fazda rate-limit + moderation eklenecek.

## Finalization Notes

- Code and CI gates are green (`flutter analyze`, `flutter test`).
- Remaining work is operational rollout only:
  - Supabase migration/function deploy
  - domain configuration for HTTPS app link host
  - release APK build and manifest publish
  - new migrations (`0005`, `0006`, `0007`, `0008`) prod ortamina uygulanacak
