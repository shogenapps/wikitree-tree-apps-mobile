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
        " main#main { padding-top: 0 !important; }" +
        " main#main > .row.mt-3 { margin-top: 0 !important; }" +
        " #view-container { margin: 0 !important; }";

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
