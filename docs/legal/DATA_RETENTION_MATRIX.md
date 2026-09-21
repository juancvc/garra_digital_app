# Data retention matrix (beta technical)

> Not a compliance certification. Documents intended beta behavior.

| Data class | Active account | After deletion request | Notes |
|---|---|---|---|
| Email / phone / avatar / display name | Kept | Anonymized / cleared | Tombstone email `@deleted.garra.invalid` |
| Auth providers / refresh tokens | Kept | Revoked / cleared | Blocks further sessions |
| Device tokens (FCM) | Kept | Deactivated | |
| Preferences / follows / blocks / saves | Kept | Removed or anonymized | Prefer delete graph edges |
| Posts / comments (UGC) | Public | Removed from public surfaces; author pseudonymized if row retained | Integrity preference |
| Media objects (R2) | Kept while referenced | Orphan cleanup job; do not delete still-referenced objects | See R2 runbook |
| Reports / security audits | Minimal | May retain without unnecessary PII | Documented reason only |
| Beta feedback | Kept | Fan id may null; message retained for ops | |
| Analytics / Crashlytics | Vendor retention | Stop new collection on consent off / delete | Vendor policies apply |
| External deletion requests | Kept | Status PROCESSED/REJECTED | Email needed for verification workflow |

Proposed beta RPO/RTO targets: see `docs/runbooks/DATABASE_BACKUP_RESTORE.md` (manual infra verification required).
