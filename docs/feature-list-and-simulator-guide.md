# WikiTree Tree Apps for iPhone and Android: what it does, and how to try it

A preview for the WikiTree Team. The app is a thin shell around the real Tree Apps page on
wikitree.com, made to fit a phone. The Tree Apps themselves still come from WikiTree's own
code, so fixes to them show up in the app without a new release. The plan is for the project to
move to WikiTree, and for WikiTree to publish it in the App Store and Google Play.

## What it does today

**The Tree Apps, full screen**
- The site's header, Tree App/ID bar and footer are hidden. A slim green bar takes their place:
  the Tree App's name (tap to switch apps, without reloading), the WikiTree ID (tap to change
  person) and a ⋮ menu.
- Each Tree App's own controls start hidden, so the chart gets the screen. Tap the sliders
  button on the green bar, or swipe down on the bar, to show them; swipe up to hide them again.
- Phone fixes for many of the apps: things that ran off the screen, overlapped or were too small
  to tap now fit (Ahnentafel, CC7, Descendants, Family Group App, Genealogy Report, Super Tree,
  Ancestor Webs, Family Timeline, Family Calendar and more). Pop-ups and help become phone-sized
  sheets.
- Wide charts (Fan Chart, Dynamic Tree, Timeline, Super Tree and others) turn to landscape on
  phones. A switch in the ⋮ menu turns this off. iPads are left free to rotate.
- Light and dark mode follow the phone's setting.

**People**
- A start screen with: who is logged in, search by name or WikiTree ID (notables are marked and
  listed first), Saved people (tap the star), Recent people, and the list of Tree Apps.
- Long-press any person for a menu: open in a Tree App, view the profile, save, share the profile
  link, copy the ID, remove.
- Name suggestions from your watchlist while you type.
- **Anniversaries:** people on your watchlist born or died on this day, an optional 8 AM daily
  notification, and a home-screen widget.
- Home-screen quick actions (long-press the app icon): recent people and Change person.

**Charts and profiles**
- **Share this chart** (⋮ menu): a picture of the chart plus a link back to it.
- **Print or save as PDF** (⋮ menu): a one-page PDF with the title, chart and link.
- Profiles and other wikitree.com pages open in a sheet over the app, already logged in. Other
  sites open in a Safari sheet. Closing it returns you to the chart.
- **Listen to biography:** reads a profile's biography aloud, with pause and stop.

**Other**
- A native WikiTree login form (the Tree Apps need a login). Email and password go only to
  WikiTree; the app keeps neither.
- A "No connection" screen with Retry when WikiTree can't be reached.
- wikitree.com links (Tree Apps and profiles) can open straight in the app, once WikiTree hosts
  two small files on wikitree.com (see `docs/wikitree-link-setup.md`).
- Android and iPhone do the same things from the same page tweaks (`shared/shell.js`).

## Trying it in the iPhone Simulator

You need a Mac with Xcode. It has been built and tested with Xcode 26 and the iPhone 17
Simulator; the app itself runs on iOS 16 and later.

1. **Get the code.** The repository is public:
   https://github.com/shogenapps/wikitree-tree-apps-mobile. Either click **Code > Download ZIP**
   and unzip it, or run
   `git clone https://github.com/shogenapps/wikitree-tree-apps-mobile.git`.
2. **Open the project.** In the downloaded folder, open `ios/TreeApps.xcodeproj` (double-click
   it, or File > Open in Xcode). Keep the folder as it is: the project reads files from the
   `shared/` folder next to `ios/`.
3. **Pick what to run.** In the bar at the top of the Xcode window, choose the **TreeApps**
   scheme (not BirthdayWidget) and an iPhone Simulator, such as iPhone 17. If no Simulators are
   listed, Xcode offers to download the iOS platform; accept it.
4. **Signing.** For the Simulator no signing team is needed, so leave Team set to None. If Xcode
   shows a signing error anyway, select the TreeApps project, then Signing & Capabilities, and pick
   your Personal Team for both the TreeApps and BirthdayWidget targets.
5. **Run.** Press ⌘R (or the ▶ button). The first build takes a minute or two, then the Simulator
   opens with the app.
6. **Log in.** On the start screen tap **Log in to WikiTree** and use your own WikiTree account.
   Then pick a person (search, or use yourself) and a Tree App. Pages can take 15 to 30 seconds to
   load in the Simulator; a real phone is faster.

**Getting around in the Simulator**
- Rotate: ⌘← and ⌘→ (or Device > Rotate Left/Right). Wide charts turn sideways on their own.
- Show a Tree App's controls: click the sliders button on the green bar, or drag down on the bar.
- Long-press: click and hold.
- Dark mode: Features > Toggle Appearance (⇧⌘A).
- Widget: go to the Home Screen (⇧⌘H), click and hold an empty spot, tap Edit > Add Widget and
  search for Tree Apps.

## Known limits

- **Heritage Charts** never draws, on the website too. The cause is in the Tree App's code and
  is written up, with the fix, in `docs/tree-app-issues.md`, along with other Tree App bugs we
  found along the way.
- **Opening wikitree.com links in the app** needs WikiTree to host
  `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`. Drafts are in
  `docs/link-setup/`.
- **Not in the stores yet.** Still to do: WikiTree developer accounts with Apple and Google, the
  final app ID (now `org.wikitree.treeapps`), and a private release signing key.
- **Translations** of the app's own words (German, Dutch, French, Swedish, Spanish, Italian) are
  in review (pull request #2) and not in this build. They are machine-made and need checking by
  native speakers.
- On Android, a test build can be installed from the repository's **Android test build** release.
