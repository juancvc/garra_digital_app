# Incident response (beta)

No dangerous automated commands.

| Incident | Symptoms | Still works | Kill switch | Rollback | Evidence |
|---|---|---|---|---|---|
| API down | 5xx / timeouts | none | maintenance mode page | redeploy previous image | correlation ids, actuator |
| DB down | readiness fail | static legal pages maybe | maintenance | restore from backup drill | DB errors (no secrets) |
| Redis down | rate limit / realtime degrade | core API if fail-open paths | disable redis-dependent features | restart Redis | redis health indicator |
| R2 down | media upload/view fail | text surfaces | disable media compose UX copy | wait / failover | upload confirm metrics |
| FCM down | no push | in-app notifications list | none required | vendor status | push metrics |
| Maps fail | map blank | list/business text | none | Maps key/config check | client diagnostics |
| Bad mobile release | crash spike | web deletion path | Play halt + force update min version | previous AAB | Crashlytics |
| Abuse spike | 429s / reports | reads may continue | feature flags / rate limits | tighten limits | rate limit metrics |
| Media abuse | large uploads | text | MIME/size limits already | ban user | reports queue |

Collect: app version, correlation id, approximate time, endpoint — **never** JWT/FCM/email dumps in tickets.
