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
        " main#main .col-lg-12 > main:has(+ #view-container.ahnentafelView) { padding: 0 !important; }" +
        " #ahnentafelOptions { margin: 6px 8px !important; padding: 8px 10px !important; gap: 6px 12px !important; }" +
        " #ahnentafelReportWrapper { padding: 12px !important; align-items: stretch !important; max-width: 100%; box-sizing: border-box; }" +
        " #ahnentafelReport { width: auto !important; min-width: 0 !important; max-width: 100% !important; overflow-wrap: anywhere; }" +
        " #ahnentafelReport img { max-width: 100%; height: auto; }" +
        " #ahnentafelReport .table-wrapper, #ahnentafelReport pre { max-width: 100%; overflow-x: auto; }";

    // Where each Tree App keeps its own controls. There is no shared convention, so apps are
    // added here one at a time. #info-panel is the shared panel used by Fan Chart, Fractal Tree,
    // Super Tree, the webs, Couples and others; the rest are app-specific.
    var CONTROLS =
        "#info-panel, header > :not([data-wt-site])," +
        " #ahnentafelOptions," +
        " #treeViewControls, #sharedControls, #reportControls";

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
            el.textContent = CONTROLS + " { display: none !important; }";
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
        var list = document.querySelectorAll(CONTROLS);
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
