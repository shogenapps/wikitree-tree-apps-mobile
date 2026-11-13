# Tree App problems found while building the mobile shell

Problems in the Tree Apps themselves (github.com/wikitree/wikitree-dynamic-tree), found while
testing them inside the Android and iPhone shells. They are to be fixed in the Tree Apps repo
later. Where the shell works around one, the workaround is named so it can be removed once the
app is fixed. Paths are relative to the Tree Apps repo.

Add one entry per problem: app, symptom, any error, likely source file, where it was seen, and
any shell workaround.

## Bugs

### Heritage Charts: chart never draws
- **Symptom:** "Show heritage" stays greyed out and nothing is drawn.
- **Error:** `Uncaught (in promise) TypeError: Cannot read properties of undefined (reading 'Degrees')`
  at `findOverallHeritage (heritage.js:257)` from `gatherHeritage (heritage.js:206)`.
- **Cause (found 2026-11-14):** `getFamilyMembers` passes the fields as ONE string,
  `["BirthLocation, BirthLocation, Name, Derived.BirthName, Father, Mother, Meta"]`. The API
  uses only the first name in it, so each profile comes back with `BirthLocation` and nothing
  else. getPeople itself works: for Beacall-6 at 5 generations it returns 63 profiles keyed by
  numeric Id (status "", resultByKey `{"Beacall-6": {"Id": 19076274}}`), and the start profile
  is found. But it has no `Meta`, so `familyMember["Meta"]["Degrees"]` at heritage.js:257
  throws. The same call with the fields as a list (`["BirthLocation", "Name",
  "Derived.BirthName", "Father", "Mother", "Meta"]`) returns Name, BirthName, Father, Mother and
  `Meta: {Degrees: 0}`.
- **Source:** `views/heritage/heritage.js`, `getFamilyMembers`.
- **Fix:** pass the fields as separate array items (and drop the duplicate BirthLocation). The
  crash also leaves the button disabled and the shaking tree showing. Also,
  `Utils.hideShakingTree;` in `gatherHeritage` is missing its `()`.
- **Seen:** Android shell, 2026-11-13; on iPhone "Show heritage" also stayed greyed out for
  Young-32264. Shell workaround: none.

### Family Calendar: no dates on iPhone/Safari
- **Symptom:** with no `month=` in the link, the calendar shows no dates on iPhone.
- **Error:** fails at `MONTHS[selectedMonth - 1]`.
- **Source:** `views/familyCalendar/familyCalendar.js` works out the month with
  `Date.parse("undefined 1")`, which Chrome reads as January but Safari/WebKit cannot parse.
- **Fix:** default to `new Date().getMonth() + 1`.
- **Seen:** iPhone shell. Shell workaround: `addCalendarMonth()` in `shared/shell.js` adds the
  current month to the link where that parse fails.

### Family Calendar: its pickers pile up in other apps
- **Symptom:** it adds its Display Mode/month picker to both of the page's `<main>` elements but
  removes only one when leaving, so copies pile up in the next apps.
- **Source:** `views/familyCalendar/familyCalendar.js`.
- **Seen:** iPhone shell. Shell workaround: in `shared/shell.js`.

### WT+ Maps: map blank in iOS apps
- **Symptom:** plus.wikitree.com offers only TLS 1.2 without forward secrecy, which iOS App
  Transport Security refuses, so the map frame is blank in iOS apps. The frame is also a fixed
  850px tall.
- **Fix:** on the server, enable ECDHE ciphers.
- **Source:** plus.wikitree.com server; `views/wtPlusMaps/` for the frame height.
- **Seen:** iPhone shell. Shell workaround: ATS exception for plus.wikitree.com in `ios/TreeApps/Info.plist`.

### One Name Trees: no other app opens after it from a link change
- **Symptom:** after One Name Trees has been open, changing `#view=` or `#name=` in the address
  does nothing: the page stays on One Name Trees.
- **Source:** `views/oneNameTrees/oneNameTrees.js` disables `#wt-id-text,#show-btn` while open
  (lines ~379 and ~704) and enables them only in `close()`. `tree.js` `onHashChange` switches
  view by clicking `#show-btn`, which a disabled button ignores, so `close()` never runs.
- **Fix:** don't disable `#show-btn`, or have `onHashChange` call `onSubmit` directly.
- **Seen:** Android shell with Knopp-385, 2026-11-14. Shell workaround: a `hashchange` listener
  in `shared/shell.js` enables them again just before the page's own listener runs.

### Ahnentafel: Report View can go blank
- **Symptom:** Report View goes blank after switching person or app through the page hash
  (no reload).
