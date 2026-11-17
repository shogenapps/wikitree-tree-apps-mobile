# Opening wikitree.com links in the Tree Apps mobile app

The app is ready to open two kinds of wikitree.com link when they are tapped in another app
(an email, a message, a browser):

- Tree Apps links: `https://www.wikitree.com/apps/...`
- Profile links: `https://www.wikitree.com/wiki/Windsor-1` (the person opens in the Tree App
  that was last used). Pages with a colon, such as `Help:`, `Space:` and `Category:`, are left
  to the browser.

Android and iOS only hand such links to an app when the website says the app may have them.
That takes two small files hosted on www.wikitree.com. Until they are there, links keep opening
in the browser (on Android the user can turn it on by hand under the app's "Open by default"
settings). Nothing in the app needs to change once the files are in place.

Drafts of both files are in `docs/link-setup/`. Each has one placeholder to fill in.

## What to host

| | Android | iPhone and iPad |
|---|---|---|
| URL | `https://www.wikitree.com/.well-known/assetlinks.json` | `https://www.wikitree.com/.well-known/apple-app-site-association` |
| Draft | `docs/link-setup/assetlinks.json` | `docs/link-setup/apple-app-site-association` |
| File name | exactly `assetlinks.json` | exactly `apple-app-site-association`, with no `.json` extension |
| Content type | `application/json` | `application/json` |
| Value to fill in | SHA-256 fingerprint of the signing certificate | Apple Team ID |

Both must be served over HTTPS with a valid certificate, with status 200 and **no redirect**
(not even to another host or to a login page), and without needing a login or cookies. The host
must be `www.wikitree.com`, because that is the host the app claims. If links on the bare
`wikitree.com` host should open the app too, the app and the files would both need that host
added.

## Values to fill in

**Android: signing certificate fingerprint.** Replace
`REPLACE_WITH_RELEASE_SIGNING_SHA256_FINGERPRINT` with the SHA-256 fingerprint of the
certificate that signs the app people install, in the form `AB:CD:...` (32 pairs).

- If the app uses Play App Signing (the default for new apps), take it from the Play Console:
  the app, then Test and release, Setup, App signing (called "App integrity" in older
  layouts), "App signing key certificate", SHA-256. The same page offers a ready-made
  `assetlinks.json`.
- Otherwise read it from the release keystore:
  `keytool -list -v -keystore <release.keystore> -alias <alias>`
- More than one fingerprint can be listed (for example the upload key as well, so that
  internal test builds verify too).

The package name is `org.wikitree.treeapps`. If WikiTree publishes under a different package
name, change it here to match.

**iPhone: Apple Team ID.** Replace `REPLACE_WITH_TEAM_ID` with the 10-character Team ID of the
Apple Developer account that publishes the app (developer.apple.com, Membership details). The
result looks like `ABCDE12345.org.wikitree.treeapps`. If the bundle ID changes from
`org.wikitree.treeapps`, change it here too.

The publishing account must also have the **Associated Domains** capability turned on for the
app's identifier (Certificates, Identifiers and Profiles, then Identifiers). The app already
asks for `applinks:www.wikitree.com` in `ios/TreeApps/TreeApps.entitlements`. Associated
Domains is not available to free personal teams, so a build signed with one will fail until
that entitlement is removed for the build.

## How to test

**The files themselves**

- `curl -i https://www.wikitree.com/.well-known/assetlinks.json` and
  `curl -i https://www.wikitree.com/.well-known/apple-app-site-association` should each show
  `200`, `content-type: application/json`, and the JSON, with no redirect.
- Android: Google's checker,
  `https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://www.wikitree.com&relation=delegate_permission/common.handle_all_urls`,
  should list the app.
- Apple fetches the file through its own cache, which can lag by a day or so:
  `https://app-site-association.cdn-apple.com/a/v1/www.wikitree.com` shows what Apple currently
  has.

**Android phone** (app installed from the store, or signed with a listed key)

- `adb shell pm get-app-links org.wikitree.treeapps` should show `www.wikitree.com: verified`.
  After changing the file, `adb shell pm verify-app-links --re-verify org.wikitree.treeapps`
  and wait a minute.
- `adb shell am start -a android.intent.action.VIEW -d "https://www.wikitree.com/wiki/Windsor-1"`
  (no package name) should open the app on that person, with no chooser.
- Or tap a profile link in an email.

**iPhone**

- Install the app (TestFlight or the store), then tap a `https://www.wikitree.com/wiki/Windsor-1`
  link in Notes or Mail. It should open the app. Typing the address into Safari does not count;
  it has to be a tapped link.
- Long-pressing the link should offer "Open in Tree Apps".
- iOS fetches the file when the app is installed or updated, so reinstall after changing it.
- For a development build, Settings, Developer, Universal Links, Associated Domains
  Development lets the phone read the file straight from the site instead of Apple's cache
  (the entitlement then needs `?mode=developer` on the domain).

## Notes

- Profile matching on Android needs Android 12 or later; older versions open Tree Apps links
  only.
- On Android the profile pattern allows up to two hyphens inside the last name
  (`Smith-Jones-12`).
- The app never changes what the website shows in a browser; without the app installed the
  links behave exactly as they do now.
