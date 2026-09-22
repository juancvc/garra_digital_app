# GARRA_SHOWCASE_V1 — operator runbook

## Scope and positioning

This runbook is only for `GARRA_SHOWCASE_V1`: a short, operator-prepared walkthrough of the current mobile product on a physical Android device.

Garra Digital is a **non-official community made by supporters, for supporters**. Do not describe it as an official club app, imply club ownership or endorsement, or use unlicensed official media.

This document records a repeatable procedure, not proof that staging is ready. This agent does **not** run staging, and no remote health, seed, identity, media, or match evidence is claimed here.

## Verified mobile facts and hard safety gates

- Debug `flutter run`, without a Dart override, uses `https://garra-digital-u-production.up.railway.app/api/v1`.
- The expected WebSocket derived by the app is `wss://garra-digital-u-production.up.railway.app/ws`.
- Release builds require an explicit `GARRA_API_BASE_URL`; this runbook uses a debug build for the physical-device showcase.
- Exact host guard: the preparation flow must parse the configured staging base URL, require HTTPS, and require its host to equal **exactly** `garra-digital-u-production.up.railway.app`. It must also require `STAGING_EXPECTED_HOST` to equal that same literal host. Abort on a suffix, subdomain, alternate host, embedded credentials, HTTP, parse failure, or mismatch; substring matching such as `contains("railway.app")` is not sufficient.
- Never commit, paste into this file, print to captured logs, or share in screenshots any password, access token, refresh token, admin token, signing secret, or service credential. Supply secrets only through the operator's approved secret channel or process environment and clear them after the session.
- The staging product seed is operator-driven; it is not an app startup runner or an HTTP backdoor.

Repository references verified in this checkout:

- [`../STAGING_MOBILE.md`](../STAGING_MOBILE.md) — debug REST/WebSocket configuration.
- [`../design/STAGING_SEED.md`](../design/STAGING_SEED.md) — seed mechanism, target content, media requirements, and report keys.
- [`../design/GARRA_UI_UX_V1_RULES.md`](../design/GARRA_UI_UX_V1_RULES.md) — navigation, screen composition, non-official positioning, and safe admin path.
- [`../release/DEVICE_QA_CHECKLIST.md`](../release/DEVICE_QA_CHECKLIST.md) — real-device evidence remains manual.
- Mobile bundled fallbacks: [`../../assets/visual/garra_stadium_splash.png`](../../assets/visual/garra_stadium_splash.png) and [`../../assets/visual/garra_match_hero.png`](../../assets/visual/garra_match_hero.png). These do not prove record-level staging media.

The backend paths referenced below are not part of this mobile repository.
`api/scripts/staging/prepare-showcase.ps1` is the reviewed orchestration entry
point and coordinates `seed-product-demo.ps1` with
`upload-showcase-media.ps1`. Run it only from the backend repository.

## Seed identities

The prepared dataset should expose these operator-selectable identities without placing their password in source control or this runbook:

1. **Regular supporter** — browses, reacts, comments, follows, saves, and demonstrates the normal profile.
2. **Creator/seller supporter** — owns showcase posts and a populated marketplace store/listing when ownership is needed.
3. **SUPERADMIN supporter** — remains a normal user with the same five-tab app and gains `Perfil → Centro Garra (Administración)`.

Use the identity handles/emails reported by the approved preparation script. Obtain or set the session password through the operator command/script and approved secret channel; do not store the password itself in documentation, command history, screenshots, chat, or the repository. There is no universal password, test-login endpoint, or login backdoor.

## One consolidated operator block

The following is the only command block for the run. It intentionally invokes the planned backend preparation flow, then starts the mobile app on a physical Android device. Replace only operator-local paths and secret retrieval. This agent does not run these staging commands.

