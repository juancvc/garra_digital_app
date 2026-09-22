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

The showcase manifest is schema V2 and enumerates 77 operator-supplied files
across profiles, posts, communities, stores, listings, events, solidarity,
rewards, sponsors and match imagery. Exact filenames and dimensions:

```
api/scripts/staging/assets/ASSET_REQUIREMENTS.md
```

One-command offline validation:

```powershell
cd api
.\scripts\staging\prepare-showcase.ps1 `
  -ShowcaseId 'GARRA_SHOWCASE_V1' `
  -DataSetName 'crema-vivo' `
  -DryRun
```

Live operator flow, only after review and local assets are present:

```powershell
$env:ALLOW_STAGING_SMOKE='true'
$env:STAGING_BASE_URL='https://YOUR_STAGING_HOST'
$env:STAGING_EXPECTED_HOST='YOUR_STAGING_HOST'
$env:STAGING_ADMIN_ACCESS_TOKEN='...'

.\scripts\staging\prepare-showcase.ps1 `
  -ShowcaseId 'GARRA_SHOWCASE_V1' `
  -DataSetName 'crema-vivo'
```

The uploader uses existing APIs:

1. `POST /api/v1/media/uploads`
2. Upload bytes to `uploadUrl`
3. `POST /api/v1/media/{assetId}/confirm`
4. Attach through verified post, clan, marketplace and sponsor contracts
5. Persist upload/association state atomically in the manifest for re-runs

Requires staging env:

- `MEDIA_STORAGE_ENABLED=true`
- `MEDIA_PUBLIC_BASE_URL=https://…`

Profiles, events and match currently have no media attachment endpoint.
Submitted solidarity campaigns and active rewards have no safe media backfill.
Those 32 manifest entries are reported as `BLOCKED`, while 45 entries use
verified contracts. Therefore tooling reports `PARTIAL` honestly until those
backend gaps are implemented; it never treats blocked media as success.

**Single manual operator step (no Railway CLI / no Cloudflare CLI):**

1. Place the 77 royalty-safe files under `api/scripts/staging/assets/` exactly
   as listed in `ASSET_REQUIREMENTS.md`, provide the guarded environment values
   above, and run the single `prepare-showcase.ps1` command.
2. Verify supported images render in the physical-device app and retain the
   redacted preparation report.

Do **not** declare `STAGING_IMAGES=PASS` until remote UI evidence exists.

## Report keys from script

```
FANS / POSTS / COMMUNITIES / BUSINESSES / STORES / LISTINGS
EVENTS / SOLIDARITY / BENEFITS / SPONSORS
COMMENTS / REACTIONS / FOLLOWS / SAVED / IMAGES
FAILED_OPERATIONS
SEED_RESULT=PASS|PARTIAL|FAIL
```
