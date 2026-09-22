# Staging product seed (Garra Digital)

## Goal

Staging must feel like a living crema community for UI/UX QA:
posts, communities, businesses, marketplace listings, events, solidaria,
benefits, and sponsors.

**User-visible copy must never contain:** `demo`, `test`, `seed`, `fake`, `mock`, `dataset`
(case-insensitive).

Technical identifiers (emails, slug prefixes like `crema-vivo-…`) may exist
server-side as long as they are not shown as product copy.

## Mechanism

Operator-driven PowerShell script (no HTTP backdoor, no auto-run in production):

```
api/scripts/staging/seed-product-demo.ps1
```

### Dry run (no staging calls)

```powershell
cd api
.\scripts\staging\seed-product-demo.ps1 -DryRun -DataSetName 'crema-vivo'
```

Validates planned payloads, target counts, and forbidden visible words.

### Live run (operator only — after review)

```powershell
$env:ALLOW_STAGING_SMOKE='true'
$env:STAGING_BASE_URL='https://YOUR_STAGING_HOST'
$env:STAGING_EXPECTED_HOST='YOUR_STAGING_HOST'
$env:STAGING_ADMIN_ACCESS_TOKEN='...'   # required for approvals + rewards + sponsors

.\scripts\staging\seed-product-demo.ps1 -DataSetName 'crema-vivo'
```

Idempotent design:

- Fans: register → on conflict, login
- Communities / stores / listings / rewards / sponsors: GET/list by slug before create
- Marketplace: real contracts only (`POST/PATCH /marketplace/seller/me`, `POST .../store`, `POST .../listings`, submit + admin approve)
- Failures are counted; script exits non-zero if critical ops fail

There is **no** `GARRA_STAGING_SEED_ENABLED` application runner.
Seed is operator-run only.

## Target counts (V1 QA)

| Domain | Count |
|--------|------:|
| Users | 16 |
| Posts | 22 |
| Communities | 6 |
| Businesses / stores | 8 |
| Listings | 17 |
| Events | 5 |
| Solidaria | 4 |
| Benefits | 6 |
| Sponsors | 3 |
| Comments | ≥12 |
| Reactions | ≥20 |
| Follows | ≥15 |
| Saved | ≥6 |

One community / event / solidarity / business application may remain pending for Centro Garra.

## Images / R2

Text seed alone is not enough for visual QA.

The mobile bundle includes two original, rights-safe atmospheric fallbacks:

- `assets/visual/garra_stadium_splash.png`
- `assets/visual/garra_match_hero.png`

They establish brand atmosphere for splash and match surfaces, but they do
**not** replace record-level staging media for posts, people, communities,
businesses, products, events, solidaria, rewards and sponsors.

Manifest:

```
api/scripts/staging/assets/staging-media-manifest.json
```

Upload flow (existing APIs):

1. `POST /api/v1/media/uploads`
2. Upload bytes to `uploadUrl`
3. `POST /api/v1/media/{assetId}/confirm`
4. Attach `mediaAssetId` / public https URL on domain records

Requires staging env:

- `MEDIA_STORAGE_ENABLED=true`
- `MEDIA_PUBLIC_BASE_URL=https://…`

**Manual operator step (no Railway CLI / no Cloudflare CLI):**

1. Drop royalty-safe images into `api/scripts/staging/assets/` per manifest filenames  
2. Confirm media env vars on staging  
3. Upload + attach via media APIs (or an approved internal tool)  
4. Verify images render in the app  

Do **not** declare `STAGING_IMAGES=PASS` until remote UI evidence exists.

## Report keys from script

```
FANS / POSTS / COMMUNITIES / BUSINESSES / STORES / LISTINGS
EVENTS / SOLIDARITY / BENEFITS / SPONSORS
COMMENTS / REACTIONS / FOLLOWS / SAVED / IMAGES
FAILED_OPERATIONS
SEED_RESULT=PASS|PARTIAL|FAIL
```