```powershell
# OPERATOR ONLY — this agent does not run staging.
# 1) Backend preparation from the backend repository.
Set-Location 'C:\path\to\backend\api'
$env:ALLOW_STAGING_SMOKE = 'true'
$env:STAGING_BASE_URL = 'https://garra-digital-u-production.up.railway.app'
$env:STAGING_EXPECTED_HOST = 'garra-digital-u-production.up.railway.app'
$env:STAGING_ADMIN_ACCESS_TOKEN = '<retrieve through approved operator secret channel>'
.\scripts\staging\prepare-showcase.ps1 -ShowcaseId 'GARRA_SHOWCASE_V1' -DataSetName 'crema-vivo'
if ($LASTEXITCODE -ne 0) { throw 'Showcase preparation failed; do not present.' }

# 2) Remove the token from this shell as soon as preparation completes.
Remove-Item Env:STAGING_ADMIN_ACCESS_TOKEN -ErrorAction SilentlyContinue

# 3) Physical Android launch from this mobile repository.
Set-Location 'C:\projects\garra_digital_app'
adb devices
flutter devices
flutter pub get
flutter run -d '<physical-android-device-id>'
```

The preparation report must identify the intended accounts by role/handle,
never reveal passwords or tokens, and return non-zero if a critical operation
fails. `PARTIAL` is expected while documented media attachment gaps remain;
it must not be presented as full media readiness. Preserve the report outside
public screenshots with secrets redacted.

## Physical Android setup

1. Use a charged physical Android phone with a stable internet connection; disable VPN/proxy settings that would change or intercept the expected host.
2. Enable Developer options and USB debugging, connect with a data-capable cable, unlock the phone, and accept the computer's RSA debugging prompt.
3. Confirm `adb devices` shows exactly the intended device as `device`, not `unauthorized` or `offline`; confirm `flutter devices` resolves the same device.
4. Set a presentation-safe display state: portrait orientation, readable brightness, normal font/display scale, Do Not Disturb, and no personal notifications or overlays.
5. Use the debug launch in the consolidated operator block with no `GARRA_API_BASE_URL` override. Confirm the small staging indicator is present and the startup log reports only the expected API host/scheme/path—never tokens.
6. Cold-start once before the audience run. Preload no secret-bearing screen, and keep a second approved identity available only if switching accounts is required.

## Preflight: do not start the showcase without evidence

The operator must review the planned preparation report and perform these checks immediately before presenting:

- **Host guard:** report shows exact HTTPS host `garra-digital-u-production.up.railway.app` and no redirect or alternate effective host.
- **Health:** perform a fresh `GET https://garra-digital-u-production.up.railway.app/actuator/health`, require HTTP 200 and response status `UP`, reject a redirect to another host, and record the timestamp. The preparation scripts do not replace this evidence.
- **Seed:** `SEED_RESULT=PASS`, `FAILED_OPERATIONS=0`, and useful non-zero/populated results exist for fans, posts, communities, businesses/stores, listings, events, solidarity, benefits, sponsors, comments, reactions, follows, and saved items.
- **Media:** `IMAGES` is populated. For at least one representative post, avatar/cover, community, store, listing, event, solidarity, benefit, and sponsor asset, the planned flow must perform a fresh HTTPS GET, reject cross-host redirects unless explicitly allowlisted by the reviewed media configuration, require HTTP 200 and an `image/*` content type, and record the final URL without query secrets. Each asset must also visibly render on the physical phone. Bundled splash/match images alone are insufficient. Do not call images ready without remote UI evidence.
- **Accounts:** regular, creator/seller, and SUPERADMIN identities can authenticate through the normal login flow; their roles and ownership match the intended route.
- **Feed:** at least one attractive multi-image post from another user is visible and safe to react to; no user-visible copy says demo, test, seed, fake, mock, or dataset.
- **Marketplace:** at least one approved listing opens into a populated store with usable, non-sensitive contact/location data.
- **Match:** the seed specification requires staging to feel populated with a match, but the documented seed target/report does not guarantee match creation. If the seed does not create an active/upcoming match, an authorized operator must configure one through the reviewed backend/admin process before the showcase and verify it on the phone. Do not improvise match data during the presentation.
- **Admin:** Centro Garra opens only from the SUPERADMIN's normal profile and has reviewable, non-sensitive content. Do not change roles or operational switches during the showcase.

If any check fails, stop and present screenshots from a previously approved evidence set only if they are clearly labeled as such; otherwise reschedule. Never manufacture readiness.

## Precise 6-minute showcase route

Target total: **6:00**, acceptable range **5:00–7:00**. Rehearse taps and scrolling on the same physical phone.

### 0:00–0:20 — Splash

- Cold-launch and hold briefly on the atmospheric splash.
- Say: “Garra Digital es una comunidad no oficial, hecha por hinchas para hinchas.”
- **Screenshot-ready:** centered community mark, clean system bars, no notification overlay.

