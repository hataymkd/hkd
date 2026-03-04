# HKD Push Worker

Bu worker, Supabase `send_notification` edge function tarafindan cagrilan push koprusudur.

## Beklenen Request

- `POST`
- Header:
  - `Authorization: Bearer <PUSH_WEBHOOK_AUTH>` veya `x-api-key`
- JSON body:
  - `token` (device token)
  - `title`
  - `body`
  - `category` (opsiyonel)
  - `data` (opsiyonel)

## Env / Binding

- `PUSH_WEBHOOK_AUTH` (zorunlu)
- `FCM_SERVICE_ACCOUNT_JSON` (gercek Android dispatch icin zorunlu, FCM HTTP v1 service account JSON)

## Deploy

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\secrets_load.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\deploy_push_worker.ps1
```

Eger `FCM_SERVICE_ACCOUNT_JSON` ayarlanmazsa worker auth kontrolu gecer fakat provider dispatch basarisiz doner.
