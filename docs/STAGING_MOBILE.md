# Mobile staging / release notes

## Canonical Android applicationId

```text
com.garradigital.app
```

Treat as **permanent** once public Play Store distribution begins. Do not casually rename again.

## Firebase Android client

Register an Android app with package **`com.garradigital.app`** in the staging (preferred) or shared Firebase project, then replace:

```text
android/app/google-services.json
```

Do not invent credentials. Until the console-issued file is present for this package, Google Sign-In / FCM may be blocked.

## API base URL

Default for `flutter run` / debug builds (no dart-define required):

```text
https://garra-digital-u-production.up.railway.app/api/v1
```

Derived WebSocket:

```text
wss://garra-digital-u-production.up.railway.app/ws
```

Override for production or alternate hosts:

```bash
flutter build apk --dart-define=GARRA_API_BASE_URL=https://<prod-or-alt-host>/api/v1
```

WebSocket URL is always derived from the REST base (`https` → `wss`, path `/ws`).

## Refresh tokens

Access + refresh tokens are stored in `flutter_secure_storage` via `SecureStorageService`.

`AuthRefreshCoordinator` + Dio interceptor handle single-flight 401 refresh against `POST /api/v1/auth/refresh` without modifying protected `lib/features/auth/data/auth_service.dart`.

Recommended staging/prod access TTL when refresh is live: `JWT_EXPIRATION_MINUTES=30` (backend env only).

## App display name

Android label: **Garra Digital**

## Signing

Staging/internal: debug signing acceptable. Production keystore: **manual** — do not generate random production keys in Cursor.
