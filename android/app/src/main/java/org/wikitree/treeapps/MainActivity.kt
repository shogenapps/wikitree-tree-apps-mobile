package org.wikitree.treeapps

import android.annotation.SuppressLint
import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.text.InputType
import android.view.View
import android.view.WindowInsets
import android.webkit.CookieManager
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.PopupMenu
import android.widget.ProgressBar
import android.widget.TextView
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.json.JSONObject

/**
 * A thin shell around the WikiTree Tree Apps (https://www.wikitree.com/apps/).
 *
 * It loads the real Tree Apps page in a WebView, hides the site's header, Tree App/ID bar
 * and footer (see assets/shell.js), and puts a slim native bar on top with:
 *   - the current Tree App (tap to pick another),
 *   - the current WikiTree ID (tap to change person),
 *   - a menu for Apps login/logout, reload, and opening things in the browser.
 *
 * Each Tree App keeps its own settings and controls, exactly as on the website.
 */
class MainActivity : Activity() {

    private lateinit var web: WebView
    private lateinit var btnApp: Button
    private lateinit var btnPerson: Button
    private lateinit var progress: ProgressBar
    private lateinit var errorText: TextView

    private val prefs by lazy { getSharedPreferences("shell", MODE_PRIVATE) }
    private val shellJs by lazy { assets.open("shell.js").bufferedReader().use { it.readText() } }

    /** shared/views.json: the Tree App list used until the page has loaded its own. */
    private val viewsJson by lazy { JSONObject(assets.open("views.json").bufferedReader().use { it.readText() }) }
    private val knownViews by lazy {
        val arr = viewsJson.getJSONArray("views")
        (0 until arr.length()).map { arr.getJSONObject(it).let { o -> o.getString("key") to o.getString("title") } }
    }
    /** Wide charts: on phones the shell turns to landscape and locks there while they are open. */
    private val landscapeViews by lazy {
        val arr = viewsJson.getJSONArray("views")
        (0 until arr.length()).map { arr.getJSONObject(it) }
            .filter { it.optBoolean("landscape") }.map { it.getString("key") }.toSet()
    }
    private val defaultView by lazy { viewsJson.optString("defaultView", "fanchart") }

    private var currentId = ""
    private var currentView = ""
    private var loggedIn = false
    private var pageViews: List<Pair<String, String>> = emptyList()
    private var showBars = false

    /** Set while heading back to the tree from a site page, so a failed return can't loop. */
    private var returning = false

    private var fileCallback: ValueCallback<Array<Uri>>? = null

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        web = findViewById(R.id.web)
        btnApp = findViewById(R.id.btn_app)
        btnPerson = findViewById(R.id.btn_person)
        progress = findViewById(R.id.progress)
        errorText = findViewById(R.id.error)

        applySystemBarInsets(findViewById(R.id.root))

        currentId = prefs.getString(KEY_ID, "") ?: ""
        currentView = prefs.getString(KEY_VIEW, "") ?: ""
        updateBar()

        btnApp.setOnClickListener { pickApp() }
        btnPerson.setOnClickListener { askPerson() }
        findViewById<Button>(R.id.btn_menu).setOnClickListener { showMenu(it) }

        setUpWebView()

        if (savedInstanceState != null) {
            web.restoreState(savedInstanceState)
        } else {
            web.loadUrl(intent?.data?.takeIf { isTreeAppsUrl(it) }?.toString() ?: startUrl())
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.data?.takeIf { isTreeAppsUrl(it) }?.let { web.loadUrl(it.toString()) }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        web.saveState(outState)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (web.canGoBack()) web.goBack() else super.onBackPressed()
    }

    // ---- WebView ---------------------------------------------------------------------------

