# HKD Decision Log

## 2026-02-28

1. Invite acceptance auth flow
- Decision: OTP/SMS not used for now.
- Impact: invite acceptance uses token + phone + password in `accept_invite`.

2. Password ownership
- Decision: user defines own password.
- Impact: invite acceptance takes password from user input; membership approval path can still use generated temp password when needed for admin flow.

3. Dernek approval rejection handling
- Decision: disable/suspend behavior (no hard delete).
- Impact: rejected users remain inactive (`profiles.is_active=false`).

4. Dues pricing strategy
- Decision: period-based amount.
- Impact: dues tracked by monthly `dues_periods` (`YYYY-MM`) and per-user invoices.

5. Organization ownership model
- Decision: single owner, multiple managers.
- Impact: DB enforces one owner per org via partial unique index; manager role remains multi-user.

6. Phone normalization rule
- Decision: E.164 mandatory.
- Impact: DB check constraints and repository normalization enforce `+`-prefixed format.

7. Inactive account access policy
- Decision: inactive users can only see own profile and pending approval screen in app.
- Impact: RLS gates module tables with `is_user_active`, Flutter route guard redirects to pending approval.

8. Membership status lookup for public user
- Decision: ID-based lookup via security-definer RPC.
- Impact: avoids broad anon table read while allowing non-authenticated status check by tracking ID.

9. Invite deep link strategy
- Decision: both custom scheme (`hkd://invite`) and HTTPS app-link (`https://<host>/invite`) supported.
- Impact: invite token can be consumed from app-open deep links with startup and in-app routing.

10. Membership approval password fallback
- Decision: admin approval can accept optional temp password; if empty, server generates strong temporary password.
- Impact: management panel can complete approvals without blocking account creation and can copy generated password for out-of-band delivery.

## 2026-03-02

11. Is arama + isci arama modeli
- Decision: two-sided marketplace eklenecek; tek ekranda "Is Bul" + "Kurye Ara" sekmeleri olacak.
- Impact: `job_posts`, `job_applications`, `courier_profiles` tablolari ve Flutter `jobs` feature'i eklendi.

12. Yetki modeli (is pazari)
- Decision: is ilani olusturma yetkisi admin/president veya organization owner/manager; basvuru yapma yetkisi aktif kullanicilar.
- Impact: RLS tarafinda job post manage policy + application self policy + organization role kontrolleri eklendi.

13. Ilk kapsam siniri
- Decision: ilk teslimatta mesajlasma/sohbet yok; basvuru notu + iletisim telefonu ile basit akis.
- Impact: MVP hizli cikis, ileride sohbet ve eslesme skorlamasi icin genisletilebilir zemin.

## 2026-03-03

14. OTP login ekleme stratejisi
- Decision: sifre login korunacak, OTP login ikinci mod olarak eklenecek.
- Impact: SMS provider hazir degilse sifre login ile kesintisiz devam; provider hazir oldugunda OTP aktif kullanilabilir.

15. Push/Bildirim yaklasimi
- Decision: dis push servisinden bagimsiz olarak `user_notifications` + `device_push_tokens` altyapisi eklenecek.
- Impact: uygulama ici bildirim kutusu hemen kullanilir; FCM/APNS entegrasyonu token tablosu uzerinden sonradan devreye alinabilir.

16. Odeme saglayici entegrasyon modeli
- Decision: provider-spesifik dogrudan kod yerine edge function uzerinden checkout koprusu kurulacak (`create_payment_checkout`, `confirm_payment`).
- Impact: mobile client sade kalir, saglayici degisimi function env/config seviyesinde yapilabilir.

17. Admin KPI raporlama
- Decision: panelde raporlar RPC (`admin_report_snapshot`) ile tek cagri metrik modeliyle sunulacak.
- Impact: yonetim paneli performansi korunur, metrikler tek noktadan genisletilebilir.

18. Release otomasyon sekli
- Decision: mevcut CI korunup ek olarak tag/manual tetiklenen release workflow eklenecek.
- Impact: analyze/test + APK release + Cloudflare publish akisi tekrar edilebilir ve izlenebilir hale gelir.

19. Etkinlik modulu
- Decision: dernek toplanti/duyuru takvimi icin etkinlik + RSVP modeli eklenecek.
- Impact: `community_events` ve `community_event_rsvps` ile uye katilim takibi uygulama icinden yonetilir.

20. Destek ve SOS yaklasimi
- Decision: ticket ve acil durum iki ayri kanal olarak ayni "Destek Merkezi" ekraninda sunulacak.
- Impact: `support_tickets` operasyonel sorunlar icin; `safety_incidents` sahadaki kritik olaylar icin kullanilir.

21. Odeme mutabakat audit zorunlulugu
- Decision: admin odeme durum degisikliginde mutabakat logu DB seviyesinde tutulacak.
- Impact: `confirm_payment` edge function her gecis icin `payment_reconciliation_logs` tablosuna iz birakir.

22. Organizasyon uye yonetimi
- Decision: owner/manager seviyesinde uye rolu ve pending/active durum guncelleme UI'den yapilabilir olacak.
- Impact: operasyon hizi artar; owner transferi tek-owner constraint korunarak repository seviyesinde gerceklestirilir.

23. Community events RLS duzeltmesi
- Decision: admin/president etkinlik policy'sinde `created_by=auth.uid()` kisiti kaldirilacak.
- Impact: tum admin/president kullanicilar published event kayitlarini operasyonel olarak yonetebilir.

24. Destek ticket mesajlasma thread
- Decision: support_tickets icin mesaj akisi tek pencere thread modeliyle eklenecek.
- Impact: uye-admin iletisim gecmisi `support_ticket_messages` tablosunda izlenebilir hale gelir.

25. SOS konum zenginlestirme
- Decision: kullanici izin verirse incident kaydina otomatik lat/lon eklenecek, izin yoksa akisi engellemeyecek.
- Impact: kritik olaylar sahada daha hizli konumlanir; fail-safe davranis korunur.

26. Harici push dispatch modeli
- Decision: `send_notification` function icinde webhook tabanli push dispatch eklenecek (`PUSH_WEBHOOK_URL`).
- Impact: `device_push_tokens` kayitlari gerçek bildirim dagitiminda kullanilabilir; provider bagimsiz entegrasyon korunur.

27. Cloudflare worker push provider standardi
- Decision: `hkd-push-webhook` worker auth dogrulamasi zorunlu olacak ve Android push icin FCM HTTP v1 (`FCM_SERVICE_ACCOUNT_JSON`) ile dispatch yapacak.
- Impact: Supabase sadece webhook cagirir; provider credential'i client yerine worker env'de tutulur. `FCM_SERVICE_ACCOUNT_JSON` yoksa dispatch fail-safe olarak hata doner ve audit `push_failed` sayaci artar.
