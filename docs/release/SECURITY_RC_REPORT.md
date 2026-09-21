# Security RC report

Date: 2026-09-21 (RC 09F)

## Findings

| ID | Severity | Finding | Status |
|---|---|---|---|
| S1 | HIGH | Release builds could previously default to staging API | Mitigated — `GARRA_API_BASE_URL` required in release |
| S2 | HIGH | Account deletion path required for Play | Mitigated — in-app + `/account-deletion` web |
| S3 | MEDIUM | Abuse-prone endpoints without distributed rate limit | Mitigated — Redis `RateLimitFilter` (fail-closed auth) |
| S4 | MEDIUM | Logs may historically include sensitive headers | Mitigated — debug interceptor avoids Authorization bodies; audit ongoing |
| S5 | LOW | Maps API key in local AndroidManifest | Accepted — protected local file, not staged |
| S6 | INFO | Upload signing not configured | `AAB_SIGNING_MANUAL_PENDING` |

## Corrected / verified

- Admin ops under `/api/v1/admin/**` require `ROLE_ADMIN`
- Deleted users treated as locked in `AuthenticatedFan`
- Refresh + device tokens revoked on deletion
- Correlation id is UUID — not PII
- No `/test-login` backdoor

## Remaining manual

- Privacy legal review
- Play Console Data Safety submission
- Infra backup verification
- Production domain + secrets rotation outside Cursor
