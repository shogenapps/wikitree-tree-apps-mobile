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
        " main#main > .row.mt-3 { margin-top: 0 !important; }" +
        // Use the full width: main#main's 16px side padding and the container's border made
        // a tan margin and a grey line down each side on phones.
        " #view-container { margin: 0 !important; border: 0 !important; }" +
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
        " main#main .col-lg-12 > main:has(+ #view-container) { padding: 0 !important; }" +
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
    var BOARDS = { fandoku: { k: 0.45, app: "FandokuView" }, fractal: { k: 0.75, app: "FractalView" }, webs: { k: 1, app: "WebsView" } };
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
            if (!mine && (t.k !== start.k || Math.abs(t.x - svg.getAttribute("width") / 2) > 0.5)) return;
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
            var k = Math.max(0.05, Math.min(start.k, 0.96 * Math.min(w / box.width, h / box.height)));
            var x = Math.round(w / 2 - (box.x + box.width / 2) * k);
            var y = Math.round(h / 2 - (box.y + box.height / 2) * k);
            svg.__zoom = d3.zoomIdentity.translate(x, y).scale(k);
            g.setAttribute("transform", "translate(" + x + "," + y + ") scale(" + k + ")");
            if (window[start.app]) window[start.app].currentScaleFactor = k;
            boardFit = { svg: svg, k: k, x: x, y: y };
        }, 250));
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
            if (!svg || !view || !matchMedia(PHONE_QUERY).matches) return;
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
        var tries = 0, done;
        clearInterval(timelineTimer);
        var timer = (timelineTimer = setInterval(function () {
            if (++tries > 120 || document.documentElement.getAttribute("data-wt-view") !== "timeline") return clearInterval(timer);
            var view = window.wtViewRegistry && wtViewRegistry.views && wtViewRegistry.views.timeline;
            var tl = view && view.timeline;
            var panel = document.querySelector("#view-container .vis-panel.vis-center");
            if (!tl || tl === done || !panel || !matchMedia(PHONE_QUERY).matches) return;
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
        if (BOARDS[view] && Math.min(screen.width, screen.height) < 600) fitBoard(view);
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
        " html[data-wt-view=calendar] main > #view-options { display: flex; align-items: center; gap: 8px; padding: 4px 8px; }" +
        " html[data-wt-view=calendar] main > #view-options > label { margin: 0; white-space: nowrap; }" +
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
        " }";

    // Where each Tree App keeps its own controls. There is no shared convention, so apps are
    // added here one at a time. #info-panel is the shared panel used by Fan Chart, Fractal Tree,
    // Super Tree, the webs, Couples and others; the rest are app-specific.
    var CONTROLS =
        "#info-panel, header:not(main header) > :not([data-wt-site])," +
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
            f.submit();
            return true;
        }
        return false;
    };

    window.__wtShellLogout = function () {
        var a = document.querySelector(".apiLogout");
        if (a) a.click();
    };

    // Registered before the Tree Apps page's own hashchange listener, so the per-app rules
    // are in place before an app starts.
    setViewAttr();
    window.addEventListener("hashchange", setViewAttr);
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
    new MutationObserver(function () {
        if (!staleTimer) staleTimer = setTimeout(clearStale, 1000);
    }).observe(document.documentElement, { childList: true, subtree: true });
    window.addEventListener("resize", function () {
        var view = document.documentElement.getAttribute("data-wt-view");
        if (boardFit && BOARDS[view]) fitBoard(view, true);
    });
    window.addEventListener("load", setViewAttr);
    apply();
    applyControls();
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", function () {
            tagSiteHeader();
            apply();
            applyControls();
        });
    } else {
        tagSiteHeader();
    }
})();
