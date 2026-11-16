# SasaTap

SasaTap is a Flutter NFC toolkit. Use the web build for a UI demo and the Android
release on an NFC-capable phone for tag reading and writing.

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
docker build -t sasatap-web .
docker run --rm -p 8080:8080 sasatap-web
```

Then open <http://localhost:8080>. The container also provides a `/healthz`
endpoint for deployment health checks.