    @SuppressLint("SetJavaScriptEnabled")
    private fun setUpWebView() {
        with(web.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            loadWithOverviewMode = false
            useWideViewPort = true
            builtInZoomControls = true
            displayZoomControls = false
            setSupportZoom(true)
            mediaPlaybackRequiresUserGesture = true
        }
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(web, true)

        // Inject the hiding CSS before the page draws, so the site bars never flash on screen.
        // Older WebViews fall back to injecting when the page finishes loading.
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            WebViewCompat.addDocumentStartJavaScript(web, shellJs, setOf(SITE_ORIGIN))
        }

        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                val uri = request.url
                if (uri.scheme != "http" && uri.scheme != "https") {
                    openExternally(uri) // mailto:, tel:, etc.
                    return true
                }
                val host = uri.host ?: return false
                val onWikiTree = host == "wikitree.com" || host.endsWith(".wikitree.com")
                // Tree Apps pages always stay in the app.
                if (isTreeAppsUrl(uri)) return false
                // Redirects stay too: the Apps login goes to api.wikitree.com and back, and may
                // pass through the WikiTree site login page on the way.
                if (onWikiTree && request.isRedirect) return false
                // So does anything followed from a page that isn't a Tree App (i.e. mid-login).
                val from = Uri.parse(view.url ?: "")
                if (onWikiTree && !isTreeAppsUrl(from)) return false
                // Everything else (profile links, sources, help pages) opens in a browser sheet
                // over the tree, so closing it returns to the tree exactly as it was.
                openInSheet(uri)
                return true
            }

            override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
                progress.visibility = View.VISIBLE
                errorText.visibility = View.GONE
            }

            override fun onPageFinished(view: WebView, url: String) {
                progress.visibility = View.GONE
                val uri = Uri.parse(url)
                if (shouldReturnToTree(uri)) {
                    // After logging in, the site lands on its own pages (e.g. the Navigation Home
                    // Page). Go back to the tree; the Tree Apps page then completes the Apps login.
                    if (!returning) {
                        returning = true
                        view.loadUrl(startUrl())
                        return
                    }
                } else if (isTreeAppsUrl(uri)) {
                    returning = false
                }
                if (uri.host == SITE_HOST) {
                    view.evaluateJavascript(shellJs, null)
                    view.evaluateJavascript("window.__wtShellSetBars && __wtShellSetBars($showBars)", null)
                }
                refreshState()
            }

            override fun doUpdateVisitedHistory(view: WebView, url: String, isReload: Boolean) {
                // Fires for hash changes too, which is how the Tree Apps switch person/app.
                readHash(Uri.parse(url))
            }

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame) {
                    progress.visibility = View.GONE
                    errorText.visibility = View.VISIBLE
                }
            }
        }

        web.webChromeClient = object : WebChromeClient() {
            // Some apps (CC7, One Name Trees) can load a saved file.
            override fun onShowFileChooser(
                webView: WebView,
                callback: ValueCallback<Array<Uri>>,
                params: FileChooserParams,
            ): Boolean {
                fileCallback?.onReceiveValue(null)
                fileCallback = callback
                return try {
                    startActivityForResult(params.createIntent(), REQ_FILE)
                    true
                } catch (e: ActivityNotFoundException) {
                    fileCallback = null
                    false
                }
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ_FILE) {
            fileCallback?.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(resultCode, data))
            fileCallback = null
        } else {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    // ---- State from the page -----------------------------------------------------------------

    private fun readHash(uri: Uri) {
        if (uri.host != SITE_HOST || uri.path?.startsWith("/apps") != true) return
        val frag = uri.fragment ?: return
        val params = frag.split("&").mapNotNull {
            val i = it.indexOf('=')
            if (i > 0) it.substring(0, i) to Uri.decode(it.substring(i + 1)) else null
        }.toMap()
        params["name"]?.takeIf { it.isNotBlank() }?.let { currentId = it }
        params["view"]?.takeIf { it.isNotBlank() }?.let { currentView = it }
        save()
        updateBar()
    }

    private fun refreshState() {
        web.evaluateJavascript("window.__wtShellState ? __wtShellState() : null") { raw ->
            if (raw == null || raw == "null") return@evaluateJavascript
            try {
                // evaluateJavascript returns the string JSON-encoded, so decode twice.
                val json = JSONObject(JSONObject("{\"v\":$raw}").getString("v"))
                json.optString("id").takeIf { it.isNotBlank() }?.let { currentId = it }
                json.optString("view").takeIf { it.isNotBlank() }?.let { currentView = it }
                loggedIn = json.optBoolean("loggedIn")
                val arr = json.optJSONArray("views")
                if (arr != null && arr.length() > 0) {
                    pageViews = (0 until arr.length()).map {
                        val p = arr.getJSONArray(it)
                        p.getString(0) to p.getString(1)
                    }
                }
                save()
                updateBar()
            } catch (_: Exception) {
            }
        }
    }

    private fun save() {
        prefs.edit().putString(KEY_ID, currentId).putString(KEY_VIEW, currentView).apply()
    }

    private fun updateBar() {
        btnApp.text = viewTitle(currentView) ?: getString(R.string.choose_app)
        btnPerson.text = currentId.ifBlank { getString(R.string.change_person) }
        applyOrientation()
    }

    private fun applyOrientation() {
        val isPhone = resources.configuration.smallestScreenWidthDp < 600
        val lock = isPhone && prefs.getBoolean(KEY_AUTO_ROTATE, true) && currentView in landscapeViews
        val wanted = if (lock) ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        else ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        if (requestedOrientation != wanted) requestedOrientation = wanted
    }

    private fun views(): List<Pair<String, String>> = pageViews.ifEmpty { knownViews }

    private fun viewTitle(key: String): String? = views().firstOrNull { it.first == key }?.second

    // ---- Bar actions -----------------------------------------------------------------------

    private fun pickApp() {
        val list = views()
        val titles = list.map { it.second }.toTypedArray()
        val checked = list.indexOfFirst { it.first == currentView }
        AlertDialog.Builder(this)
            .setTitle(R.string.choose_app)
            .setSingleChoiceItems(titles, checked) { d, which ->
                d.dismiss()
                show(currentId, list[which].first)
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun askPerson() {
        val input = EditText(this).apply {
            hint = getString(R.string.person_prompt)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            setSingleLine()
            setText(currentId)
            selectAll()
        }
        val pad = (20 * resources.displayMetrics.density).toInt()
        val box = FrameLayout(this).apply {
            setPadding(pad, pad / 2, pad, 0)
            addView(input)
        }
        val dialog = AlertDialog.Builder(this)
            .setTitle(R.string.change_person)
            .setView(box)
            .setPositiveButton(R.string.go) { _, _ ->
                val id = input.text.toString().trim()
                if (id.isNotEmpty()) show(id, currentView)
            }
            .setNegativeButton(R.string.cancel, null)
            .create()
        dialog.window?.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)
        dialog.show()
    }

    /** Show [id] in Tree App [view], switching in place when the Tree Apps page is already open. */
    private fun show(id: String, view: String) {
        if (id.isBlank()) {
            currentView = view
            save()
            updateBar()
            askPerson()
            return
        }
        val v = view.ifBlank { defaultView }
        val hash = "#name=${Uri.encode(id)}&view=${Uri.encode(v)}"
        val onAppsPage = Uri.parse(web.url ?: "").let { it.host == SITE_HOST && it.path?.startsWith("/apps") == true }
        if (onAppsPage) {
            // The Tree Apps page listens for hash changes and redraws without a reload.
            web.evaluateJavascript("location.hash = ${JSONObject.quote(hash)}", null)
        } else {
            web.loadUrl("$APPS_URL${Uri.encode(id)}$hash")
        }
    }

    private fun showMenu(anchor: View) {
        val menu = PopupMenu(this, anchor)
        val m = menu.menu
        m.add(0, 1, 0, if (loggedIn) R.string.menu_logout else R.string.menu_login)
        m.add(0, 2, 1, R.string.menu_reload)
        if (currentId.isNotBlank()) m.add(0, 3, 2, R.string.menu_profile)
        m.add(0, 4, 3, R.string.menu_browser)
        m.add(0, 5, 4, if (showBars) R.string.menu_hide_bars else R.string.menu_show_bars)
        if (resources.configuration.smallestScreenWidthDp < 600) {
            m.add(0, 6, 5, R.string.menu_auto_landscape).setCheckable(true)
                .setChecked(prefs.getBoolean(KEY_AUTO_ROTATE, true))
        }
        menu.setOnMenuItemClickListener {
            when (it.itemId) {
                1 -> if (loggedIn) {
                    web.evaluateJavascript("window.__wtShellLogout && __wtShellLogout()") { refreshState() }
                } else {
                    web.evaluateJavascript("window.__wtShellLogin ? __wtShellLogin() : false") { ok ->
                        if (ok != "true") web.loadUrl(startUrl())
                    }
                }
                2 -> web.reload()
                3 -> openInSheet(Uri.parse("https://www.wikitree.com/wiki/${Uri.encode(currentId)}"))
                4 -> web.url?.let { u -> openExternally(Uri.parse(u)) }
                6 -> {
                    prefs.edit().putBoolean(KEY_AUTO_ROTATE, !prefs.getBoolean(KEY_AUTO_ROTATE, true)).apply()
                    applyOrientation()
                }
                5 -> {
                    showBars = !showBars
                    web.evaluateJavascript("window.__wtShellSetBars && __wtShellSetBars($showBars)", null)
                }
            }
            true
        }
        menu.show()
    }

    // ---- Helpers ---------------------------------------------------------------------------

    private fun startUrl(): String =
        if (currentId.isBlank()) APPS_URL
        else "$APPS_URL${Uri.encode(currentId)}#name=${Uri.encode(currentId)}&view=${Uri.encode(currentView.ifBlank { defaultView })}"

    private fun isTreeAppsUrl(uri: Uri) = uri.host == SITE_HOST && uri.path?.startsWith("/apps") == true

    /** True for a WikiTree site page that is neither a Tree App nor part of logging in. */
    private fun shouldReturnToTree(uri: Uri): Boolean {
        if (uri.host != SITE_HOST || isTreeAppsUrl(uri)) return false
        val text = uri.toString().lowercase()
        return !text.contains("login") && !text.contains("password")
    }

    private fun openInSheet(uri: Uri) {
        try {
            CustomTabsIntent.Builder()
                .setShowTitle(true)
                .setDefaultColorSchemeParams(
                    CustomTabColorSchemeParams.Builder().setToolbarColor(getColor(R.color.wt_green)).build()
                )
                .build()
                .launchUrl(this, uri)
        } catch (_: ActivityNotFoundException) {
            openExternally(uri)
        }
    }

    private fun openExternally(uri: Uri) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri))
        } catch (_: ActivityNotFoundException) {
        }
    }

    /** Android 15 draws apps edge to edge; keep the bar and page clear of the status and nav bars. */
    private fun applySystemBarInsets(root: View) {
        root.setOnApplyWindowInsetsListener { v, insets ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bars = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.ime())
                v.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            } else {
                @Suppress("DEPRECATION")
                v.setPadding(
                    insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                    insets.systemWindowInsetRight, insets.systemWindowInsetBottom,
                )
            }
            insets
        }
    }

    companion object {
        private const val SITE_HOST = "www.wikitree.com"
        private const val SITE_ORIGIN = "https://www.wikitree.com"
        private const val APPS_URL = "https://www.wikitree.com/apps/"
        private const val KEY_ID = "id"
        private const val KEY_VIEW = "view"
        private const val KEY_AUTO_ROTATE = "autoRotate"
        private const val REQ_FILE = 1

    }
}
