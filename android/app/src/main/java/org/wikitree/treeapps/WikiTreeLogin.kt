package org.wikitree.treeapps

import android.annotation.SuppressLint
import android.app.Activity
import android.app.AlertDialog
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import java.net.URLEncoder

/**
 * A native WikiTree login: email and password (the phone's password manager can fill them), sent
 * to WikiTree's own login forms by a WebView nobody sees. It shares the app's cookies, so the
 * member ends up logged in to the www.wikitree.com site (with "remember me") and to the Tree Apps,
 * as if they had used the web pages. The password is not kept. Mirrors LoginView in People.swift.
 */
class WikiTreeLogin(private val activity: Activity, private val onDone: () -> Unit) {
    private companion object {
        const val TAG = "WTLogin"
    }

    private val main = Handler(Looper.getMainLooper())
    private val density = activity.resources.displayMetrics.density
    private fun dp(v: Int) = (v * density).toInt()

    private var web: WebView? = null
    private var step = 0
    private var busy = false

    fun show() {
        val email = EditText(activity).apply {
            hint = activity.getString(R.string.login_email)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
            setAutofillHints(View.AUTOFILL_HINT_EMAIL_ADDRESS, View.AUTOFILL_HINT_USERNAME)
            importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_YES
            setSingleLine()
        }
        val password = EditText(activity).apply {
            hint = activity.getString(R.string.login_password)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            // A password field falls back to a monospace font; match the Email field instead.
            typeface = android.graphics.Typeface.DEFAULT
            setAutofillHints(View.AUTOFILL_HINT_PASSWORD)
            importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_YES
            setSingleLine()
            // setSingleLine swaps in its own transformation, which showed the password; hide it again.
            transformationMethod = android.text.method.PasswordTransformationMethod.getInstance()
        }
        val note = TextView(activity).apply {
            text = activity.getString(R.string.login_note)
            setTextColor(activity.getColor(R.color.text_secondary))
            setPadding(0, dp(8), 0, 0)
        }
        val error = TextView(activity).apply {
            setTextColor(activity.getColor(R.color.text_error))
            setPadding(0, dp(8), 0, 0)
            visibility = View.GONE
        }
        val form = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(8), dp(20), 0)
            addView(email)
            addView(password)
            addView(error)
            addView(note)
        }
        val dialog = AlertDialog.Builder(activity)
            .setTitle(R.string.login_title)
            .setView(form)
            .setPositiveButton(R.string.login_go, null)
            .setNeutralButton(R.string.login_web, null)
            .setNegativeButton(R.string.cancel, null)
            .create()
        dialog.setOnShowListener {
            val go = dialog.getButton(AlertDialog.BUTTON_POSITIVE)
            go.setOnClickListener {
                val e = email.text.toString().trim()
                val p = password.text.toString()
                if (busy || e.isEmpty() || p.isEmpty()) return@setOnClickListener
                go.isEnabled = false
                go.text = activity.getString(R.string.login_busy)
                error.visibility = View.GONE
                logIn(e, p) { ok, message ->
                    password.text.clear()
                    go.isEnabled = true
                    go.text = activity.getString(R.string.login_go)
                    if (ok) dialog.dismiss() else {
                        error.text = message
                        error.visibility = View.VISIBLE
                    }
                }
            }
            // Forgotten password and the like: WikiTree's own login page.
            dialog.getButton(AlertDialog.BUTTON_NEUTRAL).setOnClickListener {
                dialog.dismiss()
                WikiTreeSheet(activity).show(Uri.parse("https://www.wikitree.com/index.php?title=Special:Userlogin")) { onDone() }
            }
        }
        dialog.setOnDismissListener { if (!busy) onDone() }
        dialog.show()
    }

    private fun cookie(suffix: String): Boolean =
        CookieManager.getInstance().getCookie("https://www.wikitree.com").orEmpty().split(';')
            .map { it.trim() }
            .any { it.substringBefore('=').endsWith(suffix) && it.substringAfter('=', "").isNotEmpty() }

    private fun cookieNames() =
        CookieManager.getInstance().getCookie("https://www.wikitree.com").orEmpty().split(';')
            .map { it.trim().substringBefore('=') }.filter { it.isNotEmpty() }.joinToString(",")

    private fun form(fields: Map<String, String>) =
        fields.entries.joinToString("&") { it.key + "=" + URLEncoder.encode(it.value, "UTF-8") }.toByteArray()

    /** The site login (with "remember me"), then the Tree Apps' clientLogin. */
    @SuppressLint("SetJavaScriptEnabled")
    private fun logIn(email: String, password: String, done: (Boolean, String?) -> Unit) {
        busy = true
        // WikiTree's own login page, filled in and sent as a person would; that also takes care
        // of anything the site checks first (its firewall's challenge, a session cookie).
        step = 0
        var tries = 0
        var finished = false
        fun finish(ok: Boolean, message: String?) {
            if (finished) return
            finished = true
            busy = false
            CookieManager.getInstance().flush()
            web?.destroy()
            web = null
            done(ok, message)
        }
        // The Tree Apps login, which comes back to the Tree Apps page to finish.
        fun apiLogin(web: WebView) {
            step = 2
            web.postUrl(
                "https://api.wikitree.com/api.php",
                form(
                    mapOf(
                        "action" to "clientLogin", "doLogin" to "1", "returnURL" to "https://www.wikitree.com/apps/",
                        "wpEmail" to email, "wpPassword" to password,
                    ),
                ),
            )
        }
        // Fill in the login form and press Log In. The page may still be building it, so a
        // missing form is looked for again a few times, a second apart.
        fun fill(web: WebView) {
            if (finished || step != 0) return
            val values = org.json.JSONArray(listOf(email, password)).toString()
            web.evaluateJavascript("(function(a){var e=document.querySelector('input[name=wpEmail]');var p=document.querySelector('input[name=wpPassword]')||document.querySelector('input[type=password]');var f=(e&&e.form)||(p&&p.form);if(!e||!p||!f){if(document.querySelector('#watchlistSuggestionForm, form[name=watchlistSuggestionForm]'))return 'already';return 'noform '+document.title+' | forms: '+[].map.call(document.forms,function(x){return (x.id||x.name||'?')+'['+[].map.call(x.elements,function(i){return i.name}).join(',')+']'}).join(' ');}e.value=a[0];p.value=a[1];var r=document.getElementById('wpRemember');if(r)r.checked=true;var b=document.getElementById('wpLoginattempt');if(b)b.click();else f.submit();return 'ok';})($values)") { raw ->
                if (finished || step != 0) return@evaluateJavascript
                // Only "ok", or the page title and form field names (no values), are logged.
                android.util.Log.i(TAG, "fill form: $raw")
                if (raw == "\"ok\"") step = 1
                // The site already counts the member as logged in; only the Tree Apps part may be missing.
                else if (raw == "\"already\"") {
                    if (cookie("WikiTreeAPI_userName")) finish(true, null) else apiLogin(web)
                } else if (++tries >= 8) finish(false, activity.getString(R.string.login_no_page))
                else main.postDelayed({ fill(web) }, 1000)
            }
        }
        // Laid out but invisible, so the site's pages and scripts run as usual.
        val view = WebView(activity).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            alpha = 0f
        }
        activity.addContentView(view, ViewGroup.LayoutParams(1, 1))
        web = view
        view.webViewClient = object : WebViewClient() {
            override fun onPageFinished(page: WebView, url: String) {
                if (page !== web || finished) return
                val host = Uri.parse(url).host
                // Steps and page addresses only, never what was typed; for finding faults.
                android.util.Log.i(TAG, "step $step finished ${url.substringBefore('?')} cookies ${cookieNames()}")
                if (step == 0) {
                    fill(page)
                    return
                }
                if (step == 1) {
                    // Logged in once the login form is gone; otherwise WikiTree says why on the
                    // page (wrong password, unknown email, ...), or the page title shows where it ended up.
                    page.evaluateJavascript("(function(){if(document.querySelector('input[name=wpPassword]')){var m=document.querySelector('.errorbox, .error, .alert-danger, .warningbox');var t=m?m.innerText.trim():'';return 'fail:'+(t?t:'('+document.title+')');}return 'ok';})()") { raw ->
                        val said = try {
                            org.json.JSONArray("[$raw]").optString(0)
                        } catch (_: Exception) {
                            ""
                        }
                        android.util.Log.i(TAG, "after login: ${if (said == "ok") "ok" else "failed"}")
                        if (said == "ok") apiLogin(page)
                        else finish(false, activity.getString(R.string.login_refused) + " " + said.removePrefix("fail:"))
                    }
                } else if (step == 2 && host == "www.wikitree.com") {
                    // The Tree Apps page finishes the login by itself; give it a few seconds.
                    step = 3
                    var tries = 0
                    fun check() {
                        if (cookie("WikiTreeAPI_userName") || ++tries >= 10) finish(true, null)
                        else main.postDelayed({ check() }, 1000)
                    }
                    check()
                }
            }

            override fun onReceivedError(page: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (page !== web || !request.isForMainFrame) return
                android.util.Log.i(TAG, "step $step error ${error.errorCode} ${error.description} ${request.url.host}${request.url.path}")
                // Once the site has taken the login, a hitch in the Tree Apps part still leaves
                // the member logged in; the Tree Apps page logs them in there when it next opens.
                if (step >= 2) finish(true, null) else finish(false, activity.getString(R.string.login_failed))
            }
        }
        view.loadUrl("https://www.wikitree.com/index.php?title=Special:Userlogin")
        // A login that hangs gives up after a minute. WikiTree can be slow, and it may have
        // logged the member in before its last page finished loading, so the cookies are
        // checked before calling it a failure.
        main.postDelayed({
            if (!finished) android.util.Log.i(TAG, "gave up at step $step")
            val ok = step >= 2 || cookie("WikiTreeAPI_userName") || cookie("_UserName")
            if (ok) finish(true, null) else finish(false, activity.getString(R.string.login_failed))
        }, 60_000)
    }
}