- **Source:** `views/ahnentafel/`.
- **Seen:** Android shell. Shell workaround: none.

### Couples Tree and Dynamic Tree: start off screen on phones
- **Symptom:** the root person is placed at the centre of a desktop-width canvas, so on a phone it
  starts off the right edge. The canvas is fixed at 1000px tall with the root hard-coded around
  (500, 300).
- **Source:** `views/couplesTree/couples_tree.js`, `views/baseDynamicTree/WikiTreeDynamicTreeViewer.js`.
- **Seen:** both shells. Shell workaround: `recentre()` in `shared/shell.js`.

### Couples Tree: empty area for a long time
- **Symptom:** the view stays empty for a long time before the tree appears.
- **Source:** `views/couplesTree/`.
- **Seen:** Android shell. Shell workaround: none.

### Ancestor Lines Explorer: Options box covers the screen
- **Symptom:** on a landscape phone with controls shown, the Options box fills the screen and the
  ← → buttons overlap its last line. Minor.
- **Source:** `views/ancestorLines/`.
- **Seen:** Android shell. Shell workaround: controls start hidden.

### WT+ Maps: legend and title collide on phones
- **Symptom:** the Persons legend overlaps the "5000 km" scale bar at the bottom left. On Android
  the red heading 'Data for Ancestors of "…"' at the top is cut off at both sides. For Beacall-6
  the map shows no pins (also on iPhone).
- **Source:** plus.wikitree.com map page shown in `views/wtPlusMaps/`.
- **Seen:** Android shell (legend also on iPhone), 2026-11-13. Shell workaround: none.

### Surnames List: "Gathering surnames" notice never goes away
- **Symptom:** the green "Gathering surnames from ancestors to 6 generations..." notice stays above
  the finished list.
- **Source:** `views/surnames/surnames.js` calls `wtViewRegistry.showNotice(...)` but never
  `wtViewRegistry.clearStatus()` once the list is drawn.
- **Fix:** call `wtViewRegistry.clearStatus()` after drawing.
- **Seen:** iPhone shell, Knopp-385, 2026-11-14. Shell workaround: `#wt-status.green` is hidden on
  phones once `#surnamesList .gen0` exists, in `shared/shell.js`.

### Family Portraits: blank page when there are no portraits
- **Symptom:** for a person whose ancestors have no photos (Knopp-385) the view is empty, with no
  message, so it looks broken.
- **Source:** `views/familyPortraits/portraits.js` leaves `#photo-gallery` empty.
- **Fix:** show a line such as "No portraits found for these ancestors."
- **Seen:** iPhone shell, Knopp-385, 2026-11-14. Shell workaround: none.

### Family Calendar: always shows the logged-in member
- **Symptom:** switching it to another person changes back to the logged-in member about 0.3
  seconds later, and the shell's WikiTree ID follows.
- **Source:** `views/familyCalendar/familyCalendar.js`.
- **Seen:** iPhone and Android shells, Knopp-385 while logged in as Beacall-6, 2026-11-14.
  Shell workaround: none.

### One Name Trees: late results land in the next app
- **Symptom:** switching to another app while One Name Trees is still loading leaves its late
  results drawn on the next app's page.
- **Source:** `views/oneNameTrees/oneNameTrees.js` (its fetches are not cancelled when the view
  is closed).
- **Seen:** iPhone shell, 2026-11-14. Shell workaround: none (a fresh load clears it).

## Phone layout

### All apps: #view-container is at least 1000px tall
- **Symptom:** `tree.css` gives `#view-container` `min-height: 1000px`, which every app
  inherits, so phone pages scroll into empty space.
- **Source:** `tree.css`. Shell workaround: in `shared/shell.js`.

### FanDoku, Fractal Tree, Ancestor Webs: chart overflows at start
- **Symptom:** they start at a fixed desktop scale and centre (0.45, 0.75 and 1 on a 1000px board),
  so on phones the chart overflows. They should fit the window at start.
- **Source:** `views/fandoku/FandokuView.js`, `views/fractalTree/FractalView.js`, `views/webs/WebsView.js`.
- **Shell workaround:** `fitBoard()` in `shared/shell.js`.

### Super Tree: starts tiny
- **Symptom:** after loading, the tree is zoomed out so far that boxes are about 12px wide on a
  phone (Knopp-385: 8 people) and small on desktop too.
