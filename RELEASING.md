# Releasing — Windows installer + Android APK

CI lives in `.github/workflows/release.yml`. It builds a **Windows Inno Setup
installer** and a **signed Android APK**, then attaches both to a GitHub Release.

## 1. One-time: Android signing keystore

Generate a release keystore (keep `keystore.jks` safe + private — losing it means
you can never update the app under the same signature):

```bash
keytool -genkey -v -keystore keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Add GitHub repo secrets

Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 keystore.jks` (the whole file, one line) |
| `ANDROID_KEYSTORE_PASSWORD` | store password you set above |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key password (often same as store) |

> `base64 -w0` on Linux/macOS. On Windows PowerShell:
> `[Convert]::ToBase64String([IO.File]::ReadAllBytes("keystore.jks")) > keystore.txt`

CI decodes this into `android/app/keystore.jks` and writes `android/key.properties`
at build time. Neither file is committed (`.gitignore` blocks them).

## 2. Cut a release

```bash
git tag v1.0.0
git push origin v1.0.0
```

The tag triggers the workflow. When it finishes, the Release page has:

- `WorldCupLiveTV-Setup-1.0.0.exe` — Windows installer
- `WorldCupLiveTV-1.0.0.apk` — Android app

`workflow_dispatch` (Actions tab → Run workflow) builds the same artifacts
**without** publishing a Release — useful for testing.

## 3. What users do

**Windows:** download the `-Setup-.exe`, run it, click through. Installs to
Program Files + Start-menu/desktop shortcut. Uninstall via Add/Remove Programs.

**Android:** download the `.apk`, open it, allow "Install unknown apps" for the
browser/file manager once, then install.

## Why no Microsoft Store?

Store publishing needs a paid Partner Center account + MSIX + certification
review, and apps streaming third-party live feeds are routinely rejected. The
Inno Setup installer sideloads with zero of that overhead.

## SmartScreen / "Unknown publisher" warning

The installer is **not code-signed**, so Windows SmartScreen shows
"Windows protected your PC". Users click **More info → Run anyway**. To remove
the warning you need a paid Authenticode code-signing certificate (EV cert for
instant reputation); wire `signtool` into the `windows` job if you buy one.

## Local builds (no CI)

```bash
# Android (needs android/key.properties + keystore present locally)
flutter build apk --release

# Windows installer (needs Inno Setup 6: https://jrsoftware.org/isdl.php)
flutter build windows --release
iscc /DAppVersion=1.0.0 windows\installer\setup.iss
# → dist\WorldCupLiveTV-Setup-1.0.0.exe
```