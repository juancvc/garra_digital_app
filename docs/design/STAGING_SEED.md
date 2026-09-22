# Staging product seed (Garra Digital)

## Goal

Staging must feel like a living community for UI/UX evaluation: posts, communities,
businesses, products, events, solidaria, benefits, sponsors, and match context.

User-visible copy must **never** say DEMO / TEST / SEED / FAKE / MOCK.

## Mechanism

Idempotent operator script (preferred — no HTTP backdoor):

```
api/scripts/staging/seed-product-demo.ps1
```

Requires:

```
ALLOW_STAGING_SMOKE=true
STAGING_BASE_URL=https://<staging-host>
STAGING_EXPECTED_HOST=<staging-host>
STAGING_ACCESS_TOKEN=...          # optional actor
STAGING_ADMIN_ACCESS_TOKEN=...    # optional admin verify flows
```

Run from `api/`:

```powershell
$env:ALLOW_STAGING_SMOKE='true'
$env:STAGING_BASE_URL='https://YOUR_STAGING_HOST'
$env:STAGING_EXPECTED_HOST='YOUR_STAGING_HOST'
# optional tokens...
.\scripts\staging\seed-product-demo.ps1 -DataSetName 'crema-vivo'
```

Property flag (documentation / future runners):

```
garra.staging.seed-enabled=${GARRA_STAGING_SEED_ENABLED:false}
```

Default **false**. Do not turn on in production.

## Images / R2

Marketplace and sponsor URLs require **https** absolute URLs.

If media storage (R2) is enabled on staging:

1. Confirm `MEDIA_STORAGE_ENABLED=true`
2. Confirm `MEDIA_PUBLIC_BASE_URL` points at the public CDN/base
3. Upload covers/avatars/products via existing media upload APIs used by the app
4. Re-run the seed script so posts/listings attach media asset IDs or https URLs

Manual ops (no Railway CLI / no Cloudflare CLI from agents):

| Step | Owner |
|------|--------|
| Confirm R2 bucket + public base URL env vars on staging | Operator |
| Upload hero images if seed used placeholder https | Operator |
| Run `seed-product-demo.ps1` once after deploy | Operator |

## Target counts (approx.)

| Domain | Count |
|--------|------:|
| Posts | 12–20 |
| Communities | 6 |
| Businesses / stores | 8 |
| Products / listings | 15–20 |
| Events | 5 |
| Solidaria | 4 |
| Benefits | 6 |
| Sponsors | 3 |

Exact numbers depend on admin token availability for verify/approve steps.
