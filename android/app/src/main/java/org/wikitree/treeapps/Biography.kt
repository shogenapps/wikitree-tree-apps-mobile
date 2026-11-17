package org.wikitree.treeapps

import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.webkit.CookieManager
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * A WikiTree biography, read aloud: [Biography.fetch] gets a profile's biography from the API and
 * turns its wiki text into plain sentences (no markup, no sources); [BioReader] speaks them with
 * the phone's own text-to-speech voice and can pause, carry on and stop.
 */
object Biography {
    class Text(val id: String, val name: String, val paragraphs: List<String>)

    enum class Failure { PRIVATE, EMPTY, NETWORK }

    /** "Beacall-6" from a profile's address on wikitree.com, or null for any other page. */
    fun profileId(url: String?): String? {
        val uri = android.net.Uri.parse(url ?: return null)
        val host = uri.host ?: return null
        if (host != "wikitree.com" && !host.endsWith(".wikitree.com")) return null
        val path = uri.path.orEmpty()
        val id = when {
            path.startsWith("/wiki/") -> path.removePrefix("/wiki/")
            path == "/index.php" -> uri.getQueryParameter("title").orEmpty()
            else -> ""
        }.replace(' ', '_')
        return id.takeIf { PROFILE_ID.matches(it) }
    }

    private val PROFILE_ID = Regex("[^:/#?]+-\\d+")

    /** Fetch and clean a biography off the main thread; [done] runs on the main thread. */
    fun fetch(id: String, done: (Text?, Failure?) -> Unit) {
        val main = Handler(Looper.getMainLooper())
        // The member's WikiTree login, so private profiles they may see are read too.
        val cookie = CookieManager.getInstance().getCookie("https://api.wikitree.com").orEmpty()
        Thread {
            val result: Pair<Text?, Failure?> = try {
                val body = get(
                    "https://api.wikitree.com/api.php?action=getProfile&appId=TreeAppsMobile&bioFormat=wiki" +
                        "&fields=Name,FirstName,RealName,LastNameAtBirth,LastNameCurrent,BirthDate,DeathDate,BirthDecade,DeathDecade,Bio" +
                        "&key=" + URLEncoder.encode(id, "UTF-8"),
                    cookie,
                )
                val profile = body?.let { JSONArray(it).optJSONObject(0)?.optJSONObject("profile") }
                when {
                    body == null -> null to Failure.NETWORK
                    profile == null -> null to Failure.PRIVATE
                    else -> {
                        val name = PeopleStore.describe(profile)?.first ?: id
                        val wiki = profile.optString("bio").ifBlank { profile.optString("Bio") }
                        if (!profile.has("bio") && !profile.has("Bio")) null to Failure.PRIVATE
                        else clean(wiki).let { if (it.isEmpty()) null to Failure.EMPTY else Text(id, name, it) to null }
                    }
                }
            } catch (_: Exception) {
                null to Failure.NETWORK
            }
            main.post { done(result.first, result.second) }
        }.start()
    }

    private fun get(address: String, cookie: String): String? {
        val conn = URL(address).openConnection() as HttpURLConnection
        conn.connectTimeout = 10_000
        conn.readTimeout = 15_000
        if (cookie.isNotBlank()) conn.setRequestProperty("Cookie", cookie)
        return try {
            if (conn.responseCode != 200) null else conn.inputStream.bufferedReader().use { it.readText() }
        } finally {
            conn.disconnect()
        }
    }

    /** Headings where the biography proper ends: what follows is sources and notes about them. */
    private val END_HEADING = Regex(
        "^\\s*=+\\s*(sources?|references?|research notes?|acknowledge?ments?|footnotes?|citations?|bibliography)\\s*:?\\s*=+\\s*$",
        setOf(RegexOption.IGNORE_CASE, RegexOption.MULTILINE),
    )

