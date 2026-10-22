# Development

## Setup

- Flutter stable (built with 3.47) and its bundled Dart SDK.
- Android SDK with platform tools (`adb`). Android Studio installs both.
- A phone with **USB debugging** on, or an Android emulator.

```powershell
flutter pub get
flutter doctor        # check the toolchain
```

## Everyday commands

```powershell
flutter analyze                     # lints (flutter_lints)
flutter test                        # all unit and widget tests
flutter test test\ranking_test.dart # one file
flutter run                         # debug build on a connected device
```

## Building a release APK

```powershell
flutter build apk --release
# → build\app\outputs\flutter-apk\app-release.apk (~56 MB)
```

### Signing

`android/app/build.gradle.kts` signs release builds with the key described in `android/key.properties` when that file exists, and falls back to the debug key otherwise. Neither file is committed.

`android/key.properties`:

```properties
storePassword=…
keyPassword=…
keyAlias=…
storeFile=C:\\path\\to\\upload-keystore.jks
```

Create a keystore once with:

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Back up the keystore and passwords.** Updates to an installed app (and on Google Play) must be signed with the same key.

## Installing on a phone

With the phone connected by USB and debugging allowed:

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb devices
& $adb install -r build\app\outputs\flutter-apk\app-release.apk
```

`install -r` replaces the app and **keeps its data**. Uninstalling first would erase your library.

Switching between a debug-signed and a release-signed build requires an uninstall. Export a backup before you do.

## App icon

Icon sources are in `assets/icon/`. After changing them, regenerate the Android icons:

```powershell
dart run flutter_launcher_icons
```

## Previewing in a browser

The UI also runs on Flutter web, which is handy for quick visual checks:

```powershell
flutter run -d chrome
```

Notes:

- Automatic backups are Android-only and are skipped on web.
- Deezer's API doesn't allow browser (CORS) requests, so band photos only load on web through a local proxy. Cover art and iTunes auto-fill work directly.

## Conventions

- Logic that doesn't need Flutter UI goes in `lib/logic/` and gets unit tests.
- Rating math uses whole half-star units (`Album.ratingHalves`), never raw doubles.
- Services take an optional `http.Client` so tests can pass a `MockClient`.
- New persisted settings get a `albumrank.*` SharedPreferences key in `SettingsController` and a row in [Data and backups](data-and-backups.md).
- Every feature ships with tests; `flutter analyze` must be clean.

## Dependencies

| Package | Used for |
|---|---|
| `shared_preferences` | Storing the library, settings and photo cache |
| `http` | iTunes and Deezer requests |
| `file_picker` | Choosing a backup file to import, and where to save exports |
| `share_plus` | Sharing ranking images |
| `flutter_launcher_icons` (dev) | Generating app icons |
| `flutter_lints` (dev) | Lint rules |
