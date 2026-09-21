# Versioning

## Current app

`pubspec.yaml`: `0.9.0+2`

- `versionName` = `0.9.0` (semver marketing)
- `versionCode` = `2` (monotonic integer for Play)

## Convention (beta)

Prefer `0.9.x+N` until public 1.0.

- Patch for RC fixes
- Always increment `+N` / versionCode for each Play upload
- Never reuse or decrease versionCode

## History note

Prior scaffold used `1.0.0+1` without Play distribution. RC moved to `0.9.0+2` to reflect controlled beta without implying GA.
