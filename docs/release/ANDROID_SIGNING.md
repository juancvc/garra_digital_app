# Android signing (manual)

Cursor does **not** generate, share, or commit keystores or passwords.

## Files (gitignored)

- `android/key.properties`
- `*.jks` / `*.keystore`

## key.properties template

```
storePassword=***
keyPassword=***
keyAlias=upload
storeFile=../keystore/garra-upload.jks
```

## Gradle behavior

- If `android/key.properties` exists → release uses upload signing config
- If missing → release falls back to debug signing for local `flutter run --release` only

## Play status

`AAB_SIGNING_MANUAL_PENDING` until a real upload key is created offline and configured.

Never commit secrets.
