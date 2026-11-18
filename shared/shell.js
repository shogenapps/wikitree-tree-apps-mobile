// Injected into https://www.wikitree.com/apps/ pages by the Tree Apps shell.
// It hides the site's own header, Tree App/ID bar and footer so the app gets the screen.
// The shell's native bar replaces them. Nothing here changes how the apps themselves work.
(function () {
    if (!/^\/apps(\/|$)/.test(location.pathname)) return;
    if (window.__wtShell) return;
    window.__wtShell = true;

    var CSS =
        "#offcanvasNavbar, #searchBar, .tabs--wrapper, #subfooter, .bg--tan, body > footer" +
        " { display: none !important; }" +
        // Some apps (Ahnentafel, Family Group App) add their own buttons to the site <header>.
        // So hide only the site's own header content (tagged in tagSiteHeader) and keep the rest.
        // Only the site's header and footer (directly in <body>): Genealogy Report has its own.
        " html:not(.wt-shell-ready) body > header, body > header > [data-wt-site] { display: none !important; }" +
        " body > header { padding: 0 !important; margin: 0 !important; min-height: 0 !important;" +
        " height: auto !important; background: none !important; border: 0 !important; }" +
        " main#main { padding: 0 !important; }" +
        // The Full Screen button (wikitree-dynamic-tree PR 432) hides the site's header, which the
        // shell already does, so it is hidden here, with its column when it has one of its own.
        " #full-screen-btn, .col-auto:has(> #full-screen-btn:only-child) { display: none !important; }" +
        " main#main > .row.mt-3 { margin-top: 0 !important; }" +
        // Use the full width: main#main's 16px side padding and the container's border made
        // a tan margin and a grey line down each side on phones.
        " #view-container { margin: 0 !important; border: 0 !important; }" +
        // Every Tree App sits in a Bootstrap .row (with one .col-lg-12) directly in main#main.
        // The row's -12px side margins are meant to cancel main's padding, which the shell
        // removes above, so the row and its column stuck out 12px past each side of the screen
        // (the column's 12px padding kept the app itself at the edges). On phones drop both, so
        // the row is exactly the screen's width and the app stays where it was. Tablets unchanged.
        " @media (max-width: 599px), (max-height: 599px) {" +
        " main#main > .row { margin-left: 0 !important; margin-right: 0 !important; }" +
        " main#main > .row > * { padding-left: 0 !important; padding-right: 0 !important; }" +
        " }" +
        // Fan Chart: its SVG takes its height from its viewBox, so at full width a landscape
        // phone is too short to show it and the centre falls off the bottom. Give it exactly the
        // screen below its toolbar instead; the SVG scales the whole chart to fit, and the
        // chart's own drag and pinch zoom still work inside that box.
        " main#main .col-lg-12:has(> #view-container > #fanChartSVG)" +
        " { display: flex !important; flex-direction: column; height: 100vh; }" +
        " #view-container:has(> #fanChartSVG)" +
        " { flex: 1 1 auto; min-height: 0; height: auto !important; overflow: hidden !important; }" +
        " #view-container > #fanChartSVG { display: block; width: 100%; height: 100%; }" +
        // Generations toolbar on phones (Fan Chart, FanDoku, Fractal Tree, Ancestor Webs and X-Tree
        // share this markup): its table cells are sized 30%/5%/30%, so in portrait the icons and
        // "[ 5 generations ]" wrapped into ragged lines. Keep each cell on one line, shrink the
        // icons a little and show "[ 5 gens ]". The apps only rewrite the number in
        // #numGensInBBar, so the word is hidden with font-size 0 on the cell and redrawn around
        // the number with ::before/::after. Landscape is unchanged.
        " @media (max-width: 600px) {" +
        " table:has(> tbody > tr > td > #numGensInBBar) { width: 100% !important; table-layout: auto !important; }" +
        " table:has(> tbody > tr > td > #numGensInBBar) > tbody > tr > td { width: auto !important; white-space: nowrap; padding: 2px !important; font-size: 12px; vertical-align: middle; }" +
        " table:has(> tbody > tr > td > #numGensInBBar) > tbody > tr > td:first-child { padding-left: 4px !important; }" +
        " table:has(> tbody > tr > td > #numGensInBBar) > tbody > tr > td:last-child { padding-right: 4px !important; }" +
        " table:has(> tbody > tr > td > #numGensInBBar) img[style*=\"height:30px\"] { height: 20px !important; }" +
        " table:has(> tbody > tr > td > #numGensInBBar) font[size=\"+2\"] { font-size: 16px; }" +
        " td:has(> #numGensInBBar) { font-size: 0 !important; }" +
        " #numGensInBBar { font-size: 12px; margin: 0 3px; }" +
        " #numGensInBBar::before { content: \"[ \"; }" +
        " #numGensInBBar::after { content: \" gens ]\"; }" +
        " #loadingTD { font-size: 11px !important; }" +
        " }" +
        // Ahnentafel: its header row (List/Report View, generations, Format, report options) was
        // wider than a phone, and its report centred a 1100px-wide column so both edges were
        // cut off. Wrap the header as whole items, keep labels on one line, and fit the report
        // to the screen with a little side padding. Wide tables pasted from biographies scroll.
        " #ahnentafelHeaderBox { flex-wrap: wrap !important; width: 100% !important; max-width: 100% !important; box-sizing: border-box; gap: 6px 8px; padding: 6px 8px !important; align-items: center !important; }" +
        " #ahnentafelHeaderBox > * { margin: 0 !important; }" +
        " #ahnentafelHeaderBox button, #ahnentafelHeaderBox input:not([type=checkbox]) { white-space: nowrap; font-size: 14px !important; height: 32px !important; line-height: 1 !important; margin: 0 !important; box-sizing: border-box; vertical-align: middle; }" +
        " #ahnentafelHeaderBox button { padding: 0 10px !important; }" +
        " #ahnentafelHeaderBox .more-generations-container { display: flex; align-items: center; gap: 6px; }" +
        " #ahnentafelHeaderBox #generationsToAdd { width: 44px !important; padding: 0 4px !important; text-align: center; }" +
        " #ahnentafelHeaderBox #ahnentafelAncestorListNavButtons { display: flex !important; gap: 4px; }" +
        " #ahnentafelHeaderBox #ahnentafelAncestorListNavButtons button { width: 32px; padding: 0 !important; }" +
        " #ahnentafelHeaderBox #help-button { margin-left: auto !important; }" +
        " #ahnentafelHeaderBox #ahnentafelAncestorListNavButtons { order: 1; }" +
        " #ahnentafelHeaderBox #help-button { order: 2; }" +
        " #ahnentafelHeaderBox .more-generations-container { order: 3; }" +
        " #ahnentafelHeaderBox #formatButton, #ahnentafelHeaderBox #reportImageToggle { order: 4; }" +
        " #ahnentafelHeaderBox #reportImageToggle { display: flex; flex-wrap: wrap; align-items: center; max-width: 100%; gap: 4px 14px; }" +
        " #ahnentafelHeaderBox #reportImageToggle label, #ahnentafelHeaderBox #reportImageToggle .breadcrumbs-control { display: inline-flex !important; align-items: center; gap: 4px; white-space: nowrap; font-size: 14px !important; margin: 0 !important; }" +
        " #ahnentafelHeaderBox #reportImageToggle input[type=checkbox] { margin: 0 !important; width: 16px; height: 16px; }" +
        " #ahnentafelHeaderBox #reportImageToggle .breadcrumbs-control button { width: 32px; padding: 0 !important; }" +
        " main#main .col-lg-12 > main:has(~ #view-container) { padding: 0 !important; }" +
        " #ahnentafelOptions { margin: 6px 8px !important; padding: 8px 10px !important; gap: 6px 12px !important; }" +
        " #ahnentafelReportWrapper { padding: 12px !important; align-items: stretch !important; max-width: 100%; box-sizing: border-box; }" +
        " #ahnentafelReport { width: auto !important; min-width: 0 !important; max-width: 100% !important; overflow-wrap: anywhere; }" +
        " #ahnentafelReport img { max-width: 100%; height: auto; }" +
        " #ahnentafelReport .table-wrapper, #ahnentafelReport pre { max-width: 100%; overflow-x: auto; }" +
        // Ahnentafel report on phones. Self-contained so it can be offered upstream as a media
        // query in views/ahnentafel/ahnentafel.css (wikitree-dynamic-tree); tablets keep the
        // app's own layout. Smaller title, less space around headings and between people, and a
        // hanging indent: the number sits in its own column so a wrapped name and the b./d.
        // lines line up with the first word of the name. Fonts and colours are unchanged.
        " @media (max-width: 600px) {" +
        " #ahnentafelReportStatus { min-height: 0 !important; height: auto !important; padding: 0 !important; margin: 0 0 4px !important; }" +
        " #ahnentafelReport .report-main-title { font-size: 1.25rem; margin: 8px 0 12px; }" +
        " #ahnentafelReport .report-generation-header { font-size: 1.1rem; margin: 20px 0 10px; }" +
        " #ahnentafelReport .report-person { padding: 10px 12px; margin: 0 0 12px; }" +
        " #ahnentafelReport .report-person-header { display: grid; grid-template-columns: auto 1fr; column-gap: 0.5em; align-items: baseline; margin-bottom: 8px; }" +
        " #ahnentafelReport .report-person-title, #ahnentafelReport .report-title-main { display: contents; }" +
        " #ahnentafelReport .report-person-header > *, #ahnentafelReport .report-title-main > * { grid-column: 2; }" +
        " #ahnentafelReport .report-title-main > .report-ahnentafel { grid-column: 1; margin: 0; min-width: 1.6em; }" +
        " #ahnentafelReport .report-vitals { margin: 4px 0 0; }" +
        " #ahnentafelReport .report-bio { margin-top: 8px; }" +
        " #ahnentafelReport .report-bio .family-summary { margin: 0 0 8px; padding-bottom: 8px; }" +
        " #ahnentafelReport .report-bio .family-summary p:empty { display: none; }" +
        " }" +
        // Ahnentafel List View on phones: each generation heading ends with its fill rate
        // ("4/4 (100.00%)"), floated right. When the heading text left it no room, it dropped
        // below the heading and the first person's box squeezed in beside it, a narrow column.
        // Give the fill rate its own right-aligned line inside the heading instead.
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=ahnentafel] #view-container h2 > .fillRate { float: none !important; display: block; text-align: right; }" +
        " }" +
        // Ahnentafel List View on phones: each person's ↕ button (show only this person's line)
        // is placed absolutely at the list's right edge, so it hung over the 20px margin and
        // partly off the screen. Make it the last item of the person's own row instead, at the
        // top right inside the box; the text beside it wraps a little earlier.
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=ahnentafel] #ahnentafelAncestorList .descendantButton { position: static !important; flex: none; align-self: flex-start; margin: 0 0 0 6px !important; min-width: 36px; min-height: 36px; }" +
        " }" +
        // Descendants on phones: the app lines up birth and death in four fixed columns sized
        // for a desktop, which runs off the right edge. Two columns instead: date, then place.
        // Landscape phones too: Report View was 930px wide there, cut off at both sides.
        " @media (max-width: 600px), (max-height: 599px) {" +
        " #descendants .birthDeathDetails { grid-template-columns: auto 1fr !important; column-gap: 8px; margin-right: 8px; }" +
        " #descendantsReportWrapper { padding: 12px !important; align-items: stretch !important; max-width: 100%; box-sizing: border-box; }" +
        " #descendantsReport { width: auto !important; min-width: 0 !important; max-width: 100% !important; overflow-wrap: anywhere; }" +
        " #descendantsReport img { max-width: 100%; height: auto; }" +
        " }" +
        // The site's own CSS under 980px makes body exactly 100vh tall with overflow-x hidden, so
        // body becomes a screen-high scroll box instead of the page scrolling. Descendants places
        // its expand/collapse triangles absolutely against body, so they stayed put while the
        // list scrolled. Let body grow with the list so the page itself scrolls. Phones only.
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=descendants] body { height: auto !important; }" +
        " }" +
        // Descendants on phones: each person's "highlight" checkbox is 13px and the map pin
        // beside each place 12px, too small to hit with a finger. Draw the checkbox half as big
        // again (scaled, so nothing around it moves) and give the pin a larger invisible tap
        // area (padding taken back by a negative margin, so the text does not move either).
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=descendants] #descendants .highlightCheckbox { transform: scale(1.5); margin-left: 6px; margin-right: 6px; }" +
        " html[data-wt-view=descendants] #descendants a.mapsLink { display: inline-block; box-sizing: content-box; padding: 8px; margin: -8px -6px -8px -8px; }" +
        " }" +
        // Dynamic Tree, Couples Dynamic Tree and Super Tree: tree.css gives #view-container a
        // min-height of 1000px and the trees size their drawing area from it when they start,
        // so on a phone most of the tree was below the screen, where a drag pans the tree
        // instead of scrolling the page. Give them exactly the screen below any controls, and
        // let the drawing area follow it on rotation. data-wt-view is set before the app starts
        // (see setViewAttr); recentre() then moves the first person into view. Phones only
        // (shorter side under 600px, matching the shell's own phone test); tablets keep the
        // app's layout.
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=wt-dynamic-tree] main#main .col-lg-12," +
        " html[data-wt-view=couples] main#main .col-lg-12," +
        " html[data-wt-view=superbig] main#main .col-lg-12" +
        " { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=wt-dynamic-tree] #view-container," +
        " html[data-wt-view=couples] #view-container," +
        " html[data-wt-view=superbig] #view-container" +
        " { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: hidden !important; }" +
        " html[data-wt-view=wt-dynamic-tree] #dynamic-tree-container," +
        " html[data-wt-view=couples] #couples-view-container { height: 100%; overflow: hidden; }" +
        " #dynamic-tree-container > svg, #couples-view-container > svg { display: block; width: 100%; height: 100%; }" +
        " }";
    // Tablets: charts fill the window. On a tablet the shell used to leave the apps' desktop
    // layout alone, so Super Tree, Dynamic Tree, Couples, FanDoku, Fractal Tree and Ancestor
    // Webs drew on a 1000px-tall board and the page scrolled past empty space. They now fill
    // the window below the app's toolbar, as on phones, so that a docked settings panel (see
    // DOCK) can take its room from the chart rather than from the page below it.
    CSS +=
        " @media (min-width: 600px) and (min-height: 600px) {" +
        ["wt-dynamic-tree", "couples", "superbig", "fandoku", "fractal", "webs"].map(function (v) {
            return " html[data-wt-view=" + v + "] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
                " html[data-wt-view=" + v + "] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: hidden !important; }";
        }).join("") +
        " html[data-wt-view=wt-dynamic-tree] #dynamic-tree-container," +
        " html[data-wt-view=couples] #couples-view-container { height: 100%; overflow: hidden; }" +
        " #dynamic-tree-container > svg, #couples-view-container > svg," +
        " html[data-wt-view=fandoku] #view-container > svg, html[data-wt-view=fractal] #view-container > svg," +
        " html[data-wt-view=webs] #view-container > svg { display: block; width: 100%; height: 100%; }" +
        // Super Tree drew at the width the window had when it started, so it did not shrink
        // beside a docked settings panel, and its fit (a viewBox) was placed against the right
        // edge. Sized to its box, the SVG scales the fitted tree to the room there is, centred.
        " html[data-wt-view=superbig] #view-container > #superbigChartSVG { display: block; width: 100% !important; height: 100% !important; }" +
        " }";
    var PHONE_QUERY = "(max-width: 599px), (max-height: 599px)";

    // CC7 Views on phones: cc7.css gives #cc7Container a min-width of 650px, so its button rows
    // ran off the right edge. Fit the container to the screen and wrap each button row as whole
    // buttons. The people table stays as wide as it is and scrolls sideways inside the view, as
    // before. Its two button rows are hidden with the other controls (see CONTROLS).
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " #cc7Container { min-width: 0 !important; }" +
        " #cc7Container > div:has(> #getPeopleButton), #cc7Container > #tableButtons" +
        " { display: flex; flex-wrap: wrap; align-items: center; gap: 4px 6px; padding: 4px 6px; margin: 0 !important; }" +
        " #cc7Container > div:has(> #getPeopleButton) > *, #cc7Container > #tableButtons > :not(select)" +
        " { margin: 0 !important; white-space: nowrap; }" +
        // Keep the "Improve count accuracy" box with its label: a line break before it, then
        // the box, label and settings/help icons on one line.
        " #cc7Container > div:has(> #getPeopleButton)::after { content: \"\"; flex-basis: 100%; order: 1; }" +
        " #cc7Container > div:has(> #getPeopleButton) > #getExtraDegrees," +
        " #cc7Container > div:has(> #getPeopleButton) > #getExtraDegrees + label," +
        " #cc7Container > div:has(> #getPeopleButton) > #adminButtons { order: 2; }" +
        " #cc7Container > div:has(> #getPeopleButton) > #adminButtons { margin-left: auto !important; }" +
        " #cc7Container > #degreesTable { margin: 6px 8px !important; width: auto !important; max-width: calc(100% - 16px); }" +
        " #cc7Container > #ancReport { margin: 0 8px 8px !important; }" +
        " }";

    // CC7 Views on phones: the counts table above the people list ends with a note ("True CC7
    // size for ... = [not available] ...") whose long words set a minimum width, so at a larger
    // text size, or with all seven degrees shown, the table was wider than the screen and its
    // right side was cut off (the page cannot scroll sideways). Let the note break anywhere,
    // and if the counts still do not fit, scroll the table sideways on its own.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " #cc7Container > #degreesTable { display: block; overflow-x: auto; }" +
        " #cc7Container > #degreesTable td.trueSize { min-width: 7em; overflow-wrap: anywhere; padding-left: 0.6em !important; }" +
        " }";

    // Family Group App on phones: familyGroupApp.css makes the view at least 730px wide, every
    // table 800px with fixed 160px and 250px columns, and the app sets width: 800px on its
    // tables, so the place column, wide biographies and source lines were cut off at the right.
    // Fit the sheet to the screen: a narrower label column, a fixed date column, the place takes
    // the rest and wraps, and anything long breaks rather than running off. The collapse
    // triangles sit 438-490px left of centre, off a phone screen, so they stay out of sight.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " #view-container.familyGroupApp { min-width: 0 !important; }" +
        " #view-container.familyGroupApp table { width: 100% !important; max-width: 100% !important; margin-left: 0 !important; margin-right: 0 !important; }" +
        // Each row of the sheet's tables is laid out as a grid with the same three columns, so
        // the husband's, wife's and children's tables line up (as plain tables each one sized
        // its date column to its own shortest dates). Cells spanning two or three columns keep
        // their span.
        " #view-container.familyGroupApp table.personTable > tbody > tr," +
        " #view-container.familyGroupApp #familySheetFormTable > thead > tr" +
        " { display: grid !important; grid-template-columns: 120px 100px minmax(0, 1fr); }" +
        " #view-container.familyGroupApp table.personTable > tbody > tr > *," +
        " #view-container.familyGroupApp #familySheetFormTable > thead > tr > *" +
        " { display: block; width: auto !important; min-width: 0 !important; max-width: none !important; overflow-wrap: break-word; }" +
        " #view-container.familyGroupApp table.personTable > tbody > tr > [colspan=\"2\"] { grid-column: span 2; }" +
        " #view-container.familyGroupApp table.personTable > tbody > tr > [colspan=\"3\"] { grid-column: 1 / -1; }" +
        " #view-container.familyGroupApp table.citationTable, #view-container.familyGroupApp .citationList table," +
        " #view-container.familyGroupApp table.personTable table.wikitable { width: auto !important; }" +
        " #view-container.familyGroupApp #notesAndSources, #view-container.familyGroupApp div.theBio," +
        " #view-container.familyGroupApp .citationList { max-width: 100% !important; box-sizing: border-box; overflow-wrap: anywhere; }" +
        " #view-container.familyGroupApp div.theBio table { max-width: 100% !important; }" +
        " #view-container.familyGroupApp img { max-width: 100%; height: auto; }" +
        " #view-container.familyGroupApp #fgaInfo, #view-container.familyGroupApp #fgaOptions { width: auto !important; max-width: calc(100% - 16px); box-sizing: border-box; }" +
        " }";

    // Family Group App on phones: the role rows ("Husband:", "Wife:", "1st Child:") and the
    // "Married:" heading are 1.4 times the page's text size, bold, and the role may not wrap,
    // so in portrait the label was wider than its 120px column and ran into the name beside it.
    // Make them a little smaller (still larger than the other rows) and let them wrap if they
    // must, so they stay inside their column. The names keep their size.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        // (The role row itself is 1.4em, so its label is set relative to that: 0.8em of it is
        // about the same 1.1 times the text size as the "Married:" heading.)
        " #view-container.familyGroupApp tr.roleRow > th { font-size: 0.8em !important; }" +
        " #view-container.familyGroupApp tr.marriedRow > th { font-size: 1.1em !important; }" +
        " #view-container.familyGroupApp .role.heading { white-space: normal !important; overflow-wrap: anywhere; }" +
        " }";

    // Family Group App on phones: the parents' names under each person ("Father:", "Mother:")
    // are kept on one line, so a long name such as "Angelina Taylor (Popham) ..." ran past the
    // right edge of the screen at a larger text size. Let those names wrap inside their cell.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " #view-container.familyGroupApp .parentName { white-space: normal !important; display: inline !important; overflow-wrap: anywhere; }" +
        " }";

    // Dynamic Tree and Couples Dynamic Tree put the first person at a fixed (500, 300), sized
    // for a desktop window. Once they have started, move that person to the middle of a smaller
    // screen. The trees' own zoom state (__zoom on their d3 container) is updated with it, so
    // dragging and pinching carry on from the new position.
    var TREE_ORIGIN = { x: 500, y: 300 };
    var recentreTimer;
    function recentre() {
        var tries = 0;
        clearInterval(recentreTimer);
        var timer = (recentreTimer = setInterval(function () {
            if (++tries > 80) return clearInterval(timer);
            var box = document.querySelector("#dynamic-tree-container, #couples-view-container");
            var t = box && box.__zoom;
            // Keep looking for a while: switching person rebuilds the tree a moment later.
            if (!t || !window.d3 || !d3.zoomIdentity) return;
            if (t.k !== 1 || t.x !== TREE_ORIGIN.x || t.y !== TREE_ORIGIN.y) return;
            var x = Math.round(Math.min(TREE_ORIGIN.x, box.clientWidth / 2));
            // Vertically always the middle: in portrait the desktop 300 left the person high.
            var y = Math.round(box.clientHeight / 2);
            if (x === t.x && y === t.y) return;
            box.__zoom = d3.zoomIdentity.translate(x, y);
            var g = box.querySelector(":scope > svg > g");
            if (g) g.setAttribute("transform", "translate(" + x + "," + y + ") scale(1)");
            var layer = box.querySelector(":scope > .html-layer");
            if (layer) layer.style.transform = "translate(" + x + "px, " + y + "px) scale(1)";
        }, 250));
    }

    // FanDoku, Fractal Tree and Ancestor Webs start from a fixed view chosen for a desktop
    // window (FanDoku at scale 0.45, Fractal Tree at 0.75, Ancestor Webs at 1, centred on a
    // 1000px-tall board), so on a phone the chart ran off the sides or below the screen. Once
    // the chart has drawn, zoom out (never in) to show all of it in the middle of the screen;
    // pinch to zoom in. Each app's own zoom state (__zoom on its SVG) and its scale factor,
    // which sizes its popups, are updated with it, so dragging and pinching carry on from
    // there. Turning the phone fits it again (refit), unless the player has zoomed or dragged.
    var BOARDS = { fandoku: { k: 0.45, app: "FandokuView" }, fractal: { k: 0.75, app: "FractalView" }, webs: { k: 1, app: "WebsView", k2: 1.2 } };
    var boardTimer, boardFit;
    // The chart's extent in its own units, from what is drawn on screen: the people's boxes
    // are HTML inside zero-height foreignObjects, which getBBox() leaves out. Hidden parts
    // measure 0 and are skipped, as is Fractal Tree's invisible line far below the tree.
    function chartBox(svg, g, t) {
        var r = svg.getBoundingClientRect();
        var x1 = Infinity, y1 = Infinity, x2 = -Infinity, y2 = -Infinity;
        [].forEach.call(g.querySelectorAll("path, line, circle, rect, text, foreignObject > *"), function (e) {
            if (e.id === "lineAtBottomOfSVG") return;
            var b = e.getBoundingClientRect();
            if (!b.width && !b.height) return;
            x1 = Math.min(x1, b.left); y1 = Math.min(y1, b.top);
            x2 = Math.max(x2, b.right); y2 = Math.max(y2, b.bottom);
        });
        if (!(x1 < x2)) return { x: 0, y: 0, width: 0, height: 0 };
        return { x: (x1 - r.left - t.x) / t.k, y: (y1 - r.top - t.y) / t.k, width: (x2 - x1) / t.k, height: (y2 - y1) / t.k };
    }
    function fitBoard(view, refit) {
        var start = BOARDS[view];
        var tries = 0, lastSize = "", same = 0;
        clearInterval(boardTimer);
        var timer = (boardTimer = setInterval(function () {
            if (++tries > 120) return clearInterval(timer);
            if (capture) return;
            var svg = document.querySelector("#view-container > svg");
            var g = svg && svg.querySelector(":scope > g");
            var t = svg && svg.__zoom;
            if (!g || !t || !window.d3 || !d3.zoomIdentity) return;
            // Only the app's own starting view (or, on turning, the view set here): never undo
            // the player's zooming. Keep looking, though: switching person shows the old,
            // zoomed chart until the new one is drawn.
            var mine = refit && boardFit && boardFit.svg === svg && t.k === boardFit.k && t.x === boardFit.x && t.y === boardFit.y;
            // Within half a pixel: on a 914px-wide Android screen Fractal Tree starts at
            // x = 456.99999999999994, not 457, so an exact test never fitted it.
            // PR 429's Ancestor Webs starts each drawing at 120% instead (k2), with the web's
            // top 50px down, centred across. The 50px is checked too, so that a web fitted here
            // at exactly 120% and then dragged is not taken for a new start.
            var appStart = (t.k === start.k && Math.abs(t.x - svg.getAttribute("width") / 2) <= 0.5) ||
                (start.k2 && t.k === start.k2 && Math.abs(t.y + chartBox(svg, g, t).y * t.k - 50) <= 3);
            // PR 429's Ancestor Webs also redraws at the scale set here (after its background
            // loading, or a nudge), placed back at the top: that is still this fit, so it is
            // fitted again (centred). The player's own zoom has a different scale.
            if (!mine && start.k2 && boardFit && boardFit.svg === svg && t.k === boardFit.k) {
                var b0 = chartBox(svg, g, t);
                mine = Math.abs(t.y + b0.y * t.k - 50) <= 3 && Math.abs(t.x + (b0.x + b0.width / 2) * t.k - svg.clientWidth / 2) <= 3;
            }
            if (!mine && !appStart) return;
            // Never zoom in past the app's own start (120% there, so a small web keeps its size).
            var maxK = mine ? boardFit.maxK : (start.k2 && t.k === start.k2 ? start.k2 : start.k);
            // While FanDoku sets up, all of its names show for a second or two and the board
            // looks far bigger: wait until it has hidden the ones it does not need (seven
            // generations need them all, so give up waiting after 10s). Then, for every app,
            // wait until the chart's size has held for three checks in a row.
            var names = g.querySelectorAll("[id^=floatingNameHolder]");
            var shown = [].filter.call(names, function (e) { return getComputedStyle(e).display !== "none"; });
            if (names.length && shown.length === names.length && tries < 40) return;
            var box = chartBox(svg, g, t);
            var size = [box.x, box.y, box.width, box.height].join();
            if (size !== lastSize) { lastSize = size; same = 0; return; }
            if (++same < 3) return;
            var w = svg.clientWidth, h = svg.clientHeight;
            if (!box.width || !w || !h) return;
            // Keep watching after fitting: while a person loads, the apps can put their
            // starting view back, and then it is fitted again.
            refit = false; lastSize = ""; same = 0;
            var k = Math.max(0.05, Math.min(maxK, 0.96 * Math.min(w / box.width, h / box.height)));
            var x = Math.round(w / 2 - (box.x + box.width / 2) * k);
            var y = Math.round(h / 2 - (box.y + box.height / 2) * k);
            svg.__zoom = d3.zoomIdentity.translate(x, y).scale(k);
            g.setAttribute("transform", "translate(" + x + "," + y + ") scale(" + k + ")");
            if (window[start.app]) window[start.app].currentScaleFactor = k;
            boardFit = { svg: svg, k: k, x: x, y: y, maxK: maxK };
        }, 250));
    }

    // Ancestor Webs on phones: fitBoard() fitted only the first web. Changing the generations
    // or the view (FULL, UNIQUE, REPEAT, SINGLE, Family) redraws in place at the old zoom, so a
    // bigger web, such as Windsor-1's REPEAT web at 9 generations (about 2500 units across),
    // ran far off the right of the screen, and one that loaded after the 30s fitBoard() watches
    // was never fitted. Every redraw now fits again: a different web always (whatever the player
    // did to the last one), the same web (a generation finishing loading) only if the player has
    // not zoomed or dragged it since. And when a web has no one in it (REPEAT for someone with
    // no repeat ancestors: "At 9 generations, Ian has 0 repeat ancestors.") the screen was just
    // blank, as the app says why in its summary line, hidden with the other controls: that line
    // now shows in the middle of the screen while the web is empty (see the CSS below).
    function websRefit() {
        var tries = 0;
        var timer = setInterval(function () {
            if (++tries > 240) return clearInterval(timer);
            var app = window.WebsView;
            if (!app || typeof app.redraw !== "function") return;
            clearInterval(timer);
            if (app.redraw.__wtShell) return;
            var redraw = app.redraw, last = "";
            app.redraw = function () {
                var result = redraw.apply(this, arguments);
                if (document.documentElement.getAttribute("data-wt-view") === "webs" && matchMedia(PHONE_QUERY).matches) {
                    var key = [app.viewMode, app.numGens2Display, app.familyType, app.yDir, app.repeatAncestorNum, app.commonAncestorNum].join();
                    var svg = document.querySelector("#view-container > svg");
                    var t = svg && svg.__zoom;
                    // A different web: take the zoom it is shown at as this fit's, so it is refitted.
                    if (key !== last && boardFit && t && boardFit.svg === svg) {
                        boardFit.k = t.k; boardFit.x = t.x; boardFit.y = t.y;
                    }
                    last = key;
                    if (boardFit) fitBoard("webs", true);
                    // PR 429 draws 50ms later (after its "please wait"), so look a moment after.
                    setTimeout(websEmpty, 400);
                }
                return result;
            };
            app.redraw.__wtShell = true;
        }, 250);
    }
    function websEmpty() {
        var svg = document.querySelector("#view-container > svg");
        var empty = !!svg && ![].some.call(svg.querySelectorAll("g.person foreignObject > *"), function (e) {
            return e.getBoundingClientRect().width > 0;
        });
        var summary = document.getElementById("SummaryMessageArea");
        if (empty && summary && summary.textContent.trim()) document.documentElement.setAttribute("data-wt-webs-empty", "");
        else document.documentElement.removeAttribute("data-wt-webs-empty");
    }

    // Super Tree on phones: once a tree is drawn the app zooms to fit (SuperBigFamView.reZoom).
    // It fits the whole drawing's getBBox(), which also counts the hidden places it keeps for
    // people not shown (1720 x 1900 units for Knopp-385's eight boxes), into the whole window,
    // so on a phone each 300-unit box came out about 12px wide. After that automatic fit (not
    // when the player taps the app's own zoom button, which still cycles its three settings),
    // start instead at a readable scale (a box about 0.38 of the view's height) centred on the
    // start person, whose box is found by its WikiTree ID. Drag and pinch carry on from there.
    function superStart() {
        var tries = 0;
        var timer = setInterval(function () {
            if (++tries > 240) return clearInterval(timer);
            var app = window.SuperBigFamView;
            if (!app || typeof app.reZoom !== "function") return;
            clearInterval(timer);
            if (app.reZoom.__wtShell) return;
            var reZoom = app.reZoom;
            app.reZoom = function () {
                var result = reZoom.apply(this, arguments);
                // A tap on the app's zoom button runs inside a click; the automatic fit does not.
                var tapped = window.event && window.event.type === "click";
                if (!tapped && document.documentElement.getAttribute("data-wt-view") === "superbig" && matchMedia(PHONE_QUERY).matches) readableStart(app);
                return result;
            };
            app.reZoom.__wtShell = true;
        }, 250);
    }
    function readableStart(app) {
        var svg = document.getElementById("superbigChartSVG");
        var m = /[#&]name=([^&]*)/.exec(location.hash);
        if (!svg || !app.zoom || !window.d3 || !m) return;
        var id = decodeURIComponent(m[1]);
        var root = [].filter.call(svg.querySelectorAll("g.person"), function (g) {
            return g.getBoundingClientRect().width > 0 && g.textContent.indexOf(id) >= 0;
        })[0];
        var t = root && /translate\(([-\d.]+),\s*([-\d.]+)\)/.exec(root.getAttribute("transform"));
        var box = root && root.querySelector("foreignObject");
        var div = box && box.firstElementChild;
        if (!t || !div) return;
        var w = svg.clientWidth, h = svg.clientHeight, boxH = div.offsetHeight || 240;
        var k = Math.min(0.6, (0.38 * h) / boxH);
        var cx = +t[1] + (+box.getAttribute("x") || 0) + (+box.getAttribute("width") || 0) / 2;
        var cy = +t[2] + (+box.getAttribute("y") || 0) + boxH / 2;
        svg.removeAttribute("viewBox");
        d3.select(svg).call(app.zoom.transform, d3.zoomIdentity.translate(w / 2 - cx * k, h / 2 - cy * k).scale(k));
    }

    // Loading tree: some Tree Apps fetch everything before they draw, and their own "Please
    // wait" line sits in their button bar, hidden with the other controls, so the screen stayed
    // empty. shellLoading(view, done) shows the Tree Apps' own shaking tree (the one CC7,
    // Ahnentafel and Descendants use) in the middle of the screen until done(state) is true,
    // another app opens, or two minutes pass. done() is asked every half second; state.ms is the
    // time since the tree was shown, and done() may keep its own notes on state. All screen sizes.
    var loadingTimer;
    function shellLoading(view, done) {
        var img = document.getElementById("wt-shell-loading");
        if (!img) {
            img = document.createElement("img");
            img.id = "wt-shell-loading";
            img.src = "views/cc7/images/tree.gif";
            img.alt = "Loading";
            // Styled on the element, so it stays centred when the WikiTree page bars are shown
            // (which removes the shell's style sheet).
            img.style.cssText = "position: fixed; left: 50%; top: 50%; transform: translate(-50%, -50%); z-index: 1000; pointer-events: none; width: 100px; height: auto;";
            (document.body || document.documentElement).appendChild(img);
        }
        var state = { ms: 0 };
        clearInterval(loadingTimer);
        var timer = (loadingTimer = setInterval(function () {
            state.ms += 500;
            if (state.ms > 120000 || document.documentElement.getAttribute("data-wt-view") !== view || done(state)) {
                clearInterval(timer);
                img.remove();
            }
        }, 500));
    }

    // Super Tree: on start, until people are drawn or the app clears its "Please wait" message.
    // Also when another person is asked for inside Super Tree (a new #name=): the old tree is
    // cleared while the new family loads, so for the first two seconds the old tree being drawn
    // does not count.
    var superName = null;
    function superLoading() {
        var name = (/[#&]name=([^&]*)/.exec(location.hash) || [])[1] || "";
        var fresh = superName !== null && name !== superName;
        superName = name;
        if (!fresh && superDrawn()) return;
        shellLoading("superbig", function (state) {
            var note = document.getElementById("WarningMessageBelowButtonBar");
            var waiting = !!note && /wait/i.test(note.textContent);
            if (waiting) state.waited = true;
            return (state.waited && !waiting) || ((!fresh || state.ms > 2000) && superDrawn());
        });
    }
    // Ancestor Webs: its "Please wait while initial Ancestor Webs is loading" (and PR 429's
    // drawing messages) are in #WarningMessageBelowButtonBar, inside #info-panel, which the shell
    // hides, so nothing showed that it was busy. Show the loading tree while that message says
    // "wait" (or "be patient", for a new person), or for up to 3s if it has not appeared yet.
    function websLoading() {
        shellLoading("webs", function (state) {
            var note = document.getElementById("WarningMessageBelowButtonBar");
            var waiting = !!note && /wait|patient/i.test(note.textContent);
            if (waiting) state.waited = true;
            return state.waited ? !waiting : state.ms > 3000;
        });
    }
    function superDrawn() {
        var svg = document.getElementById("superbigChartSVG");
        return !!svg && [].some.call(svg.querySelectorAll("g.person"), function (g) {
            return g.getBoundingClientRect().width > 0;
        });
    }

    // X Family Tree on phones (see its CSS block): while it is open, scale its SVG to show all
    // generations in the view, never larger than drawn and never below 0.45 (smaller is
    // unreadable; then the view scrolls, starting with the start person in view). Refitted when
    // the app redraws (person, generations) or the view changes size (turning, controls).
    var xtreeTimer;
    function fitXTree() {
        clearInterval(xtreeTimer);
        var last = "";
        xtreeTimer = setInterval(function () {
            if (document.documentElement.getAttribute("data-wt-view") !== "xtree") return clearInterval(xtreeTimer);
            var svg = document.getElementById("outerSVG");
            var view = document.getElementById("view-container");
            if (!svg || !view || capture || !matchMedia(PHONE_QUERY).matches) return;
            var w = +svg.getAttribute("width"), h = +svg.getAttribute("height");
            var cw = view.clientWidth, ch = view.clientHeight;
            var key = [w, h, cw, ch, svg.getAttribute("data-wt-fit") || ""].join();
            if (!w || !h || !cw || !ch || key === last) return;
            var k = Math.min(1, Math.max(0.45, Math.min(cw / w, (ch - 4) / h)));
            svg.setAttribute("viewBox", "0 0 " + w + " " + h);
            svg.style.width = Math.round(w * k) + "px";
            svg.style.height = Math.round(h * k) + "px";
            svg.setAttribute("data-wt-fit", k.toFixed(3));
            last = [w, h, cw, ch, svg.getAttribute("data-wt-fit")].join();
            view.scrollTop = Math.max(0, h * k - ch);
            view.scrollLeft = Math.max(0, (w * k - cw) / 2);
        }, 300);
    }

    // Family Timeline on phones: vis-timeline starts with its window set to the people's dates,
    // but each label is a box much wider than its date, so on a phone the earliest labels (the
    // parents) were cut off at the left and the latest (children) at the right until panned.
    // Once a new timeline has drawn, widen its window until every label is inside. Drag and
    // pinch carry on from there. Tree App issue, see docs/tree-app-issues.md.
    var timelineTimer;
    function fitTimeline() {
        var tries = 0, done, resolved;
        clearInterval(timelineTimer);
        var timer = (timelineTimer = setInterval(function () {
            if (++tries > 120 || document.documentElement.getAttribute("data-wt-view") !== "timeline") return clearInterval(timer);
            var view = window.wtViewRegistry && wtViewRegistry.views && wtViewRegistry.views.timeline;
            // Once Tree Apps load each app's files on first use, the registry holds a promise.
            if (view && typeof view.then === "function") { view.then(function (v) { resolved = v; }); view = resolved; }
            var tl = view && view.timeline;
            var panel = document.querySelector("#view-container .vis-panel.vis-center");
            if (!tl || tl === done || !panel || capture || !matchMedia(PHONE_QUERY).matches) return;
            var p = panel.getBoundingClientRect();
            var l = Infinity, r = -Infinity, widest = 0;
            [].forEach.call(panel.querySelectorAll(".vis-item.vis-box, .vis-item.vis-range"), function (e) {
                var b = e.getBoundingClientRect();
                if (!b.width) return;
                l = Math.min(l, b.left); r = Math.max(r, b.right); widest = Math.max(widest, b.width);
            });
            // The app keeps the view 0 wide until the timeline has drawn.
            if (p.width < 100 || !(l < r)) return;
            var over = Math.max(0, p.left + 6 - l), overR = Math.max(0, r - p.right + 6);
            // Done when all fit, or when one label alone is wider than the screen.
            if ((over < 1 && overR < 1) || widest > p.width - 12) { done = tl; return; }
            var w = tl.getWindow(), s = +w.start, e = +w.end, per = (e - s) / p.width;
            // Widening the window shrinks everything else, so overshoot a little and check again.
            tl.setWindow(s - over * per * 1.2, e + overR * per * 1.2, { animation: false });
        }, 250));
    }

    // The current Tree App's key (from #view=...) on <html>, for per-app rules above.
    function setViewAttr() {
        var m = /[#&]view=([^&]*)/.exec(location.hash);
        var view = m ? decodeURIComponent(m[1]) : "";
        document.documentElement.setAttribute("data-wt-view", view);
        if ((view === "wt-dynamic-tree" || view === "couples") && matchMedia(PHONE_QUERY).matches) recentre();
        if (view === "superbig" && Math.min(screen.width, screen.height) < 600) superStart();
        if (view === "superbig") superLoading();
        if (view === "webs") websLoading();
        if (view === "webs" && Math.min(screen.width, screen.height) < 600) websRefit();
        // Tablets too: their boards fill the window as well (see "Tablets: charts fill the window").
        if (BOARDS[view]) fitBoard(view);
        if (view === "xtree" && Math.min(screen.width, screen.height) < 600) fitXTree();
        if (view === "timeline" && Math.min(screen.width, screen.height) < 600) fitTimeline();
        // Uses the screen, not PHONE_QUERY: at document start the page has no viewport yet.
        if (view === "calendar" && Math.min(screen.width, screen.height) < 600) addCalendarMonth();
    }

    // Family Calendar: with no month= in the link it works the month out with
    // Date.parse("undefined 1"), which Safari/WebKit cannot read, so on iPhones the app stopped
    // with "MONTHS[selectedMonth - 1]" and showed no dates; Chrome (Android) reads it as
    // January, so it always opened on January. Name the current month in the link instead,
    // before the app reads the link. This works around a Tree App bug (reported).
    function addCalendarMonth() {
        if (/[#&]month=/.test(location.hash)) return;
        history.replaceState(history.state, "", location.hash + "&month=" + (new Date().getMonth() + 1));
    }

    // Compact Couple Ancestors on phones: tree.css makes #view-container 1000px tall, so on a
    // landscape phone the page scrolled into empty space below a short tree. Give the view
    // exactly the screen below any controls; a bigger tree scrolls inside it both ways. The
    // Options panel and the floating scroll arrows (which sat over the tree) are hidden with the
    // other controls (see CONTROLS); a drag scrolls the tree instead.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=cctree] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=cctree] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; }" +
        " }";

    // Compact Couple Descendants on phones: the same markup and fix as Compact Couple Ancestors.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=ccdtree] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=ccdtree] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; }" +
        " }";

    // Connection Checkers Web on phones: the app opens on its form (game, IDs, "Show connections"),
    // which is the app until there are results, so it stays. Once results exist the form is
    // hidden with the other controls (see CONTROLS) and the results fill the screen: the zoom/save
    // toolbar and the 1, 2, ... Map, Summary tabs share one line (the tabs scroll sideways), and
    // the web itself scrolls both ways in the space left. The summary under it is kept to two
    // lines that scroll. The form counts as controls from the start (see CONTROLS_LATER), so the
    // shell's controls button works as soon as results appear.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=ccwebs] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=ccwebs] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; display: flex; flex-direction: column; }" +
        " #ccwebs-view { flex: 1 1 0; min-height: 0; display: flex; flex-direction: column; overflow: auto; }" +
        " #ccwebs-view > #ccw-out:has(.ccw-result) { flex: 1 0 100%; min-height: 0; display: grid; grid-template-columns: auto minmax(0, 1fr); grid-template-rows: auto minmax(0, 1fr); column-gap: 8px; align-items: end; }" +
        " #ccwebs-view > #ccw-progress:empty { display: none; }" +
        " #ccwebs-view #ccw-out .ccw-toolbar { margin: 0 0 4px; white-space: nowrap; }" +
        " #ccwebs-view #ccw-out #ccw-tabs { flex-wrap: nowrap; overflow-x: auto; margin: 0; }" +
        " #ccwebs-view #ccw-out #ccw-tabs button { flex: none; padding: 4px 10px; }" +
        " #ccwebs-view #ccw-out .ccw-result.active { grid-column: 1 / -1; display: flex; flex-direction: column; min-height: 0; overflow: auto; margin: 0; align-self: stretch; }" +
        " #ccwebs-view #ccw-out .ccw-result > h2 { margin: 2px 0; font-size: 16px; flex: none; }" +
        " #ccwebs-view #ccw-out .ccw-diagram { flex: 1 1 0; min-height: 0; overflow: auto; }" +
        " #ccwebs-view #ccw-out .ccw-summary { flex: none; max-height: 3em; overflow: auto; margin: 2px 0 0; }" +
        " #ccwebs-view #ccw-out .ccw-map-frame { flex: 1 1 0; min-height: 0; height: auto; }" +
        " }";

    // Ancestor Lines Explorer on phones: the same markup as the Compact Couple trees (an Options
    // panel and floating scroll arrows over a 1000px #view-container), so the same fix. The panel
    // and arrows are hidden with the other controls (see CONTROLS).
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=ale] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=ale] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; }" +
        // The Options table is 940px wide; when shown, let its cells wrap so none is cut off.
        " #aleFieldset { min-width: 0; max-width: 100%; box-sizing: border-box; }" +
        " #aleFieldset #optionsTbl, #aleFieldset #optionsTbl > tbody { display: block; width: auto !important; }" +
        " #aleFieldset #optionsTbl tr { display: flex; flex-wrap: wrap; column-gap: 12px; }" +
        " #aleFieldset #optionsTbl td { display: block; width: auto !important; }" +
        " #aleFieldset #optionsTbl td[colspan='5'] { flex-basis: 100%; }" +
        " #aleFieldset #optionsTbl input[type=text] { width: 100% !important; max-width: 100%; box-sizing: border-box; }" +
        " }";

    // Lineage Matrix on phones: tree.css makes #view-container 1000px tall, taller than a phone,
    // so the page scrolled into empty space below a small matrix. Give the view exactly the
    // screen; a bigger matrix scrolls inside it. The Generations picker and the status line
    // above the matrix are hidden with the other controls (see CONTROLS).
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=lineageMatrix] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=lineageMatrix] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: auto; }" +
        " }";

    // One Name Trees on phones: four boxes of controls (name search, buttons, Table, Trees) took
    // the top third of a portrait phone. The app runs the search for the current person's surname
    // by itself, so the boxes are hidden with the other controls (see CONTROLS) and the results
    // get the screen, scrolling inside the view rather than past tree.css's 1000px minimum.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=oneNameTrees] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        // position: relative keeps the absolutely placed [355] counts scrolling with the list.
        " html[data-wt-view=oneNameTrees] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: auto; position: relative; }" +
        " }";

    // Generational Statistics on phones: the Max Generations / Options panel is hidden with the
    // other controls (see CONTROLS), and the view is exactly the screen rather than tree.css's
    // 1000px. The statistics table is about 1030px wide, so it scrolls sideways on its own and
    // the summary lines under it stay on screen.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=stats] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=stats] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: auto; }" +
        " #statsContainer > #stats-table { display: block; max-width: 100%; overflow-x: auto; }" +
        " #statsContainer > #stats-table th, #statsContainer > #stats-table td { padding: 4px 6px; }" +
        " }";

    // Timeline Tree on phones: the app already sizes its timeline to the window and keeps its
    // options in the shared info panel (hidden with the other controls). When the options are
    // shown they pushed the timeline down and its bottom rows off the screen, so the view takes
    // exactly the screen left below them and the timeline fills that.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=timelineTree] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=timelineTree] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; }" +
        " html[data-wt-view=timelineTree] #ttreeContainer { height: 100% !important; }" +
        " }";

    // X Family Tree on phones: its three-line title ("X-Chromosome Probability Tree for <name>")
    // took 72px of a 319px landscape screen and repeats what the shell's bar already shows (the
    // app and the person), so it is hidden and the tree starts at the top. The tree and the
    // ancestor list below it scroll in the view as before; the options live in the shared info
    // panel, hidden with the other controls.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=xtree] #XTreeTitle { display: none; }" +
        " html[data-wt-view=xtree] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=xtree] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: auto; }" +
        // The tree is a fixed-size SVG (100px per generation, 140px per box across) with the
        // start person at the bottom, so on a phone the person and their parents were below the
        // screen and only the empty boxes of unknown ancestors showed. fitXTree scales it to the
        // view; the app's own centring transform is replaced by margin auto.
        " html[data-wt-view=xtree] #outerSVG[data-wt-fit] { transform: none !important; display: block; margin: 0 auto; }" +
        " }";

    // Family Explorer and Galaxy Explorer on phones (wikitree-dynamic-tree PR 432): the app's panel
    // is calc(100vh - 230px) tall with a 480px minimum, sized for the desktop page's header, so
    // on a landscape phone it ran below the screen. Give it exactly the screen below any
    // controls. Its title ("Family Explorer: <name> (<ID>)") repeats the shell's bar, so it is
    // hidden; its buttons (Parents, Back to ..., SVG, PNG) stay on one line that scrolls sideways
    // if it must. The find box takes the rest of its line, and "N people loaded so far" is one
    // small line. The keyboard hint (arrow keys) and Galaxy's "scroll to zoom" hint do not apply
    // on a phone and covered the bottom of the view, so they are hidden. Galaxy's canvas takes
    // drags itself (touch-action), so a drag turns the galaxy instead of being lost to the
    // page, and its − / + degree buttons get a finger-sized target.
    var EXPLORERS = ["familyExplorer", "galaxyExplorer"];
    function explorerRule(tail) {
        return EXPLORERS.map(function (v) { return "html[data-wt-view=" + v + "] " + tail; }).join(", ");
    }
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " " + explorerRule("main#main .col-lg-12") + " { display: flex !important; flex-direction: column; height: 100vh; }" +
        " " + explorerRule("#view-container") + " { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: hidden !important; display: flex; flex-direction: column; }" +
        " " + explorerRule("#view-container > .wbe-chart-popup") + " { flex: 1 1 0; height: auto !important; min-height: 0 !important; border: 0; border-radius: 0; }" +
        " .wbe-explorer .chat-popup-header { flex-wrap: nowrap !important; padding: 4px 6px !important; }" +
        " .wbe-explorer .chat-popup-header > .wbe-chart-title { display: none; }" +
        " .wbe-explorer .chat-popup-controls { flex-wrap: nowrap !important; overflow-x: auto; margin-left: 0 !important; justify-content: flex-start !important; }" +
        " .wbe-explorer .chat-popup-controls button.small { min-height: 32px; }" +
        " .wbe-explorer .wbe-chart-toolbar { flex-wrap: nowrap; padding: 4px 6px; }" +
        " .wbe-explorer .wbe-chart-toolbar .wbe-chart-spacer { display: none; }" +
        " .wbe-explorer .wbe-explorer-bio { flex: 0 1 auto; min-width: 0; overflow: hidden; text-overflow: ellipsis; }" +
        " .wbe-explorer .wbe-explorer-search { flex: 1 1 8em; width: auto; min-width: 6em; height: 32px; font-size: 16px; }" +
        " .wbe-explorer .wbe-chart-footer { padding: 2px 8px; }" +
        " .wbe-explorer .wbe-chart-stats strong { display: inline; font-size: inherit; margin-right: 4px; }" +
        " .wbe-explorer .wbe-nav-keys, .wbe-explorer .wbe-galaxy-hint { display: none !important; }" +
        " .wbe-explorer canvas.wbe-galaxy-canvas { touch-action: none; }" +
        " .wbe-explorer .wbe-galaxy .wbe-galaxy-degrees button:not(#none) { width: 34px; height: 34px; }" +
        " }" +
        // Galaxy's person card is anchored bottom right and up to the whole height less 100px, so
        // on a portrait phone it covered the middle of the galaxy, where the person in the middle
        // and their family are drawn. Keep it in the lower half (it scrolls) and full width.
        " @media (max-width: 599px) and (orientation: portrait) {" +
        " .wbe-explorer .wbe-galaxy .wbe-galaxy-card { left: 8px; right: 8px; bottom: 8px; width: auto; max-width: none; max-height: calc(50% - 90px); }" +
        " }";

    // Family Calendar on phones: each month's list was a box 47% of the screen wide in the
    // middle, so a date and name took four or five lines. It now takes the full width. The
    // Display Mode picker and the twelve month links took the top quarter of a portrait phone,
    // so they are hidden with the other controls (see CONTROLS); the shell's controls button
    // brings them back to change month or mode, each on one line (the months scroll sideways).
    // In Modern Calendar mode FullCalendar sizes the month at 1.35 times as wide as tall, so on a
    // phone the weeks scrolled inside a 176px box; they now take their natural height.
    // The calendar adds its picker to both of the page's <main>s but removes only one on leaving,
    // so copies piled up at the end of the page and in other apps. Only the one in the inner
    // <main>, which comes first and is the one the app listens to, is kept.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=calendar] #watchCalendar .content { width: auto !important; margin: 0 !important; padding: 0 12px 12px !important; }" +
        " html[data-wt-view=calendar] #watchCalendar .calendar { height: auto; }" +
        " html[data-wt-view=calendar] #view-options:has(> #display-mode) { display: flex; align-items: center; gap: 8px; padding: 4px 8px; }" +
        " html[data-wt-view=calendar] #view-options:has(> #display-mode) > label { margin: 0; white-space: nowrap; }" +
        " html[data-wt-view=calendar] #watchCalendar > .fourteen.columns.center { white-space: nowrap; overflow-x: auto; margin: 0 0 6px !important; padding: 0 4px; }" +
        " html[data-wt-view=calendar] #watchCalendar > .fourteen.columns.center > span { font-size: 1.1em; }" +
        " html[data-wt-view=calendar] #ancCalendar .fc-scroller { height: auto !important; overflow: visible !important; }" +
        " html[data-wt-view=calendar] #ancCalendar .fc-day-grid .fc-row { min-height: 72px; }" +
        " html[data-wt-view=calendar] #ancCalendar .fc-toolbar .fc-button { padding: 0 .5em; }" +
        " html[data-wt-view=calendar] #ancCalendar .fc-toolbar h2 { font-size: 1.2em; }" +
        " html:not([data-wt-view=calendar]) main > #view-options:has(> #display-mode), main#main > #view-options:has(> #display-mode) { display: none !important; }" +
        " }";

    // Family Group View on phones: the Date Format / Date Status / WikiTree IDs box took the top
    // 150px of the screen, so it is hidden with the other controls (see CONTROLS). The family
    // sheet had side margins of 10px, then 10px more, then 50px around the children's list, and
    // the headings were indented by 5% and 8% on their first line only, so a wrapped couple's
    // name looked ragged; the margins are trimmed and the headings start at the left edge. The
    // empty <main> above the sheet keeps the site's 16px padding, a 32px blank band; it goes.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=familygroup] .col-lg-12 > main { padding: 0 !important; }" +
        " html[data-wt-view=familygroup] #family_group { margin: 0 6px !important; width: auto !important; }" +
        " html[data-wt-view=familygroup] #family_group :is(h2, h3), html[data-wt-view=familygroup] #children_list h2 { text-indent: 0 !important; margin: 8px 0 !important; }" +
        " html[data-wt-view=familygroup] .fv_singleFamily { margin: 8px 0 !important; }" +
        " html[data-wt-view=familygroup] #children_list { margin: 0 6px !important; padding: 0 6px; width: auto !important; }" +
        " }";

    // Family Portraits on phones: the gallery works as it is (rows of 150px-tall portraits that
    // wrap); only the blank 32px band above it (the empty <main>'s padding) is removed.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=portraits] .col-lg-12 > main { padding: 0 !important; }" +
        " html[data-wt-view=portraits] #photo-gallery { padding: 2px 0; }" +
        " }";

    // Genealogy Report on phones: its options form is 840px tall, more than a portrait screen,
    // and the report builds itself without it, so the form is hidden with the other controls
    // (see CONTROLS); "Done: ..." stays. A table wider than the screen (the Statistics table is
    // 810px) was cut off at the right; each table now scrolls sideways on its own. The view's
    // 16px side padding is halved.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=genealogyReport] #view-container.genealogyReportView { padding-left: 8px !important; padding-right: 8px !important; }" +
        " html[data-wt-view=genealogyReport] .gr-report table { display: block; max-width: 100%; overflow-x: auto; }" +
        " }";

    // Genealogy Report on phones: the Surnames section sets each generation as a row of three
    // columns (a 7rem "Generation N" label, then father's side and mother's side), and the
    // larger surnames of the early generations made the side columns wider than the screen, so
    // the row ran past the right edge. Put the label on its own line above the two sides, and
    // let a surname that still does not fit break rather than stick out.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=genealogyReport] .gr-surname-row { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) !important; }" +
        " html[data-wt-view=genealogyReport] .gr-surname-row > .gr-surname-label { grid-column: 1 / -1; }" +
        " html[data-wt-view=genealogyReport] .gr-surname { max-width: 100%; overflow-wrap: anywhere; }" +
        " }";

    // Name Cloud on phones: its settings and buttons took the top half of a portrait screen and
    // left the cloud 206px tall. They are hidden with the other controls (see CONTROLS) and the
    // cloud takes the rest of the screen; it is an SVG that scales to fit, so nothing is redrawn.
    // The line under it ("54 surnames from 142 people ...") stays, in smaller type.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=namecloud] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=namecloud] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: hidden !important; }" +
        " html[data-wt-view=namecloud] .ncloud-app { height: 100%; border: 0 !important; box-sizing: border-box; }" +
        " html[data-wt-view=namecloud] .ncloud-dialog { height: 100%; }" +
        " html[data-wt-view=namecloud] .ncloud-main { min-height: 0; }" +
        " html[data-wt-view=namecloud] #ncloudStatus { padding: 4px 10px !important; font-size: 12px; }" +
        " }";

    // Printer Friendly on phones: its options box took the top 280px and is hidden with the
    // other controls (see CONTROLS). The pedigree grid is 1054px wide (five generations of
    // fixed columns, laid out for paper), so the view is exactly the screen and the title and
    // grid scroll inside it both ways instead of the page running on for tree.css's 1000px.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=printer-friendly] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=printer-friendly] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: auto !important; }" +
        " html[data-wt-view=printer-friendly] .col-lg-12 > main { padding: 0 !important; }" +
        " html[data-wt-view=printer-friendly] #subject h2 { font-size: 1.1rem; margin: 6px 8px; }" +
        // Its options box (shared with Family Group View) is tighter when shown: 200px, not 280px.
        " .col-lg-12 > .familyViewOptions { row-gap: 6px !important; column-gap: 10px !important; padding: 6px 8px !important; margin: 4px 6px !important; align-content: flex-start !important; }" +
        " .col-lg-12 > .familyViewOptions > * { margin: 0 !important; }" +
        " }";

    // Research on phones: it already fits. Its "Show Search Input" button, and the search fields
    // it opens, are hidden with the other controls (see CONTROLS), and the 48px gap the button
    // sat in above the introduction closes.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=research] #research-app > .research-search-header { margin-top: 8px !important; }" +
        " }";

    // Surnames List on phones: 20px of padding round the list and a 40px gap between the
    // father's and mother's columns left each column 161px of a 402px screen, so long surnames
    // in the large sizes ran close to the edge. Both are trimmed to give the columns ~190px.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=surnames] #surnamesList { padding: 8px 6px !important; }" +
        " html[data-wt-view=surnames] #surnamesList .paternalColumn { margin-right: 6px !important; }" +
        " html[data-wt-view=surnames] #surnamesList .maternalColumn { margin-left: 6px !important; }" +
        // Its green "Gathering surnames from ancestors to 6 generations..." notice is never
        // cleared (the app does not call clearStatus), so it took 64px above the finished list.
        // Hide it once the list has drawn.
        " html[data-wt-view=surnames] body:has(#surnamesList .gen0) #wt-status.green { display: none !important; }" +
        " }" +
        // In portrait the app's sizes for new surnames (70px for the person, then 60, 50, 40 ...
        // per generation) are too big for a ~190px column: "Walmsley" at 60px is 275px wide and
        // ran off the right edge. Scale them down, and let any name still too long break.
        " @media (max-width: 599px) {" +
        " html[data-wt-view=surnames] #surnamesList .surnameItem { max-width: 100%; overflow-wrap: anywhere; }" +
        " html[data-wt-view=surnames] #surnamesList .gen0 { font-size: 48px; }" +
        " html[data-wt-view=surnames] #surnamesList .gen1 { font-size: 38px; }" +
        " html[data-wt-view=surnames] #surnamesList .gen2 { font-size: 32px; }" +
        " html[data-wt-view=surnames] #surnamesList .gen3 { font-size: 27px; }" +
        " html[data-wt-view=surnames] #surnamesList .gen4 { font-size: 22px; }" +
        " html[data-wt-view=surnames] #surnamesList .gen5 { font-size: 18px; }" +
        " }";

    // Ancestors Cemeteries on phones: the table's "Show 10 entries" and "Search" boxes are
    // hidden with the other controls (see CONTROLS) and share one line when shown. The page
    // links ran together as "Previous1234567Next" with 9px-wide numbers to tap; they are spaced
    // and padded. The blank 32px band above the table (the empty <main>'s padding) goes.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=ancestorsCemeteries] .col-lg-12 > main { padding: 0 !important; }" +
        " html[data-wt-view=ancestorsCemeteries] #cemeteriesTable_wrapper { padding: 4px 4px 12px; }" +
        " html[data-wt-view=ancestorsCemeteries] #cemeteriesTable_length, html[data-wt-view=ancestorsCemeteries] #cemeteriesTable_filter { display: inline-block; width: auto; margin: 0 8px 4px 0; }" +
        " html[data-wt-view=ancestorsCemeteries] #cemeteriesTable_filter input { width: 130px; }" +
        " html[data-wt-view=ancestorsCemeteries] #cemeteriesTable_paginate { display: flex; flex-wrap: wrap; align-items: center; gap: 4px; margin-top: 6px; }" +
        " html[data-wt-view=ancestorsCemeteries] #cemeteriesTable_paginate > span { display: contents; }" +
        " html[data-wt-view=ancestorsCemeteries] #cemeteriesTable_paginate .paginate_button { display: inline-block; min-width: 32px; padding: 6px 8px; text-align: center; border: 1px solid #ccc; border-radius: 6px; }" +
        " html[data-wt-view=ancestorsCemeteries] #cemeteriesTable_paginate .paginate_button.current { background: #25422d; color: #fff; border-color: #25422d; }" +
        " }";

    // WT+ Maps on phones: its frame was a fixed 850px tall, so the bottom of the map and its
    // controls were below the screen and the page scrolled instead of the map. The frame now
    // fills exactly the screen below the Ancestors / Descendants / Nuclear family / Managed
    // profiles buttons, which are hidden with the other controls (see CONTROLS).
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=wtPlusMaps] .col-lg-12 > main { padding: 0 !important; }" +
        " html[data-wt-view=wtPlusMaps] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=wtPlusMaps] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: hidden !important; display: flex; flex-direction: column; }" +
        " html[data-wt-view=wtPlusMaps] #view-container > #map { flex: 1 1 0; min-height: 0; height: auto !important; border: 0; display: block; }" +
        " }";

    // FanDoku on phones: its board took a fixed 1000px height, so the page scrolled. The board
    // now fills the screen below its generations toolbar (hidden with the other controls, see
    // CONTROLS); fitBoard() (above) then shows the whole game at the start. In portrait its
    // toolbar wrapped into ragged lines like the other generations toolbars, but its number sits
    // one level deeper (in #preGameGens), so the shared rules above miss it: the same treatment
    // here, giving "Start Game", the fan shapes, "[ 4 gens ]" and the settings on one line
    // (in landscape it only needed keeping each cell on one line).
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=fandoku] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=fandoku] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: hidden !important; }" +
        " html[data-wt-view=fandoku] #view-container > svg { display: block; width: 100%; height: 100%; }" +
        " #btnBarDIV > table:has(#preGameGens) > tbody > tr > td { white-space: nowrap; }" +
        " }" +
        " @media (max-width: 599px) {" +
        " #btnBarDIV > table:has(#preGameGens) { table-layout: auto !important; }" +
        " #btnBarDIV > table:has(#preGameGens) > tbody > tr > td { width: auto !important; white-space: nowrap; padding: 2px !important; font-size: 12px; vertical-align: middle; }" +
        " #btnBarDIV > table:has(#preGameGens) > tbody > tr > td:first-child { padding-left: 4px !important; }" +
        " #btnBarDIV > table:has(#preGameGens) > tbody > tr > td:last-child { padding-right: 4px !important; }" +
        " #btnBarDIV > table:has(#preGameGens) button { padding: 3px 6px !important; font-size: 13px; }" +
        " #btnBarDIV > table:has(#preGameGens) img[style*=\"height:30px\"] { height: 20px !important; }" +
        " #btnBarDIV > table:has(#preGameGens) font[size=\"+2\"] { font-size: 16px; }" +
        " #preGameGens { font-size: 0; }" +
        " }";

    // Fractal Tree on phones: like FanDoku, its chart took a fixed 1000px height, so the page
    // scrolled. It now fills the screen below its generations toolbar (hidden with the other
    // controls, see CONTROLS), and fitBoard() (above) shows the whole tree at the start.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=fractal] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=fractal] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: hidden !important; }" +
        " html[data-wt-view=fractal] #view-container > svg { display: block; width: 100%; height: 100%; }" +
        " }";

    // Ancestor Webs on phones: the same 1000px board, centred halfway down it, so most of the
    // web was below the screen. It now fills the screen below its toolbar (hidden with the
    // other controls, see CONTROLS), and fitBoard() (above) shows the whole web at the start;
    // its own zoom button still works as before. Its toolbar is too long for one line (about
    // 870px even with the shared generations rules), and its three fixed-width cells wrapped
    // into ragged lines: the groups now wrap as whole items, without the empty spacer cells,
    // giving two rows in landscape and three in portrait ("Family:" stays with its menu).
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " html[data-wt-view=webs] #info-panel > table > tbody > tr { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; column-gap: 10px; row-gap: 2px; padding: 2px 6px; }" +
        " html[data-wt-view=webs] #info-panel > table > tbody > tr > td { display: block; width: auto !important; padding: 0 !important; font-size: 12px; white-space: normal !important; }" +
        " html[data-wt-view=webs] #info-panel > table > tbody > tr > td[width=\"5%\"] { display: none; }" +
        " html[data-wt-view=webs] #FamilyTypeSelectorSpan { white-space: nowrap; }" +
        " html[data-wt-view=webs] #info-panel > table font[size=\"+2\"] { font-size: 16px; }" +
        " html[data-wt-view=webs] main#main .col-lg-12 { display: flex !important; flex-direction: column; height: 100vh; }" +
        " html[data-wt-view=webs] #view-container { flex: 1 1 0; min-height: 0 !important; height: auto !important; overflow: hidden !important; }" +
        " html[data-wt-view=webs] #view-container > svg { display: block; width: 100%; height: 100%; }" +
        // An empty web (websRefit, above): the app's summary line, which says why, in the middle
        // of the screen. (":not(#none)" outweighs the controls rule, which hides #info-panel's
        // other contents with three IDs' weight.)
        " html.wt-shell-ready[data-wt-view=webs][data-wt-webs-empty] body #info-panel > #SummaryMessageArea:not(#none) { display: block !important;" +
        " position: fixed; left: 16px; right: 16px; top: 45%; margin: 0; text-align: center; font-size: 15px; color: #555; z-index: 1; pointer-events: none; }" +
        " }";

    // Help pop-ups (the "?" button, with the controls). Most Tree Apps place theirs at a desktop
    // position, 40 to 50em wide: on a phone they started 540px off the left edge (Ancestor Lines,
    // the Compact Couple trees, Heritage, Statistics, Timeline Tree), or squeezed into a 180-250px
    // strip 3,500px tall that scrolled away with the page (CC7, Couples, Descendants), or put the
    // close mark off the right edge (One Name Trees). On phones each one fills the screen less
    // an 8px margin, scrolls inside itself, and keeps its close mark at the top right as a 40px
    // tap area; while one is open the page behind does not scroll. A drag cannot move it (its
    // position is set here), so dragging only scrolls its text. Escape and the apps' own close
    // marks work as before. :not(#wt-help):not(#wt-help) only adds weight, to win over the apps'
    // own small-screen rules (CC7 and Couples set width: 70% !important under 768px). Slippy Tree's
    // help already fits a phone. Ahnentafel's "?" does nothing anywhere, as the app never adds its
    // help text (Tree App bug); its pop-up is listed so that it fits too once that is fixed.
    var HELP = ["#help-text", "#ct-help-text", "#explanation", "#descendantsHelp", "#help.modal", "#ahnentafelHelpText"];
    var HELP_CLOSE = ["#help-text xx", "#ct-help-text xx", "#explanation x", "#descendantsHelp #closeHelp", "#help.modal #closeHelp", "#ahnentafelHelpText x"];
    var HELP_OPEN = HELP.map(function (s) { return s + "[style*=\"display: block\"]"; }).join(", ");
    var helpSel = function (list, tail) {
        return list.map(function (s) { return "html:not(#wt-help):not(#wt-help) " + s + (tail || ""); }).join(", ");
    };
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " " + helpSel(HELP) + " { position: fixed !important; top: calc(8px + env(safe-area-inset-top)) !important; bottom: auto !important;" +
        " left: calc(8px + env(safe-area-inset-left)) !important; right: calc(8px + env(safe-area-inset-right)) !important;" +
        " width: auto !important; height: auto !important; max-width: none !important; margin: 0 !important; box-sizing: border-box !important;" +
        " max-height: calc(100% - 16px - env(safe-area-inset-top) - env(safe-area-inset-bottom)) !important;" +
        " overflow-x: hidden !important; overflow-y: auto !important; overscroll-behavior: contain; -webkit-overflow-scrolling: touch;" +
        " touch-action: pan-x pan-y !important; cursor: auto !important; z-index: 2147483000 !important;" +
        " padding: 48px 14px 14px !important; box-shadow: 0 4px 24px rgba(0, 0, 0, .35) !important; font-size: 16px; line-height: 1.4; overflow-wrap: anywhere; white-space: normal !important; }" +
        " " + helpSel(HELP, " :not(pre)") + " { white-space: normal !important; }" +
        " " + helpSel(HELP_CLOSE) + " { position: fixed !important; top: calc(12px + env(safe-area-inset-top)) !important;" +
        " right: calc(12px + env(safe-area-inset-right)) !important; left: auto !important; bottom: auto !important;" +
        " width: 40px !important; height: 40px !important; min-width: 0 !important; margin: 0 !important; padding: 0 !important; float: none !important;" +
        " display: flex !important; align-items: center; justify-content: center; box-sizing: border-box;" +
        " font-size: 20px !important; line-height: 1 !important; white-space: nowrap !important; overflow: hidden; border-radius: 8px; background: #eee !important; border: 1px solid #ccc !important; z-index: 1; cursor: pointer; }" +
        " " + helpSel(HELP, " table") + " { display: block !important; max-width: 100% !important; overflow-x: auto !important; width: auto !important; }" +
        // max-width only: forcing height auto here blew up icons sized by the help text itself
        // (CC7's adoption icon and its 15px family sheet and timeline icons).
        " " + helpSel(HELP, " img") + ", " + helpSel(HELP, " video") + " { max-width: 100% !important; }" +
        " " + helpSel(HELP, " pre") + " { max-width: 100% !important; overflow-x: auto !important; white-space: pre-wrap; }" +
        " " + helpSel(HELP, " #print") + " { position: fixed !important; top: calc(12px + env(safe-area-inset-top)) !important; right: calc(60px + env(safe-area-inset-right)) !important; left: auto !important; z-index: 1; }" +
        // The page behind stays still while a pop-up is open (jQuery leaves display: block on it),
        // and the shell's "Saved" note, which sat over its last lines, is hidden meanwhile.
        " html:has(" + HELP_OPEN + ") { overflow: hidden !important; }" +
        " html:has(" + HELP_OPEN + ") #wt-shell-saved-note { display: none !important; }" +
        " }";

    // CC7 Views on phones: its Settings box and its per-person pop-ups (family sheet, timeline,
    // Bio Check report) are placed where the person was tapped, sized for a desktop (Settings is
    // 400px wide, with its top above the screen once the list is scrolled), and moved by jQuery UI
    // dragging, which does not follow a finger. So the Settings top was out of reach, a wide
    // timeline or family sheet could not be moved sideways, and one opened far to the side showed
    // only its middle, with no way to reach its [ x ]. On phones show each as a sheet over the
    // list with an 8px margin that scrolls inside, sideways too (the tables are wide until the
    // pop-up's own ↔ wraps them), and keep its [ x ] and ↔ at the sheet's top corners. The app
    // still opens, stacks and closes them as before (double-tap still closes too).
    var CC7_POPS = [".cc7Table #settingsDIV", ".cc7Table .familySheet.pop-up", ".cc7Table .timeline.pop-up", ".cc7Table .bioReport.pop-up"];
    var cc7Sel = function (tail) {
        return CC7_POPS.map(function (s) { return "html:not(#wt-cc7):not(#wt-cc7) " + s + (tail || ""); }).join(", ");
    };
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " " + cc7Sel() + " { position: fixed !important; top: calc(8px + env(safe-area-inset-top)) !important; bottom: auto !important;" +
        " left: calc(8px + env(safe-area-inset-left)) !important; right: calc(8px + env(safe-area-inset-right)) !important;" +
        " width: auto !important; max-width: none !important; height: auto !important; margin: 0 !important; box-sizing: border-box !important;" +
        " max-height: calc(100% - 16px - env(safe-area-inset-top) - env(safe-area-inset-bottom)) !important;" +
        " overflow: auto !important; overscroll-behavior: contain; -webkit-overflow-scrolling: touch;" +
        " touch-action: pan-x pan-y !important; cursor: auto !important; padding-top: 44px !important; }" +
        " " + cc7Sel(" > x") + ", " + cc7Sel(" > w") + " { position: fixed !important; top: calc(12px + env(safe-area-inset-top)) !important;" +
        " display: flex !important; align-items: center; justify-content: center; min-width: 40px; height: 36px; padding: 0 6px;" +
        " box-sizing: border-box; background: #eee; border: 1px solid #ccc; border-radius: 8px; z-index: 1; white-space: nowrap; }" +
        " " + cc7Sel(" > x") + " { right: calc(12px + env(safe-area-inset-right)) !important; left: auto !important; }" +
        " " + cc7Sel(" > w") + " { left: calc(12px + env(safe-area-inset-left)) !important; right: auto !important; }" +
        " html:not(#wt-cc7):not(#wt-cc7) .cc7Table .pop-up.wrap { width: auto !important; }" +
        " }";

    // Long notes. On phones each app's explanatory text (MORE[view].hide) is folded away behind
    // one short line ("About these numbers") placed after MORE[view].after or before
    // MORE[view].before; a tap shows the text again. addMore() adds the line. Warnings, errors,
    // login prompts and counts stay visible. Tablets unchanged.
    //  - CC7 Views: the note beside the degrees table ("We might not have retrieved all the
    //    requested connections ...") made each of its three rows 100px tall, and the pedigree
    //    report below it took 120px more, so the people list started 450px down a 780px screen.
    //    The "True CC7 size" line, and the warning shown instead of the note when a CC7 is too
    //    large to load, stay.
    var MORE = {
        cc7: {
            after: "#degreesTable",
            hide: "#degreesTable td.trueSize > .wt-more-note, #ancReport",
            label: "About these numbers",
            // The note shares its cell with the size line, as bare text after a <br>: wrap it.
            prepare: function () {
                var td = document.querySelector("#degreesTable td.trueSize");
                var br = td && !td.querySelector(".wt-more-note") && td.querySelector("br");
                if (!br || !br.nextSibling || br.nextSibling.nodeType !== 3) return;
                var span = document.createElement("span");
                span.className = "wt-more-note";
                br.parentNode.insertBefore(span, br.nextSibling);
                span.appendChild(span.nextSibling);
            },
        },
        // X Family Tree: 800px of explanation under the tree, which also started 72px off the
        // left edge when the tree is wider than the screen (the view scrolls sideways to keep the
        // start person in view), so the first words of each line were cut off. Folded in the
        // Probability Tree; in the Random Simulation its Randomize button is in the same box, so
        // that stays open. Either way the box and its line stay at the left of the screen.
        xtree: {
            before: "#XTreeAncestorList",
            hide: "#XTreeAncestorList:not(:has(button))",
            label: "About the X-chromosome tree",
        },
    };
    CSS += " .wt-more { display: none; }" + " @media (max-width: 599px), (max-height: 599px) {" +
        " button.wt-more { display: block; width: auto; margin: 2px 8px 6px; padding: 8px 4px; min-height: 40px; background: none; border: 0;" +
        " color: #25422d; font: inherit; font-size: 14px; text-decoration: underline; text-align: left; cursor: pointer; }" +
        " button.wt-more::after { content: \" \\25B8\"; } button.wt-more[aria-expanded=true]::after { content: \" \\25BE\"; }" +
        " html[data-wt-view=xtree] #XTreeAncestorList, html[data-wt-view=xtree] button.wt-more { position: sticky; left: 0; max-width: 100vw; box-sizing: border-box; }" +
        " html[data-wt-view=xtree] #XTreeAncestorList { padding: 0 10px 12px; }";
    Object.keys(MORE).forEach(function (view) {
        CSS += " " + MORE[view].hide.split(/,(?![^()]*\))/).map(function (s) {
            return "html[data-wt-view=" + view + "]:not([data-wt-more-open]) " + s.trim();
        }).join(", ") + " { display: none !important; }";
    });
    CSS += " }";

    // Person pop-ups in Fan Chart, Fractal Tree, FanDoku, Super Tree, Ancestor Webs and X Family
    // Tree: tapping a person opens #popupDIV (and its "connection" box #connectionPodDIV), which
    // the apps keep inside #info-panel. Hiding the controls hid the panel, pop-ups and all, so a
    // tap seemed to do nothing until the controls were shown. Only the panel's other contents are
    // hidden now (see CONTROLS). On phones the pop-up was also sized for a desktop: a 75px photo,
    // wide padding and borders, under the app's toolbar or off the side of the screen. It is now a
    // sheet along the bottom of the screen, 8px from each side, at most 55% of the screen tall
    // (it scrolls inside), with a smaller photo, text and tree-link icons. Its close x stays at
    // the top right. Phones only; jQuery UI dragging is not offered on a touch screen anyway.
    CSS +=
        " @media (max-width: 599px), (max-height: 599px) {" +
        " #info-panel > #popupDIV, #info-panel > #connectionPodDIV { position: fixed !important; left: 8px !important; right: 8px !important;" +
        " top: auto !important; bottom: 8px !important; width: auto !important; max-width: none !important; max-height: 55vh; overflow-x: hidden; overflow-y: auto;" +
        " padding: 0 !important; border: 0 !important; border-radius: 10px !important; background: none !important;" +
        " box-shadow: 0 4px 16px rgba(0,0,0,.35); font-size: 13px; line-height: 1.3; }" +
        " #info-panel > #popupDIV .popup-box, #info-panel > #connectionPodDIV .popup-box { padding: 8px 10px; position: relative; }" +
        " #info-panel > #popupDIV .popup-box .image-box { width: 52px; height: 52px; flex: none; }" +
        " #info-panel > #popupDIV .vital-info { padding: 0 0 4px 8px; min-width: 0; overflow-wrap: anywhere; }" +
        " #info-panel > #popupDIV .tree-links img, #info-panel > #popupDIV .tree-links svg { width: 34px !important; height: 23px !important; }" +
        " #info-panel > #popupDIV hr { margin: 6px 0; }" +
        " }";

    // Where each Tree App keeps its own controls. There is no shared convention, so apps are
    // added here one at a time. #info-panel is the shared panel used by Fan Chart, Fractal Tree,
    // Super Tree, the webs, Couples and others; the rest are app-specific.
    var CONTROLS =
        // (#info-panel's contents rather than the panel itself, so that the person pop-ups the
        // apps keep in it, #popupDIV and #connectionPodDIV, still show; see the block above)
        "#info-panel > :not(#popupDIV):not(#connectionPodDIV), header:not(main header) > :not([data-wt-site])," +
        " #ahnentafelOptions," +
        " #descendantsButtons, #helpEtc, #treeViewControls, #sharedControls, #reportControls," +
        " #couples-view-container > #ct-help-button," +
        " #cc7Container > div:has(> #getPeopleButton), #cc7Container > #tableButtons," +
        " #cctContainer > #controlBlock," +
        " #ccdContainer > #controlBlock," +
        " #ccwebs-view:has(.ccw-result) > .ccw-form," +
        " #aleContainer > #controlBlock," +
        " .lineage-matrix > .lineage-matrix__generation-control, .lineage-matrix > .lineage-matrix__status," +
        " .col-lg-12 > main > #controlWrapper," +
        " #statsContainer > #controlBlock," +
        " main#main:has(#watchCalendar) #view-options:has(> #display-mode), #watchCalendar > .fourteen.columns.center," +
        " .col-lg-12 > #familyViewOptions," +
        " .genealogyReportView > .gr-form," +
        " .ncloud-dialog > .ncloud-controls," +
        " .col-lg-12 > #printerFriendlyOptions," +
        " #view-container > #toggle-search, #research-app > .research-panel:has(> #research-form)," +
        " #cemeteriesTable_wrapper > #cemeteriesTable_length, #cemeteriesTable_wrapper > #cemeteriesTable_filter," +
        " #view-container > center:has(> #ancestors.button)," +
        // Slippy Tree already fills the screen; its round Help and Full-screen buttons floated
        // over the tree's top-left corner, so they are hidden too.
        " .slippy-tree-container > .slippy-help-button, .slippy-tree-container > .slippy-fullscreen-button";

    // Controls that the shell's button should offer before the app hides them itself (see the
    // Connection Checkers Web block above).
    var CONTROLS_LATER = "#ccwebs-view > .ccw-form";

    function tagSiteHeader() {
        var header = document.querySelector("header");
        if (header && !document.documentElement.classList.contains("wt-shell-ready")) {
            for (var i = 0; i < header.children.length; i++) {
                header.children[i].setAttribute("data-wt-site", "1");
            }
        }
        document.documentElement.classList.add("wt-shell-ready");
    }

    // Controls start hidden so the app gets the whole screen; the shell's bar shows them again.
    function applyControls() {
        document.documentElement.classList.toggle("wt-controls", !!window.__wtShellShowControls);
        var el = document.getElementById("wt-shell-controls");
        if (!window.__wtShellShowControls && !el) {
            el = document.createElement("style");
            el.id = "wt-shell-controls";
            // Prefixed so it outweighs app rules such as "body.report-mode #reportControls".
            el.textContent = CONTROLS.split(",").map(function (sel) {
                return "html.wt-shell-ready body " + sel.trim();
            }).join(", ") + " { display: none !important; }";
            (document.head || document.documentElement).appendChild(el);
        } else if (window.__wtShellShowControls && el) {
            el.remove();
        }
    }

    window.__wtShellSetControls = function (show) {
        window.__wtShellShowControls = !!show;
        applyControls();
        updateDock();
        // FanDoku, Fractal Tree and Ancestor Webs: the controls take room from the top of the
        // view, so fit the chart again (as on turning) or its bottom row was cut off.
        var view = document.documentElement.getAttribute("data-wt-view");
        if (boardFit && BOARDS[view]) fitBoard(view, true);
    };

    function hasControls() {
        var list = document.querySelectorAll(CONTROLS + ", " + CONTROLS_LATER);
        for (var i = 0; i < list.length; i++) {
            var el = list[i];
            // An empty box is not a control, but an icon-only link or button (Slippy Tree's) is.
            if (!el.classList.contains("hidden") && (el.innerHTML.trim() !== "" || el.matches("a, button"))) return true;
        }
        return false;
    }

    // Tablets (iPad, Android tablets, and any window at least 600 by 600, so split view and
    // Android multi-window follow the window, not the device): the settings box that Fan Chart,
    // FanDoku, Fractal Tree, Super Tree, Ancestor Webs and X Family Tree share (#settingsDIV,
    // opened with the app's gear) floated over the chart. It is docked instead: a 320px column
    // down the right side when the window is at least 900 wide and wider than tall, otherwise a
    // panel along the bottom, 40% of the height. The page shrinks to the room that is left, so
    // the chart re-fits beside or above it rather than hiding behind it. The box starts closed,
    // as the app has it; whether it was left open is remembered for each app and it opens again
    // next time. A swipe on the panel towards its edge (right for the column, down for the
    // bottom panel) closes it, as do the app's own close button and the shell's controls button.
    var DOCK_WIDE = "(min-width: 900px) and (min-height: 600px) and (min-aspect-ratio: 1/1)";
    var DOCK = "#info-panel > #settingsDIV";
    var DOCK_W = 320;
    CSS +=
        " html.wt-dock-side body " + DOCK + ", html.wt-dock-below body " + DOCK +
        " { position: fixed !important; margin: 0 !important; box-sizing: border-box; overflow-x: hidden; overflow-y: auto;" +
        " overscroll-behavior: contain; -webkit-overflow-scrolling: touch; border: 0 !important; border-radius: 0 !important;" +
        " box-shadow: none !important; padding: 16px 14px 24px !important; z-index: 1000 !important; max-width: none !important; max-height: none !important; }" +
        " html.wt-dock-side body " + DOCK + " { top: 0 !important; bottom: 0 !important; right: 0 !important; left: auto !important;" +
        " width: " + DOCK_W + "px !important; height: auto !important; border-left: 1px solid #c9cdbf !important; }" +
        " html.wt-dock-below body " + DOCK + " { left: 0 !important; right: 0 !important; bottom: 0 !important; top: auto !important;" +
        " width: auto !important; height: 40vh !important; border-top: 1px solid #c9cdbf !important; }" +
        // Its contents were laid out for a floating box: keep them inside the panel.
        " html.wt-dock-side body " + DOCK + " *, html.wt-dock-below body " + DOCK + " * { max-width: 100%; box-sizing: border-box; }" +
        " html.wt-dock-side body " + DOCK + " ul, html.wt-dock-below body " + DOCK + " ul { padding-left: 0; }" +
        " html.wt-dock-side body " + DOCK + " ul.profile-tabs, html.wt-dock-below body " + DOCK + " ul.profile-tabs { display: flex; flex-wrap: wrap; gap: 4px; }" +
        // While a panel is being swiped away it follows the finger (see dockSwipe).
        " html body " + DOCK + ".wt-dock-settle { transition: transform 0.2s ease-out; }" +
        // The page gives the panel its room. Charts that fill the screen (100vh columns, see the
        // per-app rules) get the height that is left above a bottom panel.
        " html.wt-dock-side body main#main { margin-right: " + DOCK_W + "px !important; }" +
        " html.wt-dock-below body { padding-bottom: 40vh !important; }" +
        " html.wt-dock-below body main#main .col-lg-12 { max-height: 60vh; }";

    // Ahnentafel on tablets: one list across a 1180px window gave lines far longer than the
    // entries. Each generation's people are laid out two to a row instead (father beside
    // mother), under the generation's heading, so the list still reads straight down and adding
    // a generation adds it at the bottom. (Newspaper columns were tried first, but with more
    // generations the reader had to scroll back up to the top of the second column.) Each
    // person's ↕ button was placed at the right edge of the whole list: it ends the person's own
    // row instead, as on phones.
    // In a wide landscape window, Ahnentafel's controls (its header box: help, List/Report
    // View, More Generations, Format, undo/redo; and its options: date format, date status,
    // IDs, colours, Excel, GEDCOM) sit in a 320px column on the right, like the docked settings,
    // so they stay in reach however far down the list is scrolled. They are shown and hidden
    // with the shell's controls button as before.
    var AHN = "html.wt-controls[data-wt-view=ahnentafel] body";
    CSS +=
        " @media (min-width: 600px) and (min-height: 600px) {" +
        " html[data-wt-view=ahnentafel] #ahnentafelAncestorList .generationContainer { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); column-gap: 16px; }" +
        " html[data-wt-view=ahnentafel] #ahnentafelAncestorList .descendantButton { position: static !important; flex: none; align-self: flex-start; margin: 0 0 0 6px !important; }" +
        " html[data-wt-view=ahnentafel] body > header > #ahnentafelOptions { padding: 4px 8px; }" +
        " }" +
        " @media " + DOCK_WIDE + " {" +
        " " + AHN + " main#main { margin-right: " + DOCK_W + "px !important; }" +
        " " + AHN + " > header { position: fixed !important; top: 0; bottom: 0; right: 0; width: " + DOCK_W + "px; z-index: 1000; overflow-y: auto; align-content: flex-start !important;" +
        " box-sizing: border-box; padding: 12px 14px 24px !important; background: #fff !important; border-left: 1px solid #c9cdbf !important; }" +
        " " + AHN + " #ahnentafelHeaderBox { display: flex !important; flex-wrap: wrap; align-items: center; gap: 6px; position: static !important; float: none !important; margin: 0 0 12px !important; width: auto !important; }" +
        " " + AHN + " #ahnentafelHeaderBox > * { margin: 0 !important; float: none !important; position: static !important; }" +
        " " + AHN + " > header > #ahnentafelOptions { display: flex !important; flex-direction: column; align-items: flex-start; gap: 10px; margin: 0 !important; padding: 0 !important; }" +
        " " + AHN + " > header > #ahnentafelOptions > * { margin: 0 !important; max-width: 100%; }" +
        " " + AHN + " > header > #ahnentafelOptions select { max-width: 100%; }" +
        " }";

    // Ahnentafel puts its options just above the list, inside the app's container, and when
    // more generations load it rebuilds that container with .html(), which threw the options
    // away until the app was opened again (a Tree App bug, listed in docs/tree-app-issues.md).
    // On tablets they are moved into the header beside the app's other buttons, out of the
    // container's way; their event handlers move with them. Report View's box likewise.
    function ahnKeepOptions() {
        if (document.documentElement.getAttribute("data-wt-view") !== "ahnentafel" || matchMedia(PHONE_QUERY).matches) return;
        var opts = document.getElementById("ahnentafelOptions");
        var box = document.getElementById("ahnentafelHeaderBox");
        if (opts && box && box.parentNode && opts.previousElementSibling !== box) box.parentNode.insertBefore(opts, box.nextSibling);
        // The box Report View draws into is thrown away by the same rebuild and never made
        // again, so Report View stayed blank after More Generations: it goes just after the
        // container instead.
        var report = document.getElementById("ahnentafelReportWrapper");
        var vc = document.getElementById("view-container");
        if (report && vc && vc.parentNode && report.parentNode !== vc.parentNode) vc.parentNode.insertBefore(report, vc.nextSibling);
    }

    var dockEl, dockObserver, dockMode = "";
    function dockKey() { return "wtDock_" + (document.documentElement.getAttribute("data-wt-view") || ""); }
    function dockRemember(open) { try { localStorage.setItem(dockKey(), open ? "1" : "0"); } catch (e) {} }
    function dockRemembered() { try { return localStorage.getItem(dockKey()) === "1"; } catch (e) { return false; } }

    function updateDock() {
        var el = document.querySelector(DOCK);
        if (el !== dockEl) {
            if (dockObserver) dockObserver.disconnect();
            dockEl = el;
            if (el) {
                // The app opens and closes the box by setting style.display: that is the
                // member's choice (the gear, its close button, Escape), so it is remembered.
                var was = el.style.display;
                dockObserver = new MutationObserver(function () {
                    var now = el.style.display;
                    if (now !== was) {
                        was = now;
                        if (!matchMedia(PHONE_QUERY).matches) dockRemember(now !== "none");
                    }
                    updateDock();
                });
                dockObserver.observe(el, { attributes: true, attributeFilter: ["style"] });
                el.addEventListener("touchstart", dockSwipe, { passive: true });
                if (!matchMedia(PHONE_QUERY).matches && el.style.display === "none" && dockRemembered()) el.style.display = "block";
            }
        }
        var open = !!el && !matchMedia(PHONE_QUERY).matches && getComputedStyle(el).display !== "none";
        var mode = open ? (matchMedia(DOCK_WIDE).matches ? "side" : "below") : "";
        if (mode === dockMode) return;
        var root = document.documentElement;
        root.classList.toggle("wt-dock-side", mode === "side");
        root.classList.toggle("wt-dock-below", mode === "below");
        dockMode = mode;
        // The charts that size themselves (Super Tree, the webs, FanDoku, Fractal Tree) are
        // told the page changed size, as on turning; Fan Chart's SVG follows by itself.
        setTimeout(function () { window.dispatchEvent(new Event("resize")); }, 50);
    }

    // Swipe the docked panel towards its edge to close it. Only a clear swipe in that direction
    // counts: taps, the panel's own scrolling and its drop-down menus are left alone.
    function dockSwipe(e) {
        var el = dockEl, mode = dockMode;
        if (!el || !mode || e.touches.length !== 1) return;
        var t0 = e.touches[0], x0 = t0.clientX, y0 = t0.clientY, at = Date.now(), d = 0, dragging = false;
        var atTop = el.scrollTop <= 0;
        if (/^(INPUT|SELECT|TEXTAREA)$/.test(e.target.tagName)) return;
        function move(ev) {
            var t = ev.touches[0], dx = t.clientX - x0, dy = t.clientY - y0;
            if (!dragging) {
                if (mode === "side" && dx > 12 && dx > Math.abs(dy) * 1.5) dragging = true;
                else if (mode === "below" && atTop && dy > 12 && dy > Math.abs(dx) * 1.5) dragging = true;
                else if (Math.abs(dx) > 12 || Math.abs(dy) > 12) return end();
                else return;
                el.classList.remove("wt-dock-settle");
            }
            ev.preventDefault();
            d = Math.max(0, mode === "side" ? dx : dy);
            el.style.transform = mode === "side" ? "translateX(" + d + "px)" : "translateY(" + d + "px)";
        }
        function end() {
            el.removeEventListener("touchmove", move);
            el.removeEventListener("touchend", end);
            el.removeEventListener("touchcancel", end);
            if (!dragging) return;
            var size = mode === "side" ? el.offsetWidth : el.offsetHeight;
            var fast = d > 40 && d / Math.max(1, Date.now() - at) > 0.5;
            el.classList.add("wt-dock-settle");
            if (d > size / 3 || fast) {
                el.style.transform = mode === "side" ? "translateX(100%)" : "translateY(100%)";
                setTimeout(function () {
                    el.classList.remove("wt-dock-settle");
                    el.style.transform = "";
                    el.style.display = "none";
                }, 200);
            } else {
                el.style.transform = "";
            }
        }
        el.addEventListener("touchmove", move, { passive: false });
        el.addEventListener("touchend", end);
        el.addEventListener("touchcancel", end);
    }

    setInterval(function () { updateDock(); ahnKeepOptions(); }, 500);
    [PHONE_QUERY, DOCK_WIDE].forEach(function (q) {
        var m = matchMedia(q);
        if (m.addEventListener) m.addEventListener("change", updateDock);
        else if (m.addListener) m.addListener(updateDock);
    });

    function apply() {
        var el = document.getElementById("wt-shell-css");
        var hide = !window.__wtShellShowBars;
        if (hide && !el) {
            el = document.createElement("style");
            el.id = "wt-shell-css";
            el.textContent = CSS;
            (document.head || document.documentElement).appendChild(el);
        } else if (!hide && el) {
            el.remove();
        }
    }

    // Dark mode: when the phone is set to dark, the Tree Apps go dark too. The apps have no dark
    // styles of their own, so the whole page is inverted (white to near black, black text to light
    // grey) and turned round the colour wheel, which keeps reds red and greens green, then given a
    // little less contrast so the black matches the shell's dark background. Photos, maps and
    // other pictures (silhouettes and privacy locks too) are inverted back so they look as they
    // should; CC7's black house icon is left inverted so it shows light on the dark page. Apps that read
    // badly this way can be listed in LIGHT_VIEWS to stay light. Kept in its own style element so
    // it stays when the site's bars are shown.
    var LIGHT_VIEWS = [];
    // Safari's engine (iPhone) moves or drops a filtered img element inside an SVG chart (Fan Chart's
    // and Super Tree's photos sit in a foreignObject), so there those pictures get no filter and
    // undarkSvgImages swaps in a copy with the colours already inverted instead.
    var SAFARI = /AppleWebKit/.test(navigator.userAgent) && !/Chrome|Android/.test(navigator.userAgent);
    var UNDARK = "img:not([src*=\"Home_icon\"])" + (SAFARI ? ":not(svg img)" : "") +
        ", video, canvas, picture, iframe, [style*=\"background-image\"]";
    function darkCss() {
        var root = "html.wt-dark" + LIGHT_VIEWS.map(function (v) { return ":not([data-wt-view=" + v + "])"; }).join("");
        return "" +
            " " + root + " { filter: invert(1) hue-rotate(180deg) contrast(0.86); background: #fff !important; color-scheme: light; }" +
            " " + UNDARK.split(", ").map(function (sel) { return root + " " + sel; }).join(", ") +
            " { filter: invert(1) hue-rotate(180deg); }" +
            // Photos inside SVG charts (Fan Chart, Super Tree): WebKit drew an <image> with a CSS
            // filter function at the page's top-left corner instead of in its place, so these are
            // inverted back with the same sums done as an SVG filter (#wt-undark, added below).
            " " + root + " svg image { filter: url(#wt-undark); }" +
            // A picture inside a picture (an <img> in an inverted iframe or <picture>) is inverted once only.
            " " + root + " picture img, " + root + " [style*=\"background-image\"] img { filter: none; }";
    }
    // invert(1) then hue-rotate(180deg) as one colour matrix: out = 1 - H·in, where H is CSS's
    // hue-rotate(180deg) matrix (its rows add up to 1, so a grey stays grey).
    var UNDARK_MATRIX = "0.574 -1.43 -0.144 0 1  -0.426 -0.43 -0.144 0 1  -0.426 -1.43 0.856 0 1  0 0 0 1 0";
    function addUndarkFilter() {
        if (!document.body || document.getElementById("wt-undark-defs")) return;
        var ns = "http://www.w3.org/2000/svg";
        var svg = document.createElementNS(ns, "svg");
        svg.id = "wt-undark-defs";
        svg.setAttribute("aria-hidden", "true");
        svg.setAttribute("style", "position: absolute; width: 0; height: 0; overflow: hidden");
        svg.innerHTML = "<filter id=\"wt-undark\" color-interpolation-filters=\"sRGB\">" +
            "<feColorMatrix type=\"matrix\" values=\"" + UNDARK_MATRIX + "\"/></filter>";
        document.body.appendChild(svg);
    }
    // Dark or not: the phone's setting as the web view sees it (prefers-color-scheme), unless the
    // app says otherwise. Android's web view keeps the setting it started with until the app is
    // restarted, so the Android app tells the page itself (window.__wtShellNight, and
    // __wtShellSetDark when the setting changes while the app is open).
    var darkQuery = window.matchMedia ? matchMedia("(prefers-color-scheme: dark)") : null;
    function setDarkClass() {
        var dark = typeof window.__wtShellNight === "boolean" ? window.__wtShellNight : !!(darkQuery && darkQuery.matches);
        document.documentElement.classList.toggle("wt-dark", dark);
        undarkSoon();
    }
    window.__wtShellSetDark = function (dark) {
        window.__wtShellNight = !!dark;
        setDarkClass();
    };
    if (darkQuery) {
        var onScheme = function () { if (typeof window.__wtShellNight !== "boolean") setDarkClass(); };
        if (darkQuery.addEventListener) darkQuery.addEventListener("change", onScheme);
        else if (darkQuery.addListener) darkQuery.addListener(onScheme);
    }
    // Safari only (see UNDARK): give each picture inside an SVG chart a pre-inverted copy while the
    // page is dark, and its own picture back when it is light. The original address is kept in
    // data-wt-src. Pictures from another site can't be read, so they stay as the page filter
    // leaves them.
    function undarkPixels(img) {
        var w = img.naturalWidth, h = img.naturalHeight, k = Math.min(1, 300 / Math.max(w, h));
        var c = document.createElement("canvas");
        c.width = Math.max(1, Math.round(w * k));
        c.height = Math.max(1, Math.round(h * k));
        var ctx = c.getContext("2d");
        ctx.drawImage(img, 0, 0, c.width, c.height);
        var data = ctx.getImageData(0, 0, c.width, c.height), d = data.data;
        for (var i = 0; i < d.length; i += 4) {
            var r = d[i], g = d[i + 1], b = d[i + 2];
            // 1 - H·colour, where H is hue-rotate(180deg): undone by the page's own filter.
            d[i] = 255 - (-0.574 * r + 1.43 * g + 0.144 * b);
            d[i + 1] = 255 - (0.426 * r + 0.43 * g + 0.144 * b);
            d[i + 2] = 255 - (0.426 * r + 1.43 * g - 0.856 * b);
        }
        ctx.putImageData(data, 0, 0);
        return c.toDataURL();
    }
    function undarkSvgImages() {
        if (!SAFARI) return;
        var dark = document.documentElement.classList.contains("wt-dark") &&
            LIGHT_VIEWS.indexOf(document.documentElement.getAttribute("data-wt-view")) < 0;
        var list = document.querySelectorAll("svg img");
        for (var i = 0; i < list.length; i++) {
            var img = list[i], src = img.getAttribute("src") || "", swapped = src.indexOf("data:") === 0 && img.hasAttribute("data-wt-src");
            if (/Home_icon/.test(src) || img.hasAttribute("data-wt-undark-failed")) continue;
            if (!dark) {
                if (swapped) {
                    img.setAttribute("src", img.getAttribute("data-wt-src"));
                    img.removeAttribute("data-wt-src");
                }
                continue;
            }
            if (swapped || src.indexOf("data:") === 0) continue;
            if (!img.complete || !img.naturalWidth) {
                img.addEventListener("load", undarkSoon, { once: true });
                continue;
            }
            try {
                var url = undarkPixels(img);
                img.setAttribute("data-wt-src", src);
                img.setAttribute("src", url);
            } catch (e) {
                img.setAttribute("data-wt-undark-failed", "1");
            }
        }
    }
    var undarkTimer;
    function undarkSoon() {
        if (!SAFARI || undarkTimer) return;
        undarkTimer = setTimeout(function () {
            undarkTimer = null;
            undarkSvgImages();
        }, 200);
    }
    function applyDark() {
        setDarkClass();
        addUndarkFilter();
        if (document.getElementById("wt-shell-dark")) return;
        var el = document.createElement("style");
        el.id = "wt-shell-dark";
        el.textContent = darkCss();
        (document.head || document.documentElement).appendChild(el);
    }

    window.__wtShellSetBars = function (show) {
        window.__wtShellShowBars = !!show;
        apply();
    };

    // State the shell's bar shows: current person, current app, login state, and the app list.
    window.__wtShellState = function () {
        var sel = document.getElementById("view-select");
        var views = [];
        if (sel) {
            for (var i = 0; i < sel.options.length; i++) {
                var o = sel.options[i];
                if (o.value && o.value !== "otherapps") views.push([o.value, o.text]);
            }
        }
        var idBox = document.getElementById("wt-id-text");
        var login = document.getElementById("wt-api-login");
        var loginText = login ? login.innerText.trim() : "";
        return JSON.stringify({
            id: idBox ? idBox.value.trim() : "",
            view: sel ? sel.value : "",
            views: views,
            loggedIn: /Logged into Apps/i.test(loginText),
            hasControls: hasControls(),
            loginText: loginText,
        });
    };

    window.__wtShellLogin = function () {
        var f = document.getElementById("appsLoginForm");
        if (f) {
            var r = document.getElementById("returnURL");
            if (r) r.value = location.href;
            // Forget the saved data first (see "Saved data" below), then log in.
            var go = function () { if (f) { var form = f; f = null; form.submit(); } };
            window.__wtShellClearSaved().then(go, go);
            setTimeout(go, 1000);
            return true;
        }
        return false;
    };

    window.__wtShellLogout = function () {
        var a = document.querySelector(".apiLogout");
        window.__wtShellClearSaved();
        if (a) a.click();
    };

    // Saved data (a trial, Descendants only). The Tree Apps fetch everything from the WikiTree
    // API again on every start, so a big tree is a long wait each time the app is reopened.
    // All of their API calls go through fetch() to api.php (WikiTreeAPI.postToAPI), so wrap
    // fetch: keep each successful answer in IndexedDB on the phone, keyed by the request, and
    // hand it back at once the next time the same request is made within a day. A small note
    // says the data is saved and how old it is; tapping it forgets the saved data and loads the
    // page again. Everything saved is forgotten on Apps login and logout, because the answers
    // depend on who is logged in and can include private profiles.
    var SAVE_VIEWS = { descendants: 1 };
    var SAVE_ACTIONS = { getPeople: 1, getPerson: 1, getAncestors: 1, getDescendants: 1, getRelatives: 1 };
    var SAVE_MAX_AGE = 24 * 60 * 60 * 1000;
    // On www.wikitree.com/apps the apps post to www.wikitree.com/api.php; elsewhere to api.
    var SAVE_API = /^https:\/\/(api|www)\.wikitree\.com\/api\.php(\?|$)/;
    var savedDb = null;
    var savedStore = function (mode) {
        if (!savedDb) {
            savedDb = new Promise(function (resolve, reject) {
                var req = indexedDB.open("wtShellSaved", 1);
                req.onupgradeneeded = function () { req.result.createObjectStore("api"); };
                req.onsuccess = function () { resolve(req.result); };
                req.onerror = function () { savedDb = null; reject(req.error); };
            });
        }
        return savedDb.then(function (db) { return db.transaction("api", mode).objectStore("api"); });
    };
    var savedRequest = function (mode, make) {
        return savedStore(mode).then(function (store) {
            return new Promise(function (resolve, reject) {
                var req = make(store);
                req.onsuccess = function () { resolve(req.result); };
                req.onerror = function () { reject(req.error); };
            });
        });
    };
    var savedClear = function () {
        return savedRequest("readwrite", function (store) { return store.clear(); }).catch(function () {});
    };
    window.__wtShellClearSaved = savedClear;
    // Forget answers older than a day, so the phone's storage does not fill up.
    var savedPrune = function () {
        savedStore("readwrite").then(function (store) {
            store.openCursor().onsuccess = function (e) {
                var c = e.target.result;
                if (!c) return;
                if (!c.value || Date.now() - c.value.t > SAVE_MAX_AGE) c.delete();
                c.continue();
            };
        }).catch(function () {});
    };
    // The key for a request worth saving, or null: a POST to the API with one of the read-only
    // actions, made while one of the SAVE_VIEWS apps is open. The login token is left out of
    // the key, since it changes with every login.
    var savedKey = function (input, init) {
        try {
            var url = typeof input === "string" ? input : input && input.url;
            if (url) url = new URL(url, location.href).href;
            if (!url || !SAVE_API.test(url) || !init || String(init.method).toUpperCase() !== "POST") return null;
            var view = document.documentElement.getAttribute("data-wt-view") ||
                (/[#&]view=([^&]*)/.exec(location.hash) || [])[1];
            if (!SAVE_VIEWS[view]) return null;
            var body = init.body;
            if (!(body instanceof URLSearchParams) && typeof body !== "string") return null;
            var params = new URLSearchParams(String(body));
            if (!SAVE_ACTIONS[params.get("action")]) return null;
            params.delete("token");
            params.sort();
            return params.toString();
        } catch (e) {
            return null;
        }
    };
    // Only complete answers are kept: JSON whose first item has status 0.
    var worthSaving = function (text) {
        try {
            var json = JSON.parse(text);
            var status = Array.isArray(json) && json[0] ? json[0].status : null;
            return status === 0 || status === "0" || status === "";
        } catch (e) {
            return false;
        }
    };
    var savedNote = null;
    var showSavedNote = function (t) {
        // Not for answers saved since this page was opened: those are as fresh as the page.
        if (savedNote || !document.body || t > performance.timeOrigin) return;
        var mins = Math.round((Date.now() - t) / 60000);
        var age = mins < 1 ? "just now" : mins < 60 ? mins + " min ago" : Math.round(mins / 60) + " h ago";
        var note = null;
        savedNote = document.createElement("button");
        savedNote.type = "button";
        savedNote.id = "wt-shell-saved-note";
        savedNote.textContent = "Saved data from " + age + ". Tap to update";
        savedNote.style.cssText = "position:fixed;left:50%;bottom:calc(12px + env(safe-area-inset-bottom));" +
            "transform:translateX(-50%);z-index:2147483000;padding:8px 14px;border:0;border-radius:18px;" +
            "background:rgba(37,66,45,.92);color:#fff;font:13px/1.2 -apple-system,Roboto,sans-serif;" +
            "white-space:nowrap;box-shadow:0 2px 8px rgba(0,0,0,.3);";
        savedNote.addEventListener("click", function () {
            savedNote.textContent = "Updating…";
            savedClear().then(function () { location.reload(); });
        });
        document.body.appendChild(savedNote);
        // After ten seconds shrink to a small chip in the corner rather than going away, so it
        // stays clear that the list is saved data and one tap still updates it.
        note = savedNote;
        setTimeout(function () {
            if (note.textContent.indexOf("Saved") !== 0) return;
            note.textContent = "\u21bb Saved " + age;
            note.style.left = "auto";
            note.style.right = "8px";
            note.style.transform = "none";
            note.style.padding = "5px 10px";
            note.style.fontSize = "11px";
            note.style.opacity = "0.8";
        }, 10000);
    };
    var realFetch = window.fetch;
    if (realFetch && window.indexedDB && window.Response && window.URLSearchParams) {
        window.fetch = function (input, init) {
            var self = this, args = arguments;
            var key = savedKey(input, init);
            if (!key) return realFetch.apply(self, args);
            var live = function () {
                return realFetch.apply(self, args).then(function (res) {
                    if (res.ok) {
                        res.clone().text().then(function (text) {
                            if (!worthSaving(text)) return;
                            return savedRequest("readwrite", function (store) {
                                return store.put({ t: Date.now(), body: text }, key);
                            });
                        }).catch(function () {});
                    }
                    return res;
                });
            };
            return savedRequest("readonly", function (store) { return store.get(key); }).then(function (hit) {
                if (!hit || Date.now() - hit.t > SAVE_MAX_AGE) return live();
                showSavedNote(hit.t);
                return new Response(hit.body, { status: 200, headers: { "Content-Type": "application/json" } });
            }, live);
        };
        setTimeout(savedPrune, 5000);
        // The page's own login form and logout link, for when the site bars are shown.
        document.addEventListener("submit", function (e) {
            if (e.target && e.target.id === "appsLoginForm") savedClear();
        }, true);
        document.addEventListener("click", function (e) {
            if (e.target && e.target.closest && e.target.closest(".apiLogout")) savedClear();
        }, true);
    }

    // Registered before the Tree Apps page's own hashchange listener, so the per-app rules
    // are in place before an app starts.
    setViewAttr();
    window.addEventListener("hashchange", setViewAttr);
    // The "About ..." line for MORE (see above), once its place is on the page. Safe to run any number of times; the app may build or rebuild its page at any time,
    // including after its files load late.
    // CC7 Views on phones: its Settings box has no close mark of its own (the settings icon that
    // toggles it is under the box once it is a sheet, see CC7_POPS). The app closes a pop-up when
    // an x element inside it is tapped, so give the box one, styled like the other pop-ups' [ x ].
    function cc7SettingsClose() {
        var box = document.querySelector(".cc7Table #settingsDIV");
        if (!box || box.querySelector(":scope > x") || !matchMedia(PHONE_QUERY).matches) return;
        var x = document.createElement("x");
        x.textContent = "[ x ]";
        x.style.color = "red";
        x.style.fontWeight = "bold";
        x.style.cursor = "pointer";
        box.insertBefore(x, box.firstChild);
    }

    // Compact Couple Ancestors on phones: its Height Factor (the vertical spacing) defaults to 55,
    // which packs the couples too tightly on a phone; 70 reads better (suggested by its author).
    // The app keeps its options in a cookie that it writes on every draw, so 55 there usually just
    // means the default. On a phone, the first time the app opens in this app (remembered in
    // localStorage), turn a 55 into 70 before the tree is first drawn. After that the user's own
    // choice always wins, including 55. The app fills the field from the cookie in the same step
    // that adds it, so this runs from the shell's MutationObserver, before the app's data arrives.
    function cctHeight() {
        var box = document.getElementById("cctTHFactor");
        if (!box || box.hasAttribute("data-wt-shell") || !matchMedia(PHONE_QUERY).matches) return;
        box.setAttribute("data-wt-shell", "");
        try {
            if (localStorage.getItem("wtShellCctHeight")) return;
            localStorage.setItem("wtShellCctHeight", "1");
        } catch (e) {
            return;
        }
        if (box.value === "55") box.value = "70";
    }

    var moreQueued = false;
    function addMore() {
        moreQueued = false;
        var view = document.documentElement.getAttribute("data-wt-view");
        var m = MORE[view];
        var at = m && document.querySelector(m.after || m.before);
        var placed = function (b) { return at && (m.after ? b.previousElementSibling : b.nextElementSibling) === at; };
        [].forEach.call(document.querySelectorAll("button.wt-more"), function (b) {
            if (b.getAttribute("data-wt-more") !== view || !placed(b) || !document.querySelector(m.hide)) b.remove();
        });
        if (!m || !matchMedia(PHONE_QUERY).matches) return;
        if (m.prepare) m.prepare();
        // Only when there is something to fold away.
        if (!at || !at.parentNode || !document.querySelector(m.hide) || [].some.call(document.querySelectorAll("button.wt-more"), placed)) return;
        var b = document.createElement("button");
        b.type = "button";
        b.className = "wt-more";
        b.setAttribute("data-wt-more", view);
        b.setAttribute("aria-expanded", document.documentElement.hasAttribute("data-wt-more-open") ? "true" : "false");
        b.textContent = m.label;
        b.addEventListener("click", function () {
            var open = !document.documentElement.hasAttribute("data-wt-more-open");
            if (open) document.documentElement.setAttribute("data-wt-more-open", "");
            else document.documentElement.removeAttribute("data-wt-more-open");
            b.setAttribute("aria-expanded", open ? "true" : "false");
        });
        at.parentNode.insertBefore(b, m.after ? at.nextSibling : at);
    }
    function queueMore() {
        if (!moreQueued) { moreQueued = true; requestAnimationFrame(addMore); }
    }
    window.addEventListener("hashchange", function () {
        document.documentElement.removeAttribute("data-wt-more-open");
        queueMore();
    });
    // Help pop-ups on phones (see HELP): a swipe inside one scrolls its text. Couples keeps its
    // pop-up inside the tree's container, whose zoom cancelled the swipe, so a touch inside a
    // pop-up goes no further than the pop-up. Taps still close it.
    ["touchstart", "touchmove"].forEach(function (type) {
        document.addEventListener(type, function (e) {
            var t = e.target;
            if (t && t.closest && t.closest(HELP.join(", ")) && matchMedia(PHONE_QUERY).matches) e.stopPropagation();
        }, { capture: true, passive: true });
    });
    // One Name Trees disables the Tree App bar's WikiTree ID box and Go button (#wt-id-text,
    // #show-btn) while it is open, and enables them again only when closed. The page changes app
    // or person on a new #view= or #name= by clicking that button, and a disabled button ignores
    // the click, so after One Name Trees the shell's app and person switching did nothing. This
    // listener is added before the page's own, so enable them just before it runs. Tree App bug,
    // see docs/tree-app-issues.md.
    window.addEventListener("hashchange", function () {
        [].forEach.call(document.querySelectorAll("#wt-id-text:disabled, #show-btn:disabled"), function (e) {
            e.disabled = false;
        });
    });
    // Ahnentafel keeps loading after it is closed. If another app is opened before its list is
    // built, it then writes its list over the new app and adds its button bar to the page header,
    // so for example Fan Chart showed the Ahnentafel list. Tree App bug, see
    // docs/tree-app-issues.md. When its parts turn up under another app, load the page again
    // (same #name= and #view=) so the app that was asked for starts afresh. At most once in 15
    // seconds; otherwise just remove them.
    // The same happens when Ahnentafel is asked for another person before the first person's list
    // is built: the first person's late results are added to the new person's list. The page
    // cannot tell which results are whose, so on a new #name= while Ahnentafel stays open, load
    // the page again with the new #name=. This runs before the page's own hashchange listener;
    // whatever that listener starts is dropped by the reload.
    var hashPart = function (key, hash) {
        var m = new RegExp("[#&]" + key + "=([^&]*)").exec(hash === undefined ? location.hash : hash);
        return m ? decodeURIComponent(m[1]) : "";
    };
    var lastHash = { name: hashPart("name"), view: hashPart("view") };
    // Load /apps/<new id>, as a fresh start does, rather than the old person's /apps/<id>.
    var reloadFor = function () {
        var path = "/apps/" + encodeURIComponent(hashPart("name"));
        if (hashPart("name") && location.pathname !== path) location.replace(path + location.hash);
        else location.reload();
    };
    window.addEventListener("hashchange", function () {
        var now = { name: hashPart("name"), view: hashPart("view") };
        var redo = now.view === "ahnentafel" && lastHash.view === "ahnentafel" && now.name !== lastHash.name;
        lastHash = now;
        if (redo) reloadFor();
    });
    var STALE = { ahnentafel: "#ahnentafelAncestorList, #ahnentafelHeaderBox" };
    var staleTimer = null;
    // Ahnentafel's report title "Ancestors of Ian Christopher Beacall (1969 – )" broke on a phone
    // with "– )" alone on the second line. Join the spaces inside a heading's closing "(...)" with
    // no-break spaces, so the dates move to the next line together.
    var keepDatesTogether = function () {
        [].forEach.call(document.querySelectorAll("#ahnentafelReport h1, #ahnentafelReport h2, #ahnentafelReport h3"), function (h) {
            var t = h.lastChild;
            if (!t || t.nodeType !== 3) return;
            var fixed = t.data.replace(/\([^()]*\)\s*$/, function (m) { return m.replace(/ +/g, "\u00a0"); });
            if (fixed !== t.data) t.data = fixed;
        });
    };
    var clearStale = function () {
        staleTimer = null;
        keepDatesTogether();
        var view = document.documentElement.getAttribute("data-wt-view");
        for (var key in STALE) {
            if (key === view || !document.querySelector(STALE[key])) continue;
            var last = 0;
            try { last = +sessionStorage.getItem("wtShellStaleReload") || 0; } catch (e) {}
            if (Date.now() - last > 15000) {
                try { sessionStorage.setItem("wtShellStaleReload", String(Date.now())); } catch (e) {}
                reloadFor();
            } else {
                [].forEach.call(document.querySelectorAll(STALE[key]), function (e) { e.remove(); });
            }
            return;
        }
    };
    // A picture of the whole chart, for the shell's "Share this chart" and "Print or save as
    // PDF". A picture of the screen held only the part in view, with any controls that were
    // showing. Now the phone asks the page to get ready first:
    //   __wtShellCapture("begin") hides the app's controls and the shell's own notes, and
    //     answers the size (CSS pixels, {w, h}) the web view needs to be to hold all of it;
    //   the phone makes the web view that size, out of sight, and calls
    //   __wtShellCapture("fit"), which lays the chart out in that space and answers the size
    //     needed again (the phone grows the view again if it is bigger, a few times at most);
    //   the phone takes the picture, puts the view back to its size and calls
    //   __wtShellCapture("end"), which puts everything back as it was.
    // Charts drawn in an SVG that the app pans and zooms with d3 (Fan Chart, Dynamic Tree, Super
    // Tree, the webs, FanDoku, Fractal Tree...): the view is made big enough for the whole chart
    // at the size it is shown, and the chart is moved and scaled to fill it with a margin. Only
    // the drawing's transform changes, never the app's own zoom state, and it is put back.
    // Lists, tables and reports that scroll: the view grows by what is scrolled out of sight, so
    // everything is laid out at once from the top. Anything else: the screen, without controls.
    // Each side is kept to CAPTURE_MAX device pixels; a longer list is cut off there. (Asked to
    // draw a web view much taller, Android drew the wrong part of the page: 6000 was tested.)
    var capture = null;
    var CAPTURE_MAX = 6000;
    var CAPTURE_MARGIN = 16;
    var CAPTURE_HIDE = "#wt-shell-loading, #wt-shell-saved-note, button.wt-more";

    // The element the app's d3 zoom is attached to (__zoom), with the chart's drawing: the SVG's
    // group that carries the zoom transform, and any HTML layer moved with it (Dynamic Tree).
    function captureChart() {
        var best = null, bestArea = 0;
        [].forEach.call(document.querySelectorAll("#view-container *"), function (e) {
            if (!e.__zoom) return;
            var r = e.getBoundingClientRect(), area = r.width * r.height;
            if (area > bestArea) { best = e; bestArea = area; }
        });
        if (!best) return null;
        var svg = best.tagName.toLowerCase() === "svg" ? best : best.querySelector(":scope > svg");
        var g = svg && svg.querySelector(":scope > g[transform]");
        if (!g) return null;
        var layers = [].filter.call(best.children, function (e) {
            return e !== svg && e.style && e.style.transform;
        });
        return {
            box: best, svg: svg, g: g, layers: layers,
            gTransform: g.getAttribute("transform"),
            layerTransforms: layers.map(function (e) { return e.style.transform; }),
        };
    }

    // What is drawn, in screen pixels. Skips what is not seen: hidden parts measure 0, and
    // shapes with no fill and no outline (some apps lay a big empty rectangle under the chart to
    // catch drags) are left out, as is Fractal Tree's invisible line far below the tree.
    function captureExtent(c) {
        var x1 = Infinity, y1 = Infinity, x2 = -Infinity, y2 = -Infinity;
        var add = function (e) {
            if (e.id === "lineAtBottomOfSVG") return;
            var b = e.getBoundingClientRect();
            if (!b.width && !b.height) return;
            if (/^(rect|path|circle|ellipse|polygon)$/i.test(e.tagName)) {
                var s = getComputedStyle(e);
                var noFill = s.fill === "none" || /rgba\(.*,\s*0\)$/.test(s.fill) || s.fillOpacity === "0";
                if (noFill && (s.stroke === "none" || s.strokeOpacity === "0")) return;
            }
            if (getComputedStyle(e).visibility === "hidden") return;
            x1 = Math.min(x1, b.left); y1 = Math.min(y1, b.top);
            x2 = Math.max(x2, b.right); y2 = Math.max(y2, b.bottom);
        };
        [].forEach.call(c.g.querySelectorAll("path, line, circle, ellipse, rect, polygon, polyline, text, image, foreignObject > *"), add);
        c.layers.forEach(function (layer) {
            [].forEach.call(layer.querySelectorAll("*"), function (e) {
                if (!e.children.length || e.tagName.toLowerCase() === "img") add(e);
            });
        });
        return x1 < x2 ? { left: x1, top: y1, width: x2 - x1, height: y2 - y1 } : null;
    }

    // Scroll boxes big enough to be the app (a quarter of the screen or more) that have more in
    // them than shows, and the page itself.
    function captureScrollers() {
        // The page, and <body>: under 980px the site's own CSS makes body a screen-high box that
        // scrolls (Ahnentafel), rather than the page.
        var list = [document.scrollingElement || document.documentElement];
        if (document.body && list.indexOf(document.body) < 0) list.push(document.body);
        var min = (innerWidth * innerHeight) / 4;
        [].forEach.call(document.querySelectorAll("main#main *"), function (e) {
            if (e.scrollHeight <= e.clientHeight + 2 && e.scrollWidth <= e.clientWidth + 2) return;
            if (e.clientWidth * e.clientHeight < min) return;
            var s = getComputedStyle(e);
            if (!/auto|scroll/.test(s.overflowX + s.overflowY)) return;
            list.push(e);
        });
        return list;
    }

    function captureNeed() {
        var w = innerWidth, h = innerHeight;
        if (capture.chart) {
            var c = capture.chart;
            var e = captureExtent(c), r = c.box.getBoundingClientRect();
            if (e) {
                // Room for the whole chart at the size it is shown, plus whatever on the page is
                // outside the chart's box (the app's own bars).
                w = Math.max(w, e.width + 2 * CAPTURE_MARGIN + (innerWidth - r.width));
                h = Math.max(h, e.height + 2 * CAPTURE_MARGIN + (innerHeight - r.height));
            }
        } else {
            var extraW = 0, extraH = 0;
            captureScrollers().forEach(function (s) {
                extraW = Math.max(extraW, s.scrollWidth - s.clientWidth);
                extraH = Math.max(extraH, s.scrollHeight - s.clientHeight);
            });
            w += extraW;
            h += extraH;
        }
        var max = CAPTURE_MAX / (window.devicePixelRatio || 1);
        return JSON.stringify({
            w: Math.round(Math.min(max, w)),
            h: Math.round(Math.min(max, h)),
            chart: !!capture.chart,
        });
    }

    // Move and scale the chart to fill its box (never more than 1.5 times the size it was shown
    // at), centred, by changing the transform on the drawing and its HTML layers.
    function captureFitChart(c) {
        c.g.setAttribute("transform", c.gTransform);
        c.layers.forEach(function (e, i) { e.style.transform = c.layerTransforms[i]; });
        var e = captureExtent(c), r = c.box.getBoundingClientRect();
        if (!e || !r.width || !r.height) return;
        var f = Math.min(1.5, (r.width - 2 * CAPTURE_MARGIN) / e.width, (r.height - 2 * CAPTURE_MARGIN) / e.height);
        if (!(f > 0)) return;
        // The move wanted, in screen pixels: scale by f about the chart's centre, then put that
        // centre in the middle of the box.
        var move = new DOMMatrix()
            .translate(r.left + r.width / 2, r.top + r.height / 2)
            .scale(f)
            .translate(-(e.left + e.width / 2), -(e.top + e.height / 2));
        // The group's new transform = (its parent's screen matrix)^-1 · move · (its own screen matrix).
        var parent = c.g.parentNode.getScreenCTM(), own = c.g.getScreenCTM();
        if (parent && own) {
            var m = DOMMatrix.fromMatrix(parent).inverse()
                .multiply(move).multiply(DOMMatrix.fromMatrix(own));
            c.g.setAttribute("transform", "matrix(" + [m.a, m.b, m.c, m.d, m.e, m.f].join(",") + ")");
        }
        // An HTML layer: the same move, put in front of its own transform, allowing for where
        // the layer sits and its transform origin.
        c.layers.forEach(function (layer, i) {
            var lr = layer.offsetParent ? layer.offsetParent.getBoundingClientRect() : { left: 0, top: 0 };
            var o = getComputedStyle(layer).transformOrigin.split(" ").map(parseFloat);
            var ox = lr.left + layer.offsetLeft + (o[0] || 0), oy = lr.top + layer.offsetTop + (o[1] || 0);
            var pre = new DOMMatrix().translate(-ox, -oy).multiply(move).multiply(new DOMMatrix().translate(ox, oy));
            layer.style.transform = pre.toString() + " " + c.layerTransforms[i];
        });
    }

    function captureEnd() {
        if (!capture) return "";
        var c = capture.chart;
        if (c) {
            c.g.setAttribute("transform", c.gTransform);
            c.layers.forEach(function (e, i) { e.style.transform = c.layerTransforms[i]; });
        }
        capture.scrolls.forEach(function (s) { s.el.scrollLeft = s.x; s.el.scrollTop = s.y; });
        capture.style.remove();
        capture = null;
        return "";
    }

    window.__wtShellCapture = function (step) {
        if (step === "end") return captureEnd();
        if (step === "fit") {
            if (!capture) return "";
            if (capture.chart) captureFitChart(capture.chart);
            else capture.scrollers.forEach(function (s) { s.scrollLeft = 0; s.scrollTop = 0; });
            return captureNeed();
        }
        captureEnd();
        var style = document.createElement("style");
        style.id = "wt-shell-capture";
        style.textContent = CONTROLS.split(",").concat(CONTROLS_LATER, CAPTURE_HIDE.split(",")).map(function (sel) {
            return "html.wt-shell-ready body " + sel.trim();
        }).join(", ") + " { display: none !important; }" +
            " ::-webkit-scrollbar { display: none !important; }";
        (document.head || document.documentElement).appendChild(style);
        capture = { style: style, chart: captureChart(), scrolls: [], scrollers: [] };
        if (!capture.chart) {
            capture.scrollers = captureScrollers();
            capture.scrolls = capture.scrollers.map(function (s) { return { el: s, x: s.scrollLeft, y: s.scrollTop }; });
            capture.scrollers.forEach(function (s) { s.scrollLeft = 0; s.scrollTop = 0; });
        }
        return captureNeed();
    };

    new MutationObserver(function () {
        queueMore();
        cctHeight();
        cc7SettingsClose();
        ahnKeepOptions();
        undarkSoon();
        if (!staleTimer) staleTimer = setTimeout(clearStale, 1000);
    }).observe(document.documentElement, { childList: true, subtree: true });
    window.addEventListener("resize", function () {
        if (capture) return;
        var view = document.documentElement.getAttribute("data-wt-view");
        if (boardFit && BOARDS[view]) fitBoard(view, true);
    });
    window.addEventListener("load", setViewAttr);
    apply();
    applyDark();
    applyControls();
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", function () {
            tagSiteHeader();
            apply();
            applyDark();
            applyControls();
        });
    } else {
        tagSiteHeader();
    }
})();