    /**
     * Wiki text to paragraphs of plain sentences: everything from the Sources heading (or the
     * references tag) on is dropped, and so are footnotes, templates, tables, pictures,
     * categories and tags; links keep only their words.
     */
    fun clean(wiki: String): List<String> {
        var t = wiki.replace("\r\n", "\n")
        t = t.replace(Regex("<!--.*?-->", RegexOption.DOT_MATCHES_ALL), "")
        END_HEADING.find(t)?.let { t = t.substring(0, it.range.first) }
        Regex("<references\\s*/?>", RegexOption.IGNORE_CASE).find(t)?.let { t = t.substring(0, it.range.first) }
        t = t.replace(Regex("<ref\\b[^>]*/>", RegexOption.IGNORE_CASE), "")
        t = t.replace(Regex("<ref\\b[^>]*>.*?</ref\\s*>", setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL)), "")
        // Templates (stickers, research boxes), innermost first so nested ones go too.
        val template = Regex("\\{\\{[^{}]*\\}\\}")
        while (template.containsMatchIn(t)) t = t.replace(template, "")
        val table = Regex("\\{\\|[^{}]*?\\|\\}", RegexOption.DOT_MATCHES_ALL)
        while (table.containsMatchIn(t)) t = t.replace(table, "")
        // Pictures and categories, whose captions can themselves hold links.
        val media = Regex("\\[\\[\\s*:?\\s*(file|image|category|media)\\s*:([^\\[\\]]|\\[\\[[^\\[\\]]*\\]\\])*\\]\\]", RegexOption.IGNORE_CASE)
        t = t.replace(media, "")
        t = t.replace(Regex("\\[\\[[^\\[\\]|]*\\|([^\\[\\]]*)\\]\\]")) { it.groupValues[1] }
        // A plain link reads as its page name, without a "Space:" style prefix or underscores.
        t = t.replace(Regex("\\[\\[\\s*:?([^\\[\\]]*)\\]\\]")) {
            it.groupValues[1].substringAfter(':').replace('_', ' ').trim('#', ' ')
        }
        t = t.replace(Regex("\\[(https?:)?//[^\\s\\]]+\\s+([^\\]]*)\\]")) { it.groupValues[2] }
        t = t.replace(Regex("\\[(https?:)?//[^\\]]*\\]"), "")
        // Bare addresses, with the brackets around them; an address ends before closing punctuation.
        t = t.replace(Regex("\\(\\s*https?://[^\\s()]*(\\([^\\s()]*\\)[^\\s()]*)*\\s*\\)"), "")
        t = t.replace(Regex("https?://[^\\s\\]]*[^\\s\\]).,;:!?'\"]"), "")
        t = t.replace(Regex("\\(\\s*[.,;:]?\\s*\\)"), "")
        // The note a GEDCOM import leaves, and hand-made footnote marks like [1].
        t = t.replace(Regex("^\\s*This person was created (through|by) the import of .*$", setOf(RegexOption.IGNORE_CASE, RegexOption.MULTILINE)), "")
        t = t.replace(Regex("\\[\\d+\\]"), "")
        t = t.replace(Regex("<br\\s*/?>", RegexOption.IGNORE_CASE), "\n")
        t = t.replace(Regex("</?(p|div|li|ul|ol|blockquote|h\\d)\\b[^>]*>", RegexOption.IGNORE_CASE), "\n\n")
        t = t.replace(Regex("<[^>]+>"), "")
        t = t.replace(Regex("'{2,}"), "")
        t = t.replace(Regex("__[A-Z]+__"), "")
        t = t.replace(Regex("^-{4,}\\s*$", RegexOption.MULTILINE), "")
        t = decodeEntities(t)
        val paragraphs = mutableListOf<String>()
        var current = StringBuilder()
        fun flush() {
            val p = current.toString().replace(Regex("\\s+"), " ").replace(Regex("\\s+([,.;:!?])"), "$1").trim()
            if (p.isNotEmpty() && p.any { it.isLetterOrDigit() }) paragraphs += p
            current = StringBuilder()
        }
        for (raw in t.split('\n')) {
            val line = raw.trim()
            val heading = Regex("^=+\\s*(.*?)\\s*=+$").find(line)
            when {
                line.isEmpty() -> flush()
                heading != null -> {
                    flush()
                    val words = heading.groupValues[1].trim()
                    // "Biography" itself says nothing; other headings are read as a short line.
                    if (words.isNotEmpty() && !words.equals("biography", true)) {
                        current.append(if (words.last() in ".!?:") words else "$words.")
                        flush()
                    }
                }
                Regex("^[*#:;]+").containsMatchIn(line) -> {
                    // List items are read one by one.
                    flush()
                    current.append(line.replace(Regex("^[*#:;]+\\s*"), ""))
                    flush()
                }
                else -> current.append(' ').append(line)
            }
        }
        flush()
        return paragraphs
    }

    private fun decodeEntities(s: String): String {
        var t = s
        listOf("&nbsp;" to " ", "&ndash;" to "–", "&mdash;" to "—", "&quot;" to "\"", "&apos;" to "'", "&#39;" to "'",
            "&lsquo;" to "‘", "&rsquo;" to "’", "&ldquo;" to "“", "&rdquo;" to "”", "&hellip;" to "…",
            "&pound;" to "£", "&euro;" to "€", "&cent;" to "¢", "&copy;" to "©", "&deg;" to "°",
            "&frac12;" to "½", "&frac14;" to "¼", "&frac34;" to "¾",
            "&lt;" to "<", "&gt;" to ">", "&amp;" to "&").forEach { (a, b) -> t = t.replace(a, b, ignoreCase = true) }
        t = t.replace(Regex("&#([xX]?)([0-9a-fA-F]+);")) { m ->
            m.groupValues[2].toIntOrNull(if (m.groupValues[1].isEmpty()) 10 else 16)
                ?.takeIf { Character.isValidCodePoint(it) }?.let { String(Character.toChars(it)) } ?: ""
        }
        // Any other named entity says nothing; a no-break space is an ordinary space.
        return t.replace(Regex("&[a-zA-Z]+;"), "").replace('\u00A0', ' ')
    }

    /** Pieces short enough for the voice, each a sentence or a few, so a pause can carry on close by. */
    fun chunks(paragraphs: List<String>, max: Int = 350): List<Pair<String, Boolean>> {
        val out = mutableListOf<Pair<String, Boolean>>()
        for (p in paragraphs) {
            val sentences = p.split(Regex("(?<=[.!?])\\s+(?=[\\p{Lu}\\d\"“(])"))
            val buf = StringBuilder()
            fun push(end: Boolean) {
                if (buf.isNotEmpty()) out += buf.toString() to end
                buf.clear()
            }
            for (s in sentences) {
                // A very long sentence is cut at a comma or space.
                var rest = s
                while (rest.length > max) {
                    val cut = rest.lastIndexOf(", ", max).takeIf { it > max / 2 }?.plus(1)
                        ?: rest.lastIndexOf(' ', max).takeIf { it > 0 } ?: max
                    push(false)
                    buf.append(rest.substring(0, cut).trim())
                    push(false)
                    rest = rest.substring(cut).trim()
                }
                if (buf.isNotEmpty() && buf.length + rest.length + 1 > max / 2) push(false)
                if (buf.isNotEmpty()) buf.append(' ')
                buf.append(rest)
            }
            push(true)
        }
        return out
    }
}

