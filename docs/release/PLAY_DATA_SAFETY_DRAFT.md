# Play Data Safety inventory (DRAFT source)

> Fill Play Console later from this inventory. **Do not invent final Console answers.**

| Data / SDK | Collection | Purpose | Storage | Sharing / processor | Retention | Optional/Required |
|---|---|---|---|---|---|---|
| Firebase Auth | identifiers | auth | Firebase + backend user row | Google Firebase | account lifetime / deletion | Required |
| Email | account | auth / contact | Postgres | Hosting provider | until deletion anonymize | Required |
| Username / display name | profile | community identity | Postgres | none beyond hosting | until deletion | Required |
| Phone | optional profile | profile | Postgres | hosting | until deletion | Optional |
| Photos / avatar / UGC media | media | product | R2 + DB keys | Cloudflare R2 | while referenced + cleanup | Product |
| Precise location | only on explicit map/check-in | maps / check-in | ephemeral / feature tables | Google Maps SDK client | feature retention | Explicit use |
| FCM token | device | push | Postgres | Firebase FCM | until deactivate/delete | Operational |
| Crashlytics | diagnostics | crash reports | Firebase | Google | vendor policy | Opt-in beta |
| Analytics | events | product metrics | Firebase | Google | vendor policy | Opt-in beta |
| Google Maps | map usage | show businesses/routes | client | Google | n/a client | Feature |
| Search queries | processed server-side | search | may log sanitized | hosting | short | Product — **do not** put raw query in Analytics |

Account deletion URL (external): `GET /account-deletion` on API host.
Privacy policy URL: `/legal/privacy` (temporary backend pages until production domain).
