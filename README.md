# SasaTap

SasaTap is a Flutter NFC toolkit. Use the web build for a UI demo and the Android
release on an NFC-capable phone for tag reading and writing.

## Supabase accounts and saved tags

SasaTap uses Supabase Auth and Postgres for account-scoped saved tags. Email and
password plus email magic links are supported. Tags are private by default;
sharing a tag with an organization makes it visible to that organization's
members, while only its owner can edit or remove it. Users can have no
organization or belong to multiple organizations. Offline saved-tag caches and
pending sync operations are partitioned by authenticated user.

1. Create a Supabase project and apply
   `supabase/migrations/20261116000100_saved_tags_tenant_isolation.sql` using
   the Supabase CLI or SQL editor.
2. In **Authentication → URL Configuration**, add the web demo URL and
   `com.sasatap.app://login-callback/` to the allowed redirect URLs. Configure
   email confirmation and the magic-link email template for your deployment.
3. Configure `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and
   `SUPABASE_AUTH_REDIRECT_URL` as compile-time Dart defines. For local web
   development, use a fixed port and add the same URL to Supabase's redirect
   allow list:

   ```powershell
   flutter run -d chrome --web-port 3000 `
     --dart-define="SUPABASE_URL=https://YOUR_PROJECT.supabase.co" `
     --dart-define="SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY" `
     --dart-define="SUPABASE_AUTH_REDIRECT_URL=http://localhost:3000/"
   ```

   For Android, set the redirect define to
   `com.sasatap.app://login-callback/`.
4. Add `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` as GitHub Actions
   repository secrets. The Pages and Android workflows pass these values to
   their Flutter builds. The Pages workflow redirects auth links back to the
   deployed site; allow `https://kimani2-lab.github.io/SasaTap/` in Supabase.

Only the Supabase publishable key belongs in the client. Never put a
service-role key in the app, a build define, or a GitHub Actions secret used by
these client builds. Row-level security in the migration enforces saved-tag
access. Organization membership is provisioned by a trusted project
administrator; self-service organization creation and invitations are not
implemented. A tag can be shared with one organization at a time. Existing
`sasatap.saved_tags.v1` device-wide data is deliberately not auto-imported into
an account, because that old cache may contain another person's tags on a
shared device. If the required Dart defines are missing, SasaTap displays a
setup screen and does not expose saved-tag access.

When offline, saved-tag changes are kept in the signed-in account's cache and
queued for sync. Pull down on the **Saved** page to retry synchronization.

## Web demo on GitHub Pages

The `Deploy web demo to GitHub Pages` workflow builds the app with the
`/SasaTap/` base path and deploys it whenever code is pushed to `main`.

1. In the repository, open **Settings → Pages** and set the source to **GitHub
   Actions**.
2. Push to `main`, or run the workflow manually from the **Actions** tab.
3. Visit <https://kimani2-lab.github.io/SasaTap/> after the deployment finishes.

## Android release

The `Build Android release` workflow runs manually or when a `v*` tag is
pushed. It builds a signed APK for device installation and a signed AAB for
Google Play, uploads both as workflow artifacts, and attaches them to a GitHub
Release for version tags.

Before running it, create an upload keystore and keep a secure backup:

```powershell
keytool -genkeypair -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias sasatap-upload
```

In the repository's **Settings → Secrets and variables → Actions**, add:

- `ANDROID_KEYSTORE_BASE64` — base64 encoding of the keystore file.
- `ANDROID_KEYSTORE_PASSWORD` — keystore password.
- `ANDROID_KEY_ALIAS` — `sasatap-upload` (or the alias chosen above).
- `ANDROID_KEY_PASSWORD` — key password.

To copy the keystore's base64 value to the clipboard in PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('android/app/upload-keystore.jks')) | Set-Clipboard
```

Do not commit the keystore or passwords. Increment the app version and build
number in `pubspec.yaml` before creating each new release tag. The APK can be
installed on an Android phone with NFC; upload the AAB to Google Play Console
for Play Store distribution. For example:

```sh
git tag v1.0.1
git push origin v1.0.1
```

## Optional container deployment

The Docker image builds the Flutter web release and serves it with unprivileged
Nginx on port `8080`:

```sh
docker build -t sasatap-web \
  --build-arg SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --build-arg SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY \
  --build-arg SUPABASE_AUTH_REDIRECT_URL=http://localhost:8080/ .
docker run --rm -p 8080:8080 sasatap-web
```

In PowerShell, use backticks for line continuation:

```powershell
docker build -t sasatap-web `
  --build-arg SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --build-arg SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY `
  --build-arg SUPABASE_AUTH_REDIRECT_URL=http://localhost:8080/ .
docker run --rm -p 8080:8080 sasatap-web
```

Add `http://localhost:8080/` to the Supabase redirect allow list for local
container testing. Then open <http://localhost:8080>. The container also
provides a `/healthz` endpoint for deployment health checks.
