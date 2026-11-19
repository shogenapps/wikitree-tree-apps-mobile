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
so does the iPhone build (the "Fetch WikiTree Browser Extension" build phase, which then copies
`shared/wbe/` into the app as `wbe/`). Both skip the download when `shared/wbe/` already holds
that build.

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
  SharedPreferences and shared by every web view), `openOptions` (WBE's settings in a new sheet),
  `openUrl` (wikitree.com in a new sheet, other sites in the browser) and `net.fetch` (WBE's AI
  requests, see below).
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

## How it runs (iPhone)

`ios/TreeApps/Wbe.swift` does the same jobs, with one difference: iOS can't answer
`https://www.wikitree.com/__wbe/`, so WBE's files are served on the app's own `wbe-app:` scheme
(`WKURLSchemeHandler`) and `__wbeHost.base` is `wbe-app://app/`. The bundles themselves are
injected as `WKUserScript`s, which the site's Content Security Policy doesn't apply to; WBE's
images, CSS and page scripts are loaded from `wbe-app://app/`, so they rely on the site's policy
allowing that scheme.

- Host calls come over a `WKScriptMessageHandlerWithReply` named `wbeNative`, in the page's world,
  accepted only from `https://www.wikitree.com` and `wbe-app:` frames.
- Settings live in `Application Support/wbe/sync.json` and `local.json`.
- The page sheet has a **WBE** menu with the same items as on Android, reloads the page after the
  settings sheet changed something, and leaves the person's name out of the bar on a profile.

## Genie and the AI features

Genie, Auto Bio's Improve with AI, the AI Change Explanation and Find and Replace's Ask Genie use the
member's own API key (BYOK) with OpenAI, Google Gemini, Anthropic (Claude), Perplexity, xAI (Grok) or
Ollama Cloud. In the extension, WBE's background script makes those requests. In the app, WBE's
`ai_requests.js` runs in the page and sends each request to the app as the `net.fetch` host call,
and the app makes it (`WbeAi.kt`, the "AI requests" part of `Wbe.swift`), so no CORS rules apply.

- Only the providers' API hosts are allowed (`api.openai.com`, `generativelanguage.googleapis.com`,
  `api.anthropic.com`, `api.perplexity.ai`, `api.x.ai`, `ollama.com`). Anything else is refused.
  Redirects aren't followed, so the key only goes to the provider.
- **Consent.** The first time WBE sends to a provider, the app asks "Send to <provider>?" and says
  what goes there (the question and details from the WikiTree pages used, such as names, dates and
  places). Allow is remembered for that provider. Don't allow refuses that one request, so the next
  one asks again. Apple's guideline 5.1.2(i) asks for this before personal data goes to a
  third-party AI. To stop, the member removes their key in WBE's AI Settings.
- Genie is a separate file, `wbe-genie.js`, loaded only when Genie is opened, because it is too big
  to inject into every page.
- On a phone Ollama always means Ollama Cloud; WBE's AI Settings offer only that.
- Needs a WBE build with Genie in the app (`chat` no longer in `disabledFeatures`).

## Not in the app yet

- WBE features that need its background script: Duplicates and the Gold Standard inspector. WBE's
  webview build turns them off (`disabledFeatures` in `webview.json`). Inside Genie, the Duplicate
  Finder and Wikidata lookups are skipped for the same reason; Genie works without them.
- Backup and Restore from the WBE menu (downloads and file pickers need more work in a web view).
- Settings don't sync with WBE on a computer. They stay on the phone.
