# Garra Digital — Privacy Policy (TECHNICAL DRAFT)

> **Not legal advice.** This draft describes what the Garra Digital beta system actually does so counsel can produce a final policy. Do not present this as GDPR/LGPD certification.

## Who we are

Garra Digital is an **independent fan community** for supporters of Universitario de Deportes. It is **not** an official club application.

## Data we process (beta)

| Category | Examples | Required? |
|---|---|---|
| Account | email, username, display name, password hash / Google auth identifiers | Yes |
| Profile | city, country, avatar, visibility settings, interests | Optional / product |
| Device | FCM device tokens, OS/app version in diagnostics | Operational |
| Content (UGC) | posts, comments, reactions, reports, media object keys | Product |
| Location | precise location only when user explicitly uses map/check-in features | Explicit use |
| Telemetry | Analytics events (opt-in), Crashlytics (opt-in) | Opt-in in beta |
| Support | beta feedback messages, optional correlation id | Voluntary |

## Purposes

- Authenticate and secure sessions (JWT + refresh rotation)
- Deliver community, matchday, marketplace, solidaria, events surfaces
- Send push notifications the user enabled
- Operate moderation, abuse controls, and account deletion
- Improve reliability via consented diagnostics/analytics

## Sharing / processors (typical)

- Hosting/database (e.g. Railway Postgres)
- Redis (rate limit / realtime optional)
- Cloudflare R2 (media objects via signed uploads)
- Firebase Auth / FCM / Crashlytics / Analytics (when enabled)
- Google Maps (client Maps SDK; key configured on device build)

## Retention (see DATA_RETENTION_MATRIX.md)

Account deletion anonymizes identifiers and revokes sessions. Some integrity/audit rows may remain without unnecessary PII.

## Contact

Support URL may be published via `/api/v1/app-config` when available.