/**
 * Speaks a [Biography.Text] with the phone's text-to-speech. Android's voice cannot pause, so
 * [pause] stops after noting the piece being read, and [resume] starts again from that piece.
 */
class BioReader(context: Context, private val onState: (State) -> Unit) {
    enum class State { STARTING, READING, PAUSED, DONE, NO_VOICE }

    private val main = Handler(Looper.getMainLooper())
    private var ready = false
    private var failed = false
    private var pieces: List<Pair<String, Boolean>> = emptyList()
    private var at = 0
    private var wanted = false
    private var generation = 0
    var state = State.DONE
        private set

    private val tts: TextToSpeech = TextToSpeech(context.applicationContext) { status ->
        main.post {
            if (status == TextToSpeech.SUCCESS) {
                ready = true
                if (wanted) speakFrom(at)
            } else {
                failed = true
                if (wanted) set(State.NO_VOICE)
            }
        }
    }.apply {
        setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String) {
                val (gen, index) = parse(id) ?: return
                main.post { if (gen == generation) at = index }
            }

            override fun onDone(id: String) {
                val (gen, index) = parse(id) ?: return
                main.post {
                    if (gen == generation && index == pieces.lastIndex && state == State.READING) {
                        at = 0
                        wanted = false
                        set(State.DONE)
                    }
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(id: String) {
                main.post { if (state == State.READING) set(State.NO_VOICE) }
            }
        })
    }

    private fun parse(id: String): Pair<Int, Int>? =
        id.split(':').takeIf { it.size == 2 }?.let { (g, i) -> g.toIntOrNull()?.let { a -> i.toIntOrNull()?.let { b -> a to b } } }

    /** Read [text] from the start, with the person's name first. */
    fun read(text: Biography.Text) {
        pieces = Biography.chunks(listOf("${text.name}.") + text.paragraphs)
        at = 0
        wanted = true
        if (failed) set(State.NO_VOICE) else if (ready) speakFrom(0) else set(State.STARTING)
    }

    fun pause() {
        if (state != State.READING) return
        generation++
        tts.stop()
        set(State.PAUSED)
    }

    fun resume() {
        if (state == State.PAUSED) speakFrom(at)
    }

    fun stop() {
        wanted = false
        generation++
        if (ready) tts.stop()
        at = 0
        set(State.DONE)
    }

    /** Stop and let the voice go; call when the screen it belongs to closes. */
    fun release() {
        stop()
        tts.shutdown()
    }

    private fun speakFrom(index: Int) {
        if (pieces.isEmpty()) return
        generation++
        val gen = generation
        tts.stop()
        for (i in index..pieces.lastIndex) {
            val (text, endOfParagraph) = pieces[i]
            tts.speak(text, TextToSpeech.QUEUE_ADD, Bundle(), "$gen:$i")
            if (endOfParagraph && i < pieces.lastIndex) tts.playSilentUtterance(450, TextToSpeech.QUEUE_ADD, "$gen:pause")
        }
        set(State.READING)
    }

    private fun set(s: State) {
        state = s
        onState(s)
    }
}