### 0:20–1:40 — Inicio, post, reaction, and multi-image

- Arrive on `Inicio`; show the five tabs: Inicio, Comunidad, Crear, Explorar, Perfil.
- Scroll the populated social feed, pause on a visually strong post from another supporter, and show its 2–4 image layout.
- Add one low-risk reaction, then open comments briefly and return. Do not create a throwaway comment live.
- Mention that the feed centers people, conversation, and match/community inserts rather than a module dashboard.
- **Screenshot-ready:** full Home feed and the multi-image post with identity, text, media, and action row visible.

### 1:40–2:10 — Comunidad

- Open `Comunidad`; show populated discovery/feed content and one community detail without joining or changing membership.
- Return with normal back navigation.
- **Screenshot-ready:** populated Comunidad surface with real cover/avatar imagery.

### 2:10–2:35 — Crear

- Tap `Crear` and hold on `¿Qué quieres crear?`.
- Point out Publicación, Evento, Emprendimiento, Campaña Solidaria, and Comunidad only as enabled by staging configuration.
- Dismiss the sheet; do not submit a new record.
- **Screenshot-ready:** the complete creation intention selector.

### 2:35–3:10 — Explorar

- Open `Explorar`; show search, category chips, and image-forward destinations.
- Briefly scroll through Eventos, Negocios, Comunidades, Marketplace, Garra Solidaria, and Beneficios.
- **Screenshot-ready:** Explorar hero plus destinations with no empty/error state.

### 3:10–4:00 — Marketplace and store

- Enter `Marketplace`, pause on the approved product grid, open one listing, then its populated store.
- Show imagery and safe business context. Do not trigger WhatsApp, phone, maps, purchase, checkout, reporting, seller onboarding, or external links.
- **Screenshot-ready:** Marketplace grid, listing detail, and store identity.

### 4:00–4:40 — Partido

- Return to `Inicio`, select the `Partido` feed tab or the verified match insert, and open the match experience.
- Show the hero, match state/countdown, and available pulse/prediction content without submitting or changing a prediction.
- **Screenshot-ready:** match hero with valid teams/time/state and no placeholder data.

### 4:40–5:15 — Perfil

- Open `Perfil`; show cover/avatar, supporter identity, level/stats, activity/settings entry points, and visible logout.
- Reinforce the non-official community positioning if visible.
- **Screenshot-ready:** profile header and core identity/stats, with private email or sensitive details out of frame.

### 5:15–6:00 — Safe SUPERADMIN and Centro Garra

- Use the already authenticated SUPERADMIN identity, or perform a rehearsed normal logout/login only if the switch reliably fits the time window and no password can be observed or captured.
- Show that SUPERADMIN still has the same five-tab supporter experience.
- Follow `Perfil → Centro Garra (Administración)`.
- Pause on the Centro Garra overview and describe review queues at a high level. Open at most one read-only/populated queue, then back out.
- Do **not** approve/reject records, edit roles, create/activate/close seasons, use kill switches, moderate content, or process deletion requests.
- **Screenshot-ready:** Centro Garra overview without personal data, tokens, destructive confirmations, or sensitive queue details.

## Actions to avoid until evidence exists

Until both seed and record-level media evidence are reviewed:

- Do not claim staging, images, matchday, marketplace, or the complete showcase is ready.
- Do not publish posts, upload media, join/leave communities, follow/block/report users, save items, or submit comments merely to make the environment look populated.
- Do not open empty records, broken image galleries, external contact links, maps, checkout-like flows, or personal-data-heavy admin queues.
- Do not create sellers/listings, approve/reject applications, alter roles, change feature switches, operate seasons, or process account deletion.
- Do not use the SUPERADMIN account as the main product experience; it is a normal supporter identity plus access to Centro Garra.
- Do not expose credentials through screen sharing, shell history, environment dumps, QR codes, logs, autofill suggestions, password-manager overlays, or screenshots.
- Do not state or imply that any remote check passed based on this runbook alone.

## Evidence handoff

For an approved run, retain: preparation timestamp and redacted report, exact effective host, health result, seed summary, representative media URL checks, device model/Android version, app commit/build identifier, account roles used, match setup source, and the screenshot set named by route section. Record failures as failures; do not convert manual or missing evidence into PASS.
