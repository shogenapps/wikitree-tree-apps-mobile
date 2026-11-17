# Google Play Data safety and Apple App Privacy answers

Recommended answers, worked out from the code on main (db6739c). **WikiTree must confirm the parts about
its own servers** (marked **CONFIRM**), because once WikiTree publishes the app, data the app sends to
wikitree.com counts as data "the developer collects".

## What the app actually does (the facts behind the answers)

| Data | Leaves the phone? | Where it goes | Kept by the app? |
| --- | --- | --- | --- |
| Email + password at login (`WikiTreeLogin.kt`, `LoginView` in `People.swift`) | Yes, HTTPS | api.wikitree.com / www.wikitree.com login only | No. Password field cleared after the attempt |
| WikiTree user ID (from WikiTree's login cookies) | Yes, as cookies | wikitree.com | Cookies in the web view store |
| Search text, WikiTree IDs viewed, Tree Apps opened | Yes | wikitree.com, api.wikitree.com | Recent list on the phone |
| Saved / Recent people | No | | SharedPreferences / UserDefaults |
| Watchlist copy (names, IDs, dates, places of other people) | Downloaded, not uploaded | | `watchlist.tsv` / App Group defaults |
| Chart screenshot for sharing | Only where the user sends it (share sheet) | user's choice | Cache file |
| Biography read aloud | No (on-device TTS) | | No |
| Notifications | Local only, no push service | | |
| Location, contacts, photos, camera, microphone | Not used | | |
| Analytics, crash reporting, ads, third-party SDKs | None (dependencies are only androidx webkit, browser, core) | | |

Other hosts the Tree Apps pages load code or fonts from: cdnjs.cloudflare.com, cdn.jsdelivr.net, unpkg.com,
fonts.googleapis.com / fonts.gstatic.com, ajax.googleapis.com, cdn.datatables.net, cdn.sheetjs.com,
d3js.org, plus.wikitree.com (WT+ Maps). These are static file downloads; no user data is sent to them
beyond the IP address of the request.

---

## Google Play: Data safety form

**Does your app collect or share any of the required user data types?** Yes.

**Is all of the user data collected by your app encrypted in transit?** Yes (HTTPS only; the manifest
allows no cleartext traffic by default on targetSdk 35).

**Do you provide a way for users to request that their data is deleted?** Yes: the app's own data is
deleted by logging out / clearing data; WikiTree account data via **[WikiTree's account-closing help
page, CONFIRM]**. Play asks for a URL if the app lets people *create* an account. The app's own login does not, but
wikitree.com's login page, which appears inside the app (the Tree Apps page shows it to logged-out
visitors, and the login's "Web page" button opens it), has a "click here to register" link. So both stores
will most likely treat the app as allowing account creation: Play then needs a public "delete your
WikiTree account" URL, and Apple (guideline 5.1.1(v)) needs a way to *start* account deletion from inside
the app, e.g. a "Delete WikiTree account" item in the ⋮ menu opening WikiTree's deletion page. **CONFIRM**
with WikiTree.

### Data types

| Category / type | Collected | Shared | Optional? | Purposes | Notes |
| --- | --- | --- | --- | --- | --- |
| Personal info > **Email address** | Yes | No | Required (wikitree.com shows its login page to logged-out visitors of the Tree Apps) | Account management | Sent to WikiTree's login |
| Personal info > **User IDs** | Yes | No | Required | App functionality, Account management | WikiTree ID in login cookies |
| App activity > **In-app search history** | **CONFIRM**: Yes only if WikiTree logs API search requests beyond answering them | No | Required | App functionality | If WikiTree keeps no such logs, leave unticked (ephemeral processing is exempt) |
| App activity > **Other user-generated content** | No | | | | The app only reads profiles; editing happens on the website |
| Web browsing | **CONFIRM** | No | | | Only if WikiTree's server logs/analytics of page views are tied to the user |
| App info and performance > Crash logs, Diagnostics | No | | | | No crash reporting |
| Device or other IDs | No | | | | No advertising ID; the app declares no AD_ID permission |
| Location, Financial, Health, Messages, Photos, Audio, Files, Calendar, Contacts | No | | | | |

Password: Play's form has no "password" type; credentials sent only to authenticate are covered by
"Account management" under Email address / User IDs.

"Shared" means sent to a *third party*. Data the app sends to WikiTree is not "shared" once WikiTree is the
developer. If the app were ever published by someone other than WikiTree, the same rows would become
"Shared" with WikiTree.

### Other Play declarations

- **Ads**: No. **Advertising ID**: not used (the app has no `com.google.android.gms.permission.AD_ID`).
- **Permissions**: `INTERNET`, `POST_NOTIFICATIONS` (optional Anniversaries reminder, asked at the moment
  the user turns it on), `RECEIVE_BOOT_COMPLETED` (re-arms the daily widget/reminder alarm). None are
  sensitive permissions needing a declaration form.
- **Target API level**: the app targets 35. **CONFIRM at submission time** the level Play requires for
  new apps then (Play normally requires the latest-but-one; from 31 August 2026 that may be 36).

---

## Apple: App Privacy ("nutrition label")

**Do you or your third-party partners collect data from this app?** Yes.

| Data type | Collected | Linked to the user's identity | Used for tracking | Purpose |
| --- | --- | --- | --- | --- |
| Contact Info > **Email Address** | Yes | Yes | No | App Functionality |
| Identifiers > **User ID** | Yes | Yes | No | App Functionality |
| Search History | **CONFIRM** (same test as Play) | Yes | No | App Functionality |
| Browsing History | **CONFIRM** (only if WikiTree logs page views by member) | Yes | No | App Functionality |
| Everything else (Location, Contacts, Health, Financial, Usage Data, Diagnostics, Purchases, Sensitive Info, Photos, Audio, Device ID, etc.) | No | | | |

**Tracking: No.** The app never links its data with other companies' data for advertising, and has no
App Tracking Transparency prompt (it does not need one).

Resulting label: **"Data Linked to You: Contact Info, Identifiers"** (plus Search/Browsing History if
WikiTree confirms), **"Data Used to Track You: none".**

### Privacy manifest (required, currently missing)

Apple rejects uploads that use "required reason" APIs without a privacy manifest. The app and the widget
both use `UserDefaults` (the widget through the App Group), so each target needs a `PrivacyInfo.xcprivacy`.
A ready file is in `PrivacyInfo.xcprivacy` next to this document. To use it, add a copy to the
**TreeApps** target and another to the **BirthdayWidget** target in Xcode (one code change, not made here).

It declares: no tracking, no tracking domains, the two collected data types above, and
`NSPrivacyAccessedAPICategoryUserDefaults` with reasons `CA92.1` (the app's own defaults) and `1C8F.1`
(the App Group shared with the widget). Before release, run Xcode's **Generate Privacy Report** on the archive to check nothing else needs declaring.

### Export compliance

The app uses only the system's HTTPS (no own encryption). In App Store Connect answer that it uses
exempt encryption. To skip the question on every build, add `ITSAppUsesNonExemptEncryption = NO` to the
app's Info.plist (another small code change, not made here).
