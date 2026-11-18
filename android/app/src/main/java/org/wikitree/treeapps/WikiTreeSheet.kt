package org.wikitree.treeapps

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Dialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.PopupMenu
import android.widget.TextView
import android.widget.Toast
import org.json.JSONObject

/**
 * A wikitree.com page (a profile, a help page) full screen over the app, in a WebView. It shares
 * the app's cookies, so the member is logged in to WikiTree as they are in the Tree Apps; a Custom
 * Tab would use the browser's own login. Links leaving wikitree.com open in the browser, and Back
 * goes back a page, then closes the sheet.
 *
 * On a profile, a Listen button reads the biography aloud (see [Biography]), with a bar at the
 * bottom to pause or stop; [show] with listen set starts reading as soon as the sheet opens.
 * Closing the sheet stops the reading.
 *
 * The WikiTree Browser Extension runs on the pages here (see [Wbe]), with a WBE button for its
 * settings, the tools its right-click menu offers on a computer, and a switch to turn it off.
 */
class WikiTreeSheet(private val activity: Activity) {
    private val density = activity.resources.displayMetrics.density
    private fun dp(v: Int) = (v * density).toInt()

    @SuppressLint("SetJavaScriptEnabled")
    fun show(uri: Uri, listen: Boolean = false, onClose: () -> Unit = {}) {
        val dialog = Dialog(activity, R.style.AppDialog)
        val green = activity.getColor(R.color.wt_green)
        val root = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(green)
            setOnApplyWindowInsetsListener { v, insets ->
                @Suppress("DEPRECATION")
                v.setPadding(
                    insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                    insets.systemWindowInsetRight, insets.systemWindowInsetBottom,
                )
                insets
            }
        }
        val title = TextView(activity).apply {
            setTextColor(activity.getColor(R.color.on_green))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(16), 0, dp(8), 0)
        }
        val bar = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        bar.addView(title, LinearLayout.LayoutParams(0, dp(52), 1f))
        val web = WebView(activity)
        val player = BioPlayer(activity)
        val listenButton = barButton(activity.getString(R.string.bio_listen)) {
            Biography.profileId(web.url ?: uri.toString())?.let { player.start(it) }
        }.apply {
            contentDescription = activity.getString(R.string.bio_listen_long)
            visibility = if (Biography.profileId(uri.toString()) != null) View.VISIBLE else View.GONE
        }
        bar.addView(listenButton)
        val browserButton = barButton(activity.getString(R.string.open_in_browser)) {
            open(Uri.parse(web.url ?: uri.toString()))
        }
        bar.addView(browserButton)
        var wbe: Wbe.Session? = null
        fun addWbe() {
            wbe = Wbe.attach(
                activity, web,
                openUrl = { openFromWbe(it) },
                openOptions = { showWbeSettings(web) },
            )
        }
        val wbeButton = barButton(activity.getString(R.string.wbe_button)) {}
        wbeButton.setOnClickListener {
            wbeMenu(wbeButton, web, on = wbe != null, turnOn = { addWbe(); web.reload() }, turnOff = {
                wbe?.remove()
                wbe = null
                web.reload()
            })
        }
        wbeButton.contentDescription = activity.getString(R.string.wbe_button_long)
        bar.addView(wbeButton)
        fun showButtonsFor(url: String) {
            val ownPage = Wbe.isWbePage(url)
            // WBE's own settings page lives inside the app, so there's no browser copy of it.
            browserButton.visibility = if (ownPage) View.GONE else View.VISIBLE
            wbeButton.visibility = if (ownPage || !Wbe.isAvailable(activity)) View.GONE else View.VISIBLE
        }
        showButtonsFor(uri.toString())
        bar.addView(barButton(activity.getString(R.string.done)) { dialog.dismiss() })
        root.addView(bar)
        val progress = ProgressBar(activity, null, android.R.attr.progressBarStyleHorizontal).apply {
            isIndeterminate = true
            visibility = View.GONE
        }
        root.addView(progress, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(4)))

        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        addWbe()
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val host = request.url.host
                val onWikiTree = host != null && (host == "wikitree.com" || host.endsWith(".wikitree.com"))
                // Other sites, and mailto: and the like, go to the system.
                if (!onWikiTree && !request.isRedirect || request.url.scheme.let { it != "http" && it != "https" }) {
                    open(request.url)
                    return true
                }
                return false
            }

            override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
                Wbe.intercept(activity, request)

            override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?) {
                progress.visibility = View.VISIBLE
            }

            override fun doUpdateVisitedHistory(view: WebView, url: String, isReload: Boolean) {
                listenButton.visibility = if (Biography.profileId(url) != null) View.VISIBLE else View.GONE
                showButtonsFor(url)
            }

            override fun onPageFinished(view: WebView, url: String) {
                progress.visibility = View.GONE
                title.text = view.title?.takeIf { it.isNotBlank() && !it.startsWith("http") } ?: ""
            }
        }
        root.addView(web, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        root.addView(player.view, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))

        dialog.setOnKeyListener { _, code, event ->
            if (code == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP && web.canGoBack()) {
                web.goBack()
                true
            } else {
                code == KeyEvent.KEYCODE_BACK && web.canGoBack()
            }
        }
        dialog.setOnDismissListener {
            player.release()
            wbe?.remove()
            Wbe.detach(web)
            web.destroy()
            // Keep a login made here even if the app is closed straight away.
            android.webkit.CookieManager.getInstance().flush()
            onClose()
            showing -= dialog
            if (showing.isEmpty()) {
                val actions = afterClose.values.toList()
                afterClose.clear()
                actions.forEach { it() }
            }
        }
        dialog.setContentView(root)
        dialog.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        dialog.show()
        showing += dialog
        web.loadUrl(uri.toString())
        if (listen) Biography.profileId(uri.toString())?.let { player.start(it) }
    }

    companion object {
        /** WBE's right-click tools and the feature each belongs to (its id in WBE's options). */
        private val WBE_TOOLS = listOf(
            WbeTool(R.string.wbe_notes, "showNotes", "clipboardAndNotes"),
            WbeTool(R.string.wbe_clipboard, "showClipboard", "clipboardAndNotes"),
            WbeTool(R.string.wbe_wikitable, "launchWikitableWizard", "wikitableWizard"),
            WbeTool(R.string.wbe_color_blind, "showColorBlindSimulator", "colorBlindSupport"),
        )

        private val showing = mutableSetOf<Dialog>()
        private val afterClose = linkedMapOf<String, () -> Unit>()

        /**
         * Run [action] now, or once every open sheet has closed if one is showing; a later action
         * with the same [key] replaces a waiting one. Redrawing the start screen while a sheet is
         * open would put it over the sheet, hiding its player bar while the biography is read.
         */
        fun whenClosed(key: String, action: () -> Unit) {
            if (showing.isEmpty()) action() else afterClose[key] = action
        }
    }

    /**
     * WBE's settings in a sheet of their own. If anything was changed there, [page] reloads when
     * it closes, so the change takes effect on the page underneath.
     */
    private fun showWbeSettings(page: WebView) {
        val before = Wbe.settingsChanges
        WikiTreeSheet(activity).show(Uri.parse(Wbe.OPTIONS_URL)) {
            if (Wbe.settingsChanges != before) try { page.reload() } catch (_: Exception) {}
        }
    }

    /** WBE's menu: settings, the right-click tools of the features that are on, and the on/off switch. */
    private fun wbeMenu(anchor: View, web: WebView, on: Boolean, turnOn: () -> Unit, turnOff: () -> Unit) {
        if (!on) {
            buildWbeMenu(anchor, web, false, emptySet(), turnOn, turnOff)
            return
        }
        Wbe.runningFeatures(web, WBE_TOOLS.map { it.feature }.distinct()) { running ->
            buildWbeMenu(anchor, web, true, running, turnOn, turnOff)
        }
    }

    private class WbeTool(val label: Int, val action: String, val feature: String)

    private fun buildWbeMenu(
        anchor: View, web: WebView, on: Boolean, running: Set<String>, turnOn: () -> Unit, turnOff: () -> Unit,
    ) {
        val menu = PopupMenu(activity, anchor)
        val version = Wbe.version(activity)
        if (on) {
            menu.menu.add(activity.getString(R.string.wbe_settings)).setOnMenuItemClickListener {
                showWbeSettings(web); true
            }
            // The same messages the extension's right-click menu sends to the page, for the
            // features that are turned on and running on this page.
            for (tool in WBE_TOOLS.filter { it.feature in running }) {
                val (label, action) = tool.label to tool.action
                menu.menu.add(activity.getString(label)).setOnMenuItemClickListener {
                    if (!Wbe.sendToPage(web, JSONObject().put("action", action))) {
                        Toast.makeText(activity, R.string.wbe_not_ready, Toast.LENGTH_SHORT).show()
                    }
                    true
                }
            }
            menu.menu.add(activity.getString(R.string.wbe_turn_off)).setOnMenuItemClickListener {
                Wbe.setEnabled(activity, false); turnOff(); true
            }
        } else {
            menu.menu.add(activity.getString(R.string.wbe_turn_on)).setOnMenuItemClickListener {
                Wbe.setEnabled(activity, true); turnOn(); true
            }
        }
        if (version.isNotEmpty()) {
            menu.menu.add("WikiTree Browser Extension $version").isEnabled = false
        }
        menu.show()
    }

    /** A link WBE opens in a new tab on a computer: wikitree.com in another sheet, the rest outside. */
    private fun openFromWbe(uri: Uri) {
        val host = uri.host.orEmpty()
        if (uri.scheme == "https" && (host == "wikitree.com" || host.endsWith(".wikitree.com"))) {
            WikiTreeSheet(activity).show(uri)
        } else {
            open(uri)
        }
    }

    private fun open(uri: Uri) {
        try {
            activity.startActivity(Intent(Intent.ACTION_VIEW, uri))
        } catch (_: ActivityNotFoundException) {
        }
    }

    private fun barButton(text: String, onClick: () -> Unit) = Button(activity, null, 0, R.style.BarButton).apply {
        this.text = text
        setOnClickListener { onClick() }
    }
}
