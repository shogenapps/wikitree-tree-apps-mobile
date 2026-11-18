# The WikiTree Browser Extension in the app

The app runs the WikiTree Browser Extension (WBE) on the wikitree.com pages it opens in its page
sheet (profiles, edit pages, Add Person, help pages). The Tree Apps view itself does not get WBE,
so it can't change the Tree Apps layout. WBE comes whole from its own releases: nothing is copied
from it by hand.

## Where it comes from

WBE's release workflows build a "webview" zip next to the Chrome and Firefox zips
(`wbe-<moniker>-<version>-<hash>-webview.zip`). It holds `webview.json`, the page bundle
(`wbe-webview.js`), the early script (`wbe-early.js`), the settings page (`options.html`,
`wbe-options.js`) and WBE's images, CSS and fonts. The bundles carry WBE's own stand-in for the
browser extension APIs.

`shared/wbe.lock` names the release, the asset and its SHA-256. At build time
`scripts/fetch-wbe.sh` downloads it, checks the SHA-256 and unpacks it into `shared/wbe/`, which
is not committed. The Android build runs it before every build (Gradle task `fetchWbe`), and
skips the download when `shared/wbe/` already holds that build.

WBE's `stable`, `preview` and `test/development` releases are replaced every time their workflow
runs, so the asset in the lock file disappears at the next WBE release. The build then fails with
a message saying so, until the lock is updated.

## Moving to a new WBE build

```sh
scripts/update-wbe.sh            # newest build on the release the lock names now
scripts/update-wbe.sh preview    # or switch to another release: stable, preview, test/development
```

It rewrites `shared/wbe.lock` and fetches the build. Build the app, check a profile, an edit page
and WBE's settings on a phone, then commit the lock file.

To try a WBE build from your own machine without a release:
`WBE_ZIP=/path/to/dist-webview.zip ./gradlew assembleDebug` (its SHA-256 is not checked).

## How it runs (Android)

`Wbe.kt` does the app's side:

- **Files.** `https://www.wikitree.com/__wbe/...` is answered from the app's assets
  (`WebViewClient.shouldInterceptRequest`), so the site treats WBE's files as its own and its
  Content Security Policy allows them.
- **Injection.** One document-start script on `https://www.wikitree.com` pages defines
  `window.__wbeHost` and then runs `wbe-early.js` and `wbe-webview.js`. On WBE's own settings page
  only the host is defined, because `options.html` loads its own bundle. The script also lets the
  settings page (laid out for a 780 px popup) fit a phone.
- **Host calls** arrive over a web message listener that only `https://www.wikitree.com` can use:
  `storage.get`, `storage.set`, `storage.remove` and `storage.clear` (areas `sync` and `local`, kept in
  SharedPreferences and shared by every web view), `openOptions` (WBE's settings in a new sheet)
  and `openUrl` (wikitree.com in a new sheet, other sites in the browser).
- **Changes.** When a page changes a setting, every other open WBE page gets a `storageChanged`
  event. The page that wrote it is left out, because it already fired its own `onChanged`.
- **WBE button** in the sheet's bar: Extension settings; Notes, Clipboard, Wikitable Wizard and
  Color Blind Simulator (the same messages WBE's right-click menu sends), listed only when their
  feature is running on the page (WBE marks each running feature with `data-wbe-<id>` on `<html>`);
  and Turn off/Turn on. WBE is on unless the member turns it off.
- **After settings change**, closing the settings sheet reloads the page underneath, so the change
  shows straight away.
- **Settings page on a phone.** WBE's settings are laid out for a 780 px popup. The app adds a few
  CSS rules on that page (options button on the feature's line, creator under the name). These
  would be better in WBE's own `options.css` as a narrow-screen media query.

Needs a WebView with document-start scripts and web message listeners (any current Android System
WebView). Without them, or when the app was built without WBE, the WBE button is hidden.

## Not in the app yet

- WBE features that need its background script: Genie, Duplicates, the Gold Standard inspector and
  the AI features. WBE's webview build turns them off (`disabledFeatures` in `webview.json`).
- Backup and Restore from the WBE menu (downloads and file pickers need more work in a web view).
- iPhone: `WKURLSchemeHandler` can't answer `https://www.wikitree.com/__wbe/`, so the iOS side needs
  a different way to serve WBE's files.
- Settings don't sync with WBE on a computer. They stay on the phone.
