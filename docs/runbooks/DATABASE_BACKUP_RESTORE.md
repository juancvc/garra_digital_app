# Database backup / restore runbook

`INFRA_MANUAL_VERIFICATION_REQUIRED` — Cursor does not touch Railway.

## What to back up

- Postgres primary data (all app schemas)
- Prefer logical dump + provider snapshot if available

## Frequency (proposed beta)

- Daily automated snapshot if Railway plan supports it — **verify manually**
- Before risky migrations: manual dump

## Restore drill

1. Restore dump to a **non-production** database
2. Point a staging instance via config (do not overwrite live blindly)
3. Run `./mvnw test` subset + smoke health
4. Validate Flyway version matches

## Validation

- Row counts on `fan_users`, `community` posts sample
- Login works
- `/actuator/health` UP

## Proposed targets (beta aspiration)

- RPO ≤ 24h
- RTO ≤ 4h

Do **not** claim automated backups are active until verified in Railway console.