- **Source:** `views/superBigFamTree/SuperBigFamView.js`, `SuperBigFamView.reZoom`, called
  automatically after the first load. It sets the SVG `viewBox` to `g.getBBox()`, which also
  counts the hidden placeholders kept for people not shown (1720 x 1900 units where the visible
  boxes span about 600 x 800), and fits that into the whole window (`window.innerWidth/innerHeight`),
  not the chart's own area.
- **Fix:** fit only the visible people, measured against the SVG's own size, and on small
  screens start at a readable scale centred on the start person.
- **Seen:** Android shell, 2026-11-14. Shell workaround: `superStart()` in `shared/shell.js`
  replaces the automatic fit on phones with a readable start centred on the start person.

### Family Calendar: lists and weeks cramped on phones
- **Symptom:** the month list is a box 47% wide, so each entry wraps to 4 or 5 lines. Modern mode
  keeps FullCalendar's 1.35 aspect ratio, so the weeks scroll in a box about 176px tall.
- **Source:** `views/familyCalendar/`. Shell workaround: in `shared/shell.js`.

### Printer Friendly: pedigree grid 1054px wide
- **Source:** `views/printerFriendly/`. Shell workaround: in `shared/shell.js`.

### Genealogy Report: tall form and wide tables
- **Symptom:** the options form is 840px tall, and tables such as Statistics (810px wide) have no
  horizontal scroll of their own.
- **Source:** `views/genealogyReport/`. Shell workaround: in `shared/shell.js`.

### Family Group View: ragged names on phones
- **Symptom:** nested side margins (10 + 10 + 50px) and first-line-only heading indents of 5% and
  8% make wrapped names look ragged.
- **Source:** `views/familyView/`. Shell workaround: in `shared/shell.js`.

### Ancestors Cemeteries: tiny pager
- **Symptom:** the DataTables pager renders as "Previous1234567Next" with 9px tap targets.
- **Source:** `views/ancestorsCemeteries/`. Shell workaround: in `shared/shell.js`.

### Surnames List: big surnames run off a phone
- **Symptom:** new surnames are 70px for the person, then 60, 50, 40 ... per generation. In a
  ~190px portrait column "Walmsley" at 60px is 275px wide and was cut off at the right.
- **Source:** `views/surnames/` CSS (`#surnamesList .gen0` ... `.gen6`).
- **Seen:** iPhone shell, Knopp-385, 2026-11-14. Shell workaround: smaller sizes under
  `max-width: 599px` and `overflow-wrap: anywhere`, in `shared/shell.js`.

### FanDoku: tiny names, and Rules on every start
- **Symptom:** the board is built for wide screens, so on a phone the names are tiny until you
  pinch. The Rules panel also opens on every fresh start.
- **Source:** `views/fandoku/FandokuView.js`.
- **Seen:** iPhone shell, 2026-11-14. Shell workaround: `fitBoard()` fits the board only.

### Couples Tree: oldest couple at the edge in landscape
- **Symptom:** on a landscape iPhone the oldest couple runs to the screen edge until you pan.
- **Source:** `views/couplesTree/couples_tree.js`.
- **Seen:** iPhone shell, 2026-11-14. Shell workaround: none (minor).

### Timeline: earliest labels cut off at the left
- **Symptom:** the earliest labels start cut off at the left edge until you pan.
- **Source:** `views/timeline/`.
- **Seen:** iPhone shell, 2026-11-14. Shell workaround: none.

## Touch and wording

### "Mouse wheel" in help text
- **Symptom:** Couples Tree, Dynamic Tree and other zoomable charts tell the user to use the
  mouse wheel, which phones and tablets do not have ("pinch to zoom" would fit there).
- **Source:** `views/couplesTree/couples_tree.js`, `views/baseDynamicTree/WikiTreeDynamicTreeViewer.js`,
  and similar text in `fanChart`, `fandoku`, `fractalTree`, `webs`, `superBigFamTree`, `nameCloud`.

## Ideas for the Tree Apps repo

### One shared class for each app's controls
Each app draws its own controls with its own ids (`#info-panel`, `#ahnentafelOptions`,
`#treeViewControls`, ...), and Ahnentafel and Family Group App add theirs to the site `<header>`.
The shell keeps a long per-app list (`CONTROLS` in `shared/shell.js`). One agreed class on each
app's control area would let any embedder show or hide them.

### An embed mode on /apps/
A flag such as `?embed=1` that leaves out the site header, Tree App bar and footer would let the
shell drop most of its page CSS.

### Phone layouts
The per-app phone CSS prototyped in `shared/shell.js` (Ahnentafel report, Fan Chart fit,
Descendants, CC7, Family Group App and others) is written to be offered upstream as media queries.
