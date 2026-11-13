# WikiTree Tree Apps for mobile

A phone app that shows the [WikiTree Tree Apps](https://www.wikitree.com/apps/) with nearly the whole
screen given to the app itself. It is a thin shell: it loads the real Tree Apps page from wikitree.com,
hides the site's header, Tree App/ID bar and footer, and adds a slim bar of its own. The Tree Apps
themselves come from [wikitree/wikitree-dynamic-tree](https://github.com/wikitree/wikitree-dynamic-tree),
so fixes there appear in the app without a new release.

## Layout

| Folder | What's in it |
| --- | --- |
| `shared/` | Pieces any platform can use. `shell.js` is injected into the Tree Apps page to hide the site bars and report state (person, app, login) to the shell. `views.json` is the Tree App list used before the page loads its own. |
| `android/` | The Android app (Kotlin, one Activity with a WebView). |
| `ios/` | The iPhone and iPad app (SwiftUI, a `WKWebView`), using the same `shared/` files. Open `ios/TreeApps.xcodeproj` in Xcode and run it in the Simulator. |

## The shell's bar

- **Tree App name**: tap to switch apps. The page switches in place, without reloading.
- **WikiTree ID**: tap to change person.
- **⋮ menu**: Apps login/logout, reload, open the profile or page in the browser, and a switch to show the
  site's own bars again if something is hidden that shouldn't be.

Each Tree App's own settings and controls are left exactly as they are on the website.

## Trying the Android app

Every push to `main` builds an APK with GitHub Actions and attaches it to the
**Android test build** release (tag `android-test`). Open that release on your phone, download
`wikitree-tree-apps.apk` and install it (Android will ask you to allow installs from your browser the
first time). New builds install over the old one.

To build locally: open `android/` in Android Studio, or run `./gradlew assembleDebug` in `android/`.

## Before a store release

- Choose the final application id (currently `org.wikitree.treeapps`); it can't change after the first upload.
- Sign with a private release key kept out of this repo. `android/app/testing.keystore` is a throwaway key
  for test builds only.
- Replace the placeholder icon with WikiTree Apps project artwork.
- Publish under a WikiTree Apps project developer account.
