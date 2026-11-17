# Apple App Store listing

Paste-ready text for App Store Connect (**App Information** and the version page). Character counts were
checked against Apple's limits. Items marked **DECIDE** need Ian or WikiTree.

| Field | Limit | Text | Length |
| --- | --- | --- | --- |
| Name | 30 | WikiTree Tree Apps | 18 |
| Subtitle | 30 | Family tree charts on the go | 28 |
| Promotional text | 170 | Over 30 free WikiTree charts and tools, full screen on your phone: fan charts, descendants, timelines and more, plus Saved people, Anniversaries and dark mode. | 159 |
| Keywords | 100 | genealogy,ancestors,descendants,fan chart,pedigree,family history,timeline,heritage,roots,surnames | 98 |
| Description | 4000 | below (same as Google Play) | 2490 |

Keyword notes: Apple already indexes the words in the name and subtitle ("WikiTree", "Tree", "Apps",
"family", "charts"), so they are not repeated. Competitors' trademarks (e.g. "Ancestry") are left out on
purpose; Apple rejects them.

## Description

```text
WikiTree Tree Apps puts the free WikiTree family tree charts on your phone, with the screen given to the chart instead of the website around it.

WikiTree is a free, collaborative family tree that anyone can search: millions of profiles shared by genealogists around the world. The Tree Apps are the charts, lists and tools that volunteers in the WikiTree Apps project have built on top of it. This app opens them full screen, adds a slim bar to switch app or person, and keeps each app's own settings exactly as they are on the website.

MORE THAN 30 TREE APPS
• Fan Chart, Dynamic Tree, Super Tree and Compact Couple charts of ancestors
• Descendants lists and charts
• Family Timeline and Timeline Tree
• Family Portraits, Family Group views and Ahnentafel lists
• Ancestor Webs, Ancestor Lines Explorer and Lineage Matrix
• Statistics, Surnames, Name Cloud and Family Calendar
• Research helpers, a Genealogy Report and the FanDoku puzzle
Wide charts turn to landscape on their own. Each app's controls stay out of the way until you ask for them.

FIND PEOPLE QUICKLY
• Search by name or WikiTree ID, with notable people shown first
• Star people to keep them in Saved, and find the people you looked at in Recent
• Long-press anyone for their profile, other Tree Apps, a link to share or their ID to copy

MADE FOR THE PHONE
• Your own profile at the top of the start screen once you log in
• Read a biography aloud with your phone's own voice
• Share a chart as a picture, or print it and save it as a PDF
• Dark mode that follows your phone
• Anniversaries: births and deaths on this day among the people on your WikiTree watchlist, with a home-screen widget and an optional morning reminder
• WikiTree profile and Tree Apps links can open straight in the app

YOUR ACCOUNT, YOUR DATA
Log in with your free WikiTree account to use the Tree Apps, see the private profiles you are allowed to see, and get Anniversaries from your watchlist. Your email and password go only to WikiTree and are never stored by the app. Saved people, Recent people and your watchlist copy stay on your phone. The app itself has no ads, no analytics and no tracking.

ABOUT
Made by the WikiTree Apps project. The Tree Apps load live from wikitree.com, so improvements by the WikiTree Apps volunteers reach you without an app update. You need an internet connection to use them.

WikiTree is free forever, a community of genealogists working together on one family tree for all of us. Join at wikitree.com.
```

## Other fields

| Field | Suggested value |
| --- | --- |
| Primary category | **Reference** |
| Secondary category | Lifestyle (or Education) |
| Price | Free |
| Support URL | **DECIDE**: required, a page with a way to contact the WikiTree Apps project (e.g. a G2G tag page or a WikiTree Apps help page) |
| Marketing URL | https://www.wikitree.com/apps/ (optional) |
| Privacy Policy URL | **DECIDE**: where WikiTree will host `privacy-policy.md` |
| Copyright | **DECIDE**: e.g. "2026 WikiTree" (Apple shows it as written) |
| Bundle ID / SKU | **DECIDE**: currently `org.wikitree.treeapps` (widget: `org.wikitree.treeapps.BirthdayWidget`, App Group `group.org.wikitree.treeapps`). Fixed for ever once the app is created in App Store Connect. SKU can be anything, e.g. `wikitree-tree-apps`. |
| Age rating | Answer "None" to every content question. "Unrestricted web access": **Yes** (the app shows wikitree.com pages and opens links in a browser sheet). Apple works out the rating from these answers. Under the older scheme web access alone forced 17+; under the 2025 age ratings expect 13+. Check the result Apple shows. |
| Content rights | "Does your app contain, show, or access third-party content?" **Yes**: WikiTree profiles, biographies and photos, which WikiTree licenses to the WikiTree Apps project. WikiTree must confirm this. |
| Screenshots | iPhone 6.9" display, 1320 × 2868 portrait (or 2868 × 1320 landscape), 1 to 10: `screenshots/ios/`. Apple scales these down for smaller iPhones. |
| App icon | Taken from the build (`ios/TreeApps/Assets.xcassets`). Nothing to upload. |

## iPad (needs a decision before submitting)

The Xcode project targets iPhone **and** iPad (`TARGETED_DEVICE_FAMILY = "1,2"`). If that stays, App
Store Connect also **requires 13" iPad screenshots** (2064 × 2752) and Apple reviews the app on an iPad.
Ian decided against an iPad layout, so the simpler path is to make the app iPhone-only
(`TARGETED_DEVICE_FAMILY = 1` for the app and the widget). iPads can still install it and run it in an
iPhone-sized window. **DECIDE** (recommended: iPhone-only).

## App Review information

| Field | Value |
| --- | --- |
| Sign-in required | Yes: wikitree.com shows its login page instead of the Tree Apps to visitors who are not logged in. Provide a dedicated reviewer WikiTree account (**DECIDE**, never Ian's own). |
| Contact | **DECIDE**: name, phone and email of a WikiTree Apps contact |
| Notes | below |

```text
WikiTree Tree Apps is the mobile app of the WikiTree Apps project for WikiTree (wikitree.com), a free collaborative family tree. It presents the WikiTree Tree Apps, more than 30 interactive charts and tools, full screen on a phone.

Native features beyond the web pages:
- Start screen with native search of WikiTree by name or ID, Saved (starred) and Recent people.
- Long-press any person: open them in any Tree App, view the profile, read the biography aloud (AVSpeechSynthesizer), save, share a link or copy the ID.
- Native WikiTree login (password sent only to WikiTree, never stored).
- Anniversaries: births and deaths on this day among the member's WikiTree watchlist, a home-screen widget and an optional local notification.
- Share a chart as an image, print it or save it as a PDF.
- Dark mode, and automatic landscape for wide charts.

To try it: tap Log in to WikiTree on the start screen and use the demo account below. Then type Windsor-1 in the search box and open Fan Chart, Descendants or Family Timeline from the Tree App menu at the top left. Long-press a person on the start screen for the native person menu.
```

## Release notes ("What's New")

Not used for the first version.
