// Injected into https://www.wikitree.com/apps/ pages by the Tree Apps shell.
// It hides the site's own header, Tree App/ID bar and footer so the app gets the screen.
// The shell's native bar replaces them. Nothing here changes how the apps themselves work.
(function () {
    if (!/^\/apps(\/|$)/.test(location.pathname)) return;
    if (window.__wtShell) return;
    window.__wtShell = true;

    var CSS =
        "#offcanvasNavbar, #searchBar, .tabs--wrapper, #subfooter, .bg--tan, footer" +
        " { display: none !important; }" +
        // Some apps (Ahnentafel, Family Group App) add their own buttons to the site <header>.
        // So hide only the site's own header content (tagged in tagSiteHeader) and keep the rest.
        " html:not(.wt-shell-ready) header, header > [data-wt-site] { display: none !important; }" +
        " header { padding: 0 !important; margin: 0 !important; min-height: 0 !important;" +
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
        // Descendants on phones: the app lines up birth and death in four fixed columns sized
        // for a desktop, which runs off the right edge. Two columns instead: date, then place.
        " @media (max-width: 600px) {" +
        " #descendants .birthDeathDetails { grid-template-columns: auto 1fr !important; column-gap: 8px; margin-right: 8px; }" +
        " #descendantsReportWrapper { padding: 12px !important; align-items: stretch !important; max-width: 100%; box-sizing: border-box; }" +
        " #descendantsReport { width: auto !important; min-width: 0 !important; max-width: 100% !important; overflow-wrap: anywhere; }" +
        " #descendantsReport img { max-width: 100%; height: auto; }" +
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

    // The current Tree App's key (from #view=...) on <html>, for per-app rules above.
    function setViewAttr() {
        var m = /[#&]view=([^&]*)/.exec(location.hash);
        var view = m ? decodeURIComponent(m[1]) : "";
        document.documentElement.setAttribute("data-wt-view", view);
        if ((view === "wt-dynamic-tree" || view === "couples") && matchMedia(PHONE_QUERY).matches) recentre();
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

    // Where each Tree App keeps its own controls. There is no shared convention, so apps are
    // added here one at a time. #info-panel is the shared panel used by Fan Chart, Fractal Tree,
    // Super Tree, the webs, Couples and others; the rest are app-specific.
    var CONTROLS =
        "#info-panel, header > :not([data-wt-site])," +
        " #ahnentafelOptions," +
        " #descendantsButtons, #helpEtc, #treeViewControls, #sharedControls, #reportControls," +
        " #cc7Container > div:has(> #getPeopleButton), #cc7Container > #tableButtons," +
        " #cctContainer > #controlBlock," +
        " #ccdContainer > #controlBlock," +
        " #ccwebs-view:has(.ccw-result) > .ccw-form";

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
    };

    function hasControls() {
        var list = document.querySelectorAll(CONTROLS + ", " + CONTROLS_LATER);
        for (var i = 0; i < list.length; i++) {
            var el = list[i];
            if (!el.classList.contains("hidden") && el.innerHTML.trim() !== "") return true;
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
