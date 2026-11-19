package org.wikitree.treeapps

import android.content.Context
import android.net.Uri
import android.webkit.MimeTypeMap
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import androidx.webkit.JavaScriptReplyProxy
import androidx.webkit.ScriptHandler
import androidx.webkit.WebMessageCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException

/**
 * The WikiTree Browser Extension (WBE) on wikitree.com pages in the app's own web views.
 *
 * WBE's "webview" build (fetched at build time into assets/wbe/, see docs/wbe.md) carries its own
 * stand-in for the chrome.* extension APIs. The stand-in talks to `window.__wbeHost`, which this
 * class provides:
 *
 * - The build's files are served from the app at https://www.wikitree.com/__wbe/, so the site
 *   sees them as its own ([intercept]).
 * - A document-start script defines `__wbeHost` and then runs wbe-early.js and wbe-webview.js.
 * - Host calls arrive over a web message listener limited to https://www.wikitree.com: settings
 *   storage (one store for every web view, kept in SharedPreferences), openOptions, openUrl, and
 *   net.fetch for WBE's AI requests ([WbeAi]).
 * - When a page changes a setting, every other open WBE page gets a storageChanged event. The page
 *   that wrote it fires its own onChanged, so it is not sent the event again.
 */
object Wbe {
    const val ORIGIN = "https://www.wikitree.com"
    private const val PATH = "/__wbe/"
    const val OPTIONS_URL = "$ORIGIN${PATH}options.html"
    private const val PREFS = "wbe"
    private const val KEY_ENABLED = "enabled"