/**
 * The bar at the bottom of a profile while its biography is read: who is being read, Pause or
 * Carry on, and Stop. Hidden until [start]; a biography that cannot be read says why here.
 */
class BioPlayer(private val activity: android.app.Activity) {
    private val density = activity.resources.displayMetrics.density
    private fun dp(v: Int) = (v * density).toInt()

    private val status = android.widget.TextView(activity).apply {
        setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 15f)
        setTextColor(activity.getColor(R.color.text_primary))
        maxLines = 2
        ellipsize = android.text.TextUtils.TruncateAt.END
        gravity = android.view.Gravity.CENTER_VERTICAL
        setPadding(dp(16), dp(8), dp(8), dp(8))
    }
    private val pauseButton = button(activity.getString(R.string.bio_pause)) { toggle() }
    private val stopButton = button(activity.getString(R.string.bio_stop)) { stop() }

    val view: android.widget.LinearLayout = android.widget.LinearLayout(activity).apply {
        orientation = android.widget.LinearLayout.VERTICAL
        setBackgroundColor(activity.getColor(R.color.sheet_bg))
        visibility = android.view.View.GONE
        addView(android.view.View(activity).apply {
            setBackgroundColor(activity.getColor(R.color.text_secondary))
            alpha = 0.3f
        }, android.widget.LinearLayout.LayoutParams(android.view.ViewGroup.LayoutParams.MATCH_PARENT, dp(1)))
        addView(android.widget.LinearLayout(activity).apply {
            orientation = android.widget.LinearLayout.HORIZONTAL
            gravity = android.view.Gravity.CENTER_VERTICAL
            minimumHeight = dp(56)
            addView(status, android.widget.LinearLayout.LayoutParams(0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            addView(pauseButton)
            addView(stopButton)
        })
    }

    private var reader: BioReader? = null
    private var text: Biography.Text? = null
    private var request = 0

    // Leaving the app (Home, another app, the screen going off) stops the reading, as on iPhone.
    private val lifecycle = object : android.app.Application.ActivityLifecycleCallbacks {
        override fun onActivityStopped(a: android.app.Activity) {
            if (a === activity && !a.isChangingConfigurations) stop()
        }
        override fun onActivityCreated(a: android.app.Activity, state: Bundle?) {}
        override fun onActivityStarted(a: android.app.Activity) {}
        override fun onActivityResumed(a: android.app.Activity) {}
        override fun onActivityPaused(a: android.app.Activity) {}
        override fun onActivitySaveInstanceState(a: android.app.Activity, state: Bundle) {}
        override fun onActivityDestroyed(a: android.app.Activity) {}
    }.also { activity.application.registerActivityLifecycleCallbacks(it) }

    /** Fetch the biography of [id] and read it. */
    fun start(id: String) {
        reader?.stop()
        val mine = ++request
        text = null
        show(activity.getString(R.string.bio_fetching), pause = false)
        Biography.fetch(id) { bio, failure ->
            if (mine != request) return@fetch
            if (bio == null) {
                show(activity.getString(when (failure) {
                    Biography.Failure.PRIVATE -> R.string.bio_private
                    Biography.Failure.EMPTY -> R.string.bio_empty
                    else -> R.string.bio_failed
                }), pause = false, close = true)
                return@fetch
            }
            text = bio
            val r = reader ?: BioReader(activity) { onState(it) }.also { reader = it }
            r.read(bio)
        }
    }

    private fun onState(state: BioReader.State) {
        val name = text?.name ?: ""
        when (state) {
            BioReader.State.STARTING -> show(activity.getString(R.string.bio_reading, name), pause = false)
            BioReader.State.READING -> show(activity.getString(R.string.bio_reading, name), pause = true)
            BioReader.State.PAUSED -> show(activity.getString(R.string.bio_paused, name), pause = true, paused = true)
            BioReader.State.NO_VOICE -> show(activity.getString(R.string.bio_no_voice), pause = false, close = true)
            BioReader.State.DONE -> view.visibility = android.view.View.GONE
        }
    }

    private fun toggle() {
        val r = reader ?: return
        if (r.state == BioReader.State.PAUSED) r.resume() else r.pause()
    }

    fun stop() {
        request++
        reader?.stop()
        view.visibility = android.view.View.GONE
    }

    /** Stop and let the voice go, when the profile closes. */
    fun release() {
        activity.application.unregisterActivityLifecycleCallbacks(lifecycle)
        request++
        reader?.release()
        reader = null
    }

    private fun show(message: String, pause: Boolean, paused: Boolean = false, close: Boolean = false) {
        status.text = message
        pauseButton.visibility = if (pause) android.view.View.VISIBLE else android.view.View.GONE
        pauseButton.text = activity.getString(if (paused) R.string.bio_resume else R.string.bio_pause)
        stopButton.text = activity.getString(if (close) R.string.bio_close else R.string.bio_stop)
        view.visibility = android.view.View.VISIBLE
    }

    private fun button(text: String, onClick: () -> Unit) = android.widget.TextView(activity).apply {
        this.text = text
        setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 15f)
        setTypeface(typeface, android.graphics.Typeface.BOLD)
        setTextColor(activity.getColor(R.color.wt_accent))
        gravity = android.view.Gravity.CENTER
        minHeight = dp(48)
        minWidth = dp(64)
        setPadding(dp(12), 0, dp(12), 0)
        val ripple = android.util.TypedValue()
        activity.theme.resolveAttribute(android.R.attr.selectableItemBackground, ripple, true)
        setBackgroundResource(ripple.resourceId)
        setOnClickListener { onClick() }
    }
}
