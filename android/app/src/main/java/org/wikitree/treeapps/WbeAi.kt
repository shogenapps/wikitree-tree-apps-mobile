package org.wikitree.treeapps

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * WBE's AI requests (Genie, Auto Bio's Improve with AI and the other AI features), which the
 * extension makes from its background script. In the app WBE sends them here as the `net.fetch`
 * host call, and the app makes the request itself, so no CORS rules get in the way.
 *
 * - Only the AI providers' API hosts are allowed ([PROVIDERS]); anything else is refused.
 * - The member brings their own API key (WBE's AI Settings); it goes only to that provider.
 * - The first time a provider is used, the member is asked whether WBE may send to it (app store
 *   rules ask for that before personal data goes to a third-party AI). Allow is remembered for that
 *   provider; Don't allow refuses this request only, so the next one asks again.
 */
object WbeAi {
    /** Host to the name the member knows the provider by. Matches ai_requests.js in WBE. */
    private val PROVIDERS = mapOf(
        "api.openai.com" to "OpenAI",
        "generativelanguage.googleapis.com" to "Google Gemini",
        "api.anthropic.com" to "Anthropic (Claude)",
        "api.perplexity.ai" to "Perplexity",
        "api.x.ai" to "xAI (Grok)",
        "ollama.com" to "Ollama Cloud",
    )

    private const val PREFS = "wbe_ai"
    private const val CONNECT_TIMEOUT_MS = 30_000
    // WBE gives up after 4½ minutes and says so; this is a little longer, so its message is the one shown.
    private const val READ_TIMEOUT_MS = 280_000

    private val network = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())

    /**
     * Handles one `net.fetch` call: { url, method, headers, body } -> { status, statusText, body }.
     * [done] is called once, on the main thread, with an error message or the result.
     */
    fun fetch(context: Context, args: JSONObject, done: (error: String?, result: JSONObject?) -> Unit) {
        val url = Uri.parse(args.optString("url"))
        val provider = PROVIDERS[url.host]
        if (url.scheme != "https" || provider == null) {
            return done("The WikiTree app only sends WBE's requests to the AI providers", null)
        }
        val method = args.optString("method", "GET").uppercase()
        if (method != "GET" && method != "POST") return done("Method $method isn't allowed", null)
        ask(context, url.host!!, provider) { allowed ->
            if (!allowed) {
                done(context.getString(R.string.wbe_ai_refused, provider), null)
            } else {
                network.execute {
                    val outcome = try {
                        null to request(url.toString(), method, args.optJSONObject("headers"), args.opt("body"))
                    } catch (e: Exception) {
                        (e.message ?: e.javaClass.simpleName) to null
                    }
                    main.post { done(outcome.first, outcome.second) }
                }
            }
        }
    }

    private fun ask(context: Context, host: String, provider: String, answer: (Boolean) -> Unit) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (prefs.getBoolean(host, false)) return answer(true)
        val activity = context as? Activity
        if (activity == null || activity.isFinishing) return answer(false)
        var answered = false
        fun reply(allowed: Boolean) {
            if (answered) return
            answered = true
            if (allowed) prefs.edit().putBoolean(host, true).apply()
            answer(allowed)
        }
        AlertDialog.Builder(activity)
            .setTitle(activity.getString(R.string.wbe_ai_title, provider))
            .setMessage(activity.getString(R.string.wbe_ai_message, provider))
            .setPositiveButton(R.string.wbe_ai_allow) { _, _ -> reply(true) }
            .setNegativeButton(R.string.wbe_ai_deny) { _, _ -> reply(false) }
            .setOnDismissListener { reply(false) }
            .show()
    }

    private fun request(url: String, method: String, headers: JSONObject?, body: Any?): JSONObject {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = CONNECT_TIMEOUT_MS
            connection.readTimeout = READ_TIMEOUT_MS
            connection.instanceFollowRedirects = false
            headers?.keys()?.forEach { name -> connection.setRequestProperty(name, headers.optString(name)) }
            if (method == "POST" && body is String) {
                connection.doOutput = true
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val status = connection.responseCode
            val stream = if (status >= 400) connection.errorStream else connection.inputStream
            val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
            return JSONObject()
                .put("status", status)
                .put("statusText", connection.responseMessage ?: "")
                .put("body", text)
        } finally {
            connection.disconnect()
        }
    }
}