    /** True when this build of the app includes WBE and the device's WebView can run it. */
    fun isAvailable(context: Context): Boolean {
        available?.let { return it }
        val bundled = try {
            context.assets.open("wbe/webview.json").close()
            true
        } catch (_: IOException) {
            false
        }
        val supported = WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT) &&
            WebViewFeature.isFeatureSupported(WebViewFeature.WEB_MESSAGE_LISTENER)
        return (bundled && supported).also { available = it }
    }

    private var available: Boolean? = null

    /** On unless the member turned it off in the WBE menu. */
    fun isEnabled(context: Context) =
        isAvailable(context) && prefs(context).getBoolean(KEY_ENABLED, true)

    fun setEnabled(context: Context, on: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, on).apply()
    }

    fun isWbePage(url: String?) = url != null && url.startsWith("$ORIGIN$PATH")

    /** WBE's version, from webview.json, for the menu. */
    fun version(context: Context): String = try {
        JSONObject(context.assets.open("wbe/webview.json").bufferedReader().use { it.readText() }).optString("version")
    } catch (_: Exception) {
        ""
    }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * Serves https://www.wikitree.com/__wbe/... from assets/wbe/. Call from
     * [android.webkit.WebViewClient.shouldInterceptRequest]; null means "not ours".
     */
    fun intercept(context: Context, request: WebResourceRequest): WebResourceResponse? {
        val url = request.url
        if (url.scheme != "https" || url.host != "www.wikitree.com") return null
        val path = url.path ?: return null
        if (!path.startsWith(PATH)) return null
        val name = path.removePrefix(PATH)
        if (name.isEmpty() || name.split('/').any { it == ".." }) return notFound()
        return try {
            val stream = context.assets.open("wbe/$name")
            val ext = name.substringAfterLast('.', "").lowercase()
            val mime = when (ext) {
                "js", "mjs" -> "text/javascript"
                "json" -> "application/json"
                "css" -> "text/css"
                "html" -> "text/html"
                "svg" -> "image/svg+xml"
                "woff2" -> "font/woff2"
                "woff" -> "font/woff"
                "ttf" -> "font/ttf"
                else -> MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "application/octet-stream"
            }
            val text = mime.startsWith("text/") || mime == "application/json" || mime == "image/svg+xml"
            WebResourceResponse(mime, if (text) "utf-8" else null, stream).apply {
                responseHeaders = mapOf("Cache-Control" to "no-cache", "Access-Control-Allow-Origin" to ORIGIN)
            }
        } catch (_: IOException) {
            notFound()
        }
    }

    private fun notFound() = WebResourceResponse("text/plain", "utf-8", 404, "Not Found", null, "".byteInputStream())

    /** What [attach] added to one web view, so it can be taken off again. */
    class Session internal constructor(private val web: WebView, private val script: ScriptHandler) {
        fun remove() {
            script.remove()
            WebViewCompat.removeWebMessageListener(web, BRIDGE)
            pages.remove(web)
        }
    }

    private const val BRIDGE = "WbeNative"

    /** Main-frame pages by web view, with the channel to answer them and send them events. */
    private val pages = mutableMapOf<WebView, JavaScriptReplyProxy>()

    /**
     * Adds WBE to [web] for every https://www.wikitree.com page it loads from now on. Returns null
     * when WBE is off or can't run here. Call [Session.remove] or [detach] before the web view is
     * destroyed.
     */
    fun attach(
        context: Context,
        web: WebView,
        openUrl: (Uri) -> Unit,
        openOptions: () -> Unit,
    ): Session? {
        if (!isEnabled(context)) return null
        val script = try {
            WebViewCompat.addWebMessageListener(web, BRIDGE, setOf(ORIGIN)) { view, message, _, isMainFrame, reply ->
                if (isMainFrame) pages[view] = reply
                handle(context, view, message, reply, openUrl, openOptions)
            }
            WebViewCompat.addDocumentStartJavaScript(web, pageScript(context), setOf(ORIGIN))
        } catch (e: Exception) {
            android.util.Log.w("Wbe", "Could not add WBE", e)
            return null
        }
        return Session(web, script)
    }

    fun detach(web: WebView) {
        pages.remove(web)
    }

    /**
     * Sends a message to the WBE listeners on the page in [web] (chrome.runtime.onMessage), as the
     * extension's right-click menu would. Returns false if no WBE page has spoken from it yet.
     */
    fun sendToPage(web: WebView, message: JSONObject): Boolean {
        val reply = pages[web] ?: return false
        return post(web, reply, JSONObject().put("type", "message").put("message", message))
    }

    /**
     * Which WBE features are running on the page in [web]: WBE marks each one it starts with a
     * data-wbe-<feature id> attribute on <html>. Calls back with an empty set if there's no page.
     */
    fun runningFeatures(web: WebView, ids: List<String>, result: (Set<String>) -> Unit) {
        val js = "(function(ids){var h=document.documentElement;return ids.filter(function(i){return h.hasAttribute('data-wbe-'+i);}).join(',');})(" +
            JSONArray(ids).toString() + ")"
        web.evaluateJavascript(js) { raw ->
            val text = try {
                JSONArray("[$raw]").optString(0)
            } catch (_: Exception) {
                ""
            }
            result(text.split(',').filter { it.isNotEmpty() }.toSet())
        }
    }

    // --- The page side ---

    private var script: String? = null

    /**
     * One document-start script: the host, then the two bundles. WBE's own pages (the settings
     * screen) get only the host, because options.html loads its own bundle. Each part is in its own
     * try block so a failure in one doesn't stop the others.
     */
    private fun pageScript(context: Context): String {
        script?.let { return it }
        fun asset(name: String) = context.assets.open("wbe/$name").bufferedReader().use { it.readText() }
        val info = JSONObject(asset("webview.json"))
        val early = asset(info.optString("early", "wbe-early.js"))
        val main = asset(info.optString("entry", "wbe-webview.js"))
        return buildString {
            append(HOST_JS)
            append("\nif (!window.__wbeSkipBundles) { try {\n")
            append(early)
            append("\n} catch (e) { console.error('WBE early', e); } }\n")
            append("if (!window.__wbeSkipBundles) { try {\n")
            append(main)
            append("\n} catch (e) { console.error('WBE', e); } }\n")
        }.also { script = it }
    }

    // __wbeHost as the WBE stand-in expects it (see the WBE webview brief). The stand-in sets
    // reply() and event() on it; answers and events come back over the same channel.
    private const val HOST_JS = """
(function () {
  if (window.__wbeHost || typeof WbeNative === "undefined") return;
  var wbePage = location.pathname.indexOf("/__wbe/") === 0;
  window.__wbeSkipBundles = wbePage;
  var host = window.__wbeHost = {
    platform: "android",
    base: location.origin + "/__wbe/",
    send: function (json) { WbeNative.postMessage(json); }
  };
  WbeNative.onmessage = function (e) {
    var m;
    try { m = JSON.parse(e.data); } catch (x) { return; }
    if (m.kind === "reply") { if (host.reply) host.reply(m.id, m.error, m.result); }
    else if (m.kind === "event") { if (host.event) host.event(m.event); }
  };
  if (wbePage) {
    // The settings page is laid out for a 780 px popup; fit it to a phone: the options button
    // sits on the feature's own line and the creator line goes under the name.
    var fit = function () {
      var s = document.createElement("style");
      s.textContent = [
        "html { min-width: 0 !important; }",
        "body { max-width: 100vw; overflow-x: hidden; }",
        ".section-header { display: flex; flex-wrap: wrap; align-items: center; column-gap: 8px; }",
        ".feature-options-button { left: auto; top: auto; margin-left: auto; min-width: 0; padding: 5px 12px; font-size: 13px; }",
        ".feature-author { position: static; text-align: left; padding: 0; margin: 0 0 2px 22px; }",
        ".feature-author > div { display: inline; margin-right: 8px; }"
      ].join("\n");
      (document.head || document.documentElement).appendChild(s);
    };
    if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", fit); else fit();
  }
})();
"""

    // --- Host calls ---

    private fun handle(
        context: Context,
        view: WebView,
        message: WebMessageCompat,
        reply: JavaScriptReplyProxy,
        openUrl: (Uri) -> Unit,
        openOptions: () -> Unit,
    ) {
        val call = try {
            JSONObject(message.data ?: return)
        } catch (_: Exception) {
            return
        }
        val id = call.opt("id")
        val args = call.optJSONObject("args") ?: JSONObject()
        fun answer(error: String?, result: Any?) {
            val json = JSONObject()
                .put("kind", "reply")
                .put("id", id ?: JSONObject.NULL)
                .put("error", error ?: JSONObject.NULL)
                .put("result", if (result == null) "null" else result.toString())
            try {
                reply.postMessage(json.toString())
            } catch (_: Exception) {
            }
        }
        if (call.optString("method") == "net.fetch") {
            // (answered later: it may ask the member first, and the request takes a while)
            WbeAi.fetch(context, args) { error, result -> answer(error, result) }
            return
        }
        var error: String? = null
        var result: Any? = null
        try {
            when (val method = call.optString("method")) {
                "storage.get" -> result = Store(context, args.area()).get(args.opt("keys"))
                "storage.set" -> changed(context, view, args.area(), Store(context, args.area()).set(args.getJSONObject("items")))
                "storage.remove" -> changed(context, view, args.area(), Store(context, args.area()).remove(args.opt("keys")))
                "storage.clear" -> changed(context, view, args.area(), Store(context, args.area()).clear())
                "openOptions" -> openOptions()
                "openUrl" -> openUrl(Uri.parse(args.getString("url")))
                else -> error = "Unknown host method $method"
            }
        } catch (e: Exception) {
            error = e.message ?: e.javaClass.simpleName
        }
        answer(error, result)
    }

    private fun JSONObject.area(): String = when (val a = optString("area")) {
        "sync", "local" -> a
        else -> throw IllegalArgumentException("Unknown storage area $a")
    }

    /**
     * Counts changes to WBE's settings (the sync area), so a page can tell whether the settings
     * screen changed anything while it was open, and reload if so.
     */
    var settingsChanges = 0
        private set

    /** Tells every other open WBE page about a settings change. */
    private fun changed(context: Context, from: WebView, area: String, changes: JSONObject) {
        if (changes.length() == 0) return
        if (area == "sync") settingsChanges++
        val event = JSONObject().put("type", "storageChanged").put("area", area).put("changes", changes)
        for ((web, reply) in pages.toList()) {
            if (web !== from) post(web, reply, event)
        }
    }

    private fun post(web: WebView, reply: JavaScriptReplyProxy, event: JSONObject): Boolean = try {
        reply.postMessage(JSONObject().put("kind", "event").put("event", event.toString()).toString())
        true
    } catch (_: Exception) {
        // The page has gone (navigated away or closed): forget it until its next page speaks.
        pages.remove(web)
        false
    }

    /**
     * One storage area. Each key's value is kept as JSON, wrapped as {"v": value} so strings,
     * numbers and nulls survive as they are.
     */
    private class Store(context: Context, area: String) {
        private val prefs = context.getSharedPreferences("wbe_$area", Context.MODE_PRIVATE)

        private fun read(key: String): Any? = prefs.getString(key, null)?.let {
            try {
                JSONObject(it).opt("v")
            } catch (_: Exception) {
                null
            }
        }

        private fun keyList(keys: Any?): List<String>? = when (keys) {
            null, JSONObject.NULL -> null
            is String -> listOf(keys)
            is JSONArray -> (0 until keys.length()).map { keys.getString(it) }
            is JSONObject -> keys.keys().asSequence().toList()
            else -> listOf(keys.toString())
        }

        fun get(keys: Any?): JSONObject {
            val out = JSONObject()
            val names = keyList(keys) ?: prefs.all.keys.toList()
            for (k in names) {
                val v = read(k)
                when {
                    v != null -> out.put(k, v)
                    keys is JSONObject -> out.put(k, keys.opt(k))
                }
            }
            return out
        }

        fun set(items: JSONObject): JSONObject {
            val changes = JSONObject()
            val edit = prefs.edit()
            for (k in items.keys()) {
                val value = items.opt(k)
                val old = read(k)
                edit.putString(k, JSONObject().put("v", value ?: JSONObject.NULL).toString())
                changes.put(k, JSONObject().apply {
                    if (old != null) put("oldValue", old)
                    put("newValue", value ?: JSONObject.NULL)
                })
            }
            edit.apply()
            return changes
        }

        fun remove(keys: Any?): JSONObject {
            val changes = JSONObject()
            val edit = prefs.edit()
            for (k in keyList(keys).orEmpty()) {
                val old = read(k) ?: continue
                edit.remove(k)
                changes.put(k, JSONObject().put("oldValue", old))
            }
            edit.apply()
            return changes
        }

        fun clear(): JSONObject = remove(JSONArray(prefs.all.keys.toList()))
    }
}
