# R2 media retention / cleanup

Do not touch Cloudflare live credentials from Cursor.

## Asset classes

| Class | Regenerable? | Retention |
|---|---|---|
| Seed / demo fixtures | Often yes | Low criticality |
| User avatar / post media | No | Keep while referenced; orphan cleanup after deletion grace |
| Deleted-account media | Conditional | Remove when no remaining DB references |

## Rules

- Never delete R2 objects still referenced by DB keys
- Signed uploads: mobile never holds R2 credentials
- Confirm upload failures should be metric'd (`r2_upload_confirm_failures`)
- Orphan cleanup is a worker job — dry-run first

## Deleted accounts

Prefer detach references on anonymize; schedule media GC after grace window.
