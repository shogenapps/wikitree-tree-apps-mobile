// Opens Genie (the WikiTree Browser Extension's assistant) on a wikitree.com page in one of the
// app's page sheets, for "Ask Genie" on the start screen. The app runs this file when the page
// has loaded, then calls __wtAskGenie with the question typed on the start screen ("" just opens
// Genie). It answers with a short note of how it went, which the app logs; the note is also kept
// in window.__wtGenieNote.
//
// WBE loads Genie lazily, the first time its Genie button is tapped. If the page has that button,
// it is tapped; if not, wbe-genie.js is loaded the way WBE does it (on iPhone the script's src
// goes through WBE's `file` host call, see Wbe.swift) and Genie is opened directly.
(function () {
  if (window.__wtAskGenie) return;

  var log = function (note) {
    try { console.log("WikiTree app, Genie: " + note); } catch (e) {}
    window.__wtGenieNote = note;
    return note;
  };

  // Wait for test() to give something, for up to ms milliseconds.
  function waitFor(test, ms, what) {
    return new Promise(function (resolve, reject) {
      var start = Date.now();
      (function check() {
        var found;
        try { found = test(); } catch (e) {}
        if (found) return resolve(found);
        if (Date.now() - start > ms) return reject(new Error("timed out waiting for " + what));
        setTimeout(check, 150);
      })();
    });
  }

  function popupInput() {
    var popup = document.getElementById("wbe-chat-popup");
    var input = document.getElementById("wbe-chat-input");
    if (!popup || !input) return null;
    var style = getComputedStyle(popup);
    return style.display !== "none" && style.visibility !== "hidden" ? input : null;
  }

  function genieButton() {
    return document.getElementById("wbe-chat-button") || document.getElementById("wbe-genie-button") ||
      document.querySelector(".wbe-genie-bar-button");
  }

  function loadGenie() {
    if (window.__wbeGenie) return Promise.resolve(window.__wbeGenie);
    return waitFor(function () {
      return window.chrome && chrome.runtime && chrome.runtime.getURL;
    }, 15000, "WBE").then(function () {
      if (window.__wbeGenie) return window.__wbeGenie;
      return new Promise(function (resolve, reject) {
        var s = document.createElement("script");
        s.src = chrome.runtime.getURL("wbe-genie.js");
        s.onload = function () {
          window.__wbeGenie ? resolve(window.__wbeGenie) : reject(new Error("wbe-genie.js ran, but Genie didn't start"));
        };
        s.onerror = function () { s.remove(); reject(new Error("wbe-genie.js couldn't be loaded")); };
        (document.head || document.documentElement).appendChild(s);
      });
    });
  }

  // Open Genie: WBE's own button if the page has one (it may take a moment to appear), else directly.
  function openGenie() {
    if (popupInput()) return Promise.resolve("already open");
    return waitFor(genieButton, 4000, "the Genie button").then(function (button) {
      button.click();
      return "button";
    }, function () {
      return loadGenie().then(function (g) {
        g.openChatPopup();
        return "direct";
      });
    });
  }

  // The app may call again when the page loads again (a redirect, or a reload that dropped the
  // first call); a page asks only once.
  var asking = null;
  window.__wtAskGenie = function (question) {
    if (asking) return asking;
    var how;
    return asking = openGenie().then(function (h) {
      how = h;
      return waitFor(popupInput, 20000, "Genie's window (opened by " + h + ")");
    }).then(function (input) {
      question = String(question || "").trim();
      if (!question) {
        input.focus();
        return log("opened (" + how + ")");
      }
      input.value = question;
      input.dispatchEvent(new Event("input", { bubbles: true }));
      var send = document.getElementById("wbe-chat-send");
      if (send && !send.disabled) {
        send.click();
        return log("asked (" + how + ")");
      }
      input.focus();
      return log("question typed, Send not ready (" + how + ")");
    }).catch(function (e) {
      return log("failed: " + (e && e.message || e));
    });
  };
})();
