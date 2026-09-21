# Beta metrics contract

Bounded KPI set for controlled beta. Not a full BI stack.

## Product

- DAU / WAU
- Retention D1 / D7 (when Analytics cohorting allows)
- Sessions / user
- `community_view` / feed opens
- `post_created` / `post_photo_created`
- comments
- follows / `fan_followed`
- `community_joined`
- `event_going`
- business follows / `offer_opened`
- `marketplace_opened` / `solidarity_opened`
- `achievement_unlocked_viewed` / `season_viewed`

## Reliability

- Crash-free users (Crashlytics, consented)
- API 5xx rate
- API p95 latency
- Push delivery outcomes (backend metrics; not user PII)

## Rules

- No vanity overload
- No PII labels on metrics
- Event taxonomy lives in `AnalyticsService`
