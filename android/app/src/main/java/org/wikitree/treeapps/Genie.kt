package org.wikitree.treeapps

import android.app.Activity
import android.net.Uri
import android.webkit.WebView
import org.json.JSONObject

/**
 * "Ask Genie" on the start screen. Genie is the WikiTree Browser Extension's assistant (see [Wbe]):
 * it searches WikiTree, answers questions and, with an AI key in WBE's settings, more. It lives on
 * wikitree.com pages, so asking opens a page sheet on the profile of the person the start screen's
 * Tree Apps are for (Genie then knows who "him" or "her" is), or WikiTree's home page with nobody,
 * and shared/genie.js opens Genie there with the question already sent.
 */
object Genie {
    /** Genie needs WBE, which the member can turn off. */
    fun isAvailable(activity: Activity) = Wbe.isEnabled(activity)

    /** Open Genie over the app, asking [question] ("" just opens it). */
    fun open(activity: Activity, question: String, personId: String) {
        val page = if (personId.isBlank()) "https://www.wikitree.com/"
        else "https://www.wikitree.com/wiki/" + Uri.encode(personId)
        WikiTreeSheet(activity).show(Uri.parse(page), genie = question.trim())
    }

    /**
     * Called by the sheet when a page has loaded. [opened] runs once Genie has opened on this page
     * (genie.js leaves a note of how it went in window.__wtGenieNote, looked at every second).
     */
    fun ask(activity: Activity, web: WebView, question: String, opened: () -> Unit) {
        val js = activity.assets.open("genie.js").bufferedReader().use { it.readText() }
        web.evaluateJavascript(js + "\n;window.__wtAskGenie(" + JSONObject.quote(question) + "); void 0;", null)
        val page = web.url
        var tries = 0
        fun check() {
            if (web.url != page || ++tries > 45) return
            web.evaluateJavascript("window.__wtGenieNote || ''") { raw ->
                val note = raw?.trim('"').orEmpty()
                when {
                    note.isEmpty() -> web.postDelayed({ check() }, 1000)
                    !note.startsWith("failed") -> opened()
                    else -> android.util.Log.w("Genie", note)
                }
            }
        }
        web.postDelayed({ check() }, 1000)
    }
}
