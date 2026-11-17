package org.wikitree.treeapps

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Calendar

/** One person from the watchlist. [birth] and [death] are "YYYY-MM-DD" as WikiTree gives them, or "". */
data class Relative(
    val id: String, val name: String, val birth: String, val dates: String,
    /** When WikiTree last changed the profile, to spot what needs fetching again. */
    val touched: String = "",
    /** Birthplace, shown with name suggestions. */
    val place: String = "",
    val death: String = "",
) {
    val birthYear: Int get() = birth.take(4).toIntOrNull() ?: 0
    val deathYear: Int get() = death.take(4).toIntOrNull() ?: 0
}

/** A birth or a death on the watchlist that falls on a given day of the year. */
data class Anniversary(val person: Relative, val isBirth: Boolean, val year: Int) {
    /** Whole years since, counted from [today]'s year. */
    fun years(today: Calendar = Calendar.getInstance()): Int = today.get(Calendar.YEAR) - year

    /** A round number of years (every 25th), worth picking out. */
    fun isMilestone(today: Calendar = Calendar.getInstance()): Boolean = years(today).let { it > 0 && it % 25 == 0 }
}

/**
 * The logged-in member's WikiTree watchlist, kept in a file on the phone only. It feeds the
 * Anniversaries list, widget and notification, and the name suggestions while typing.
 *
 * It is fetched with the WikiTree login already in the web view (its cookies), a page at a time,
 * and refreshed once a week or by hand; a refresh fetches only the people who have changed.
 */
class WatchlistStore(context: Context) {
    private val app = context.applicationContext
    private val prefs = app.getSharedPreferences("watchlist", Context.MODE_PRIVATE)
    private val file = File(app.filesDir, "watchlist.tsv")
    private val main = Handler(Looper.getMainLooper())

    enum class Result { OK, LOGGED_OUT, FAILED }

    /** When the list was last fetched (ms), or 0 if never. */
    val fetchedAt: Long get() = prefs.getLong(KEY_AT, 0L)
    val count: Int get() = prefs.getInt(KEY_COUNT, 0)
    val isStale: Boolean get() = isOldFormat || System.currentTimeMillis() - fetchedAt > WEEK

    /** A list stored before death dates were kept; it is fetched again in full. */
    private val isOldFormat: Boolean get() = fetchedAt != 0L && prefs.getInt(KEY_FORMAT, 1) < FORMAT

    var notify: Boolean
        get() = prefs.getBoolean(KEY_NOTIFY, false)
        set(value) = prefs.edit().putBoolean(KEY_NOTIFY, value).apply()

    fun all(): List<Relative> = cached ?: read().also { cached = it }

    /** Births and deaths on [day] (default today), oldest first, a birth before a death in the same year. */
    fun anniversaries(day: Calendar = Calendar.getInstance()): List<Anniversary> {
        val monthDay = "-%02d-%02d".format(day.get(Calendar.MONTH) + 1, day.get(Calendar.DAY_OF_MONTH))
        fun on(date: String) = date.length == 10 && date.endsWith(monthDay)
        val found = ArrayList<Anniversary>()
        for (p in all()) {
            if (on(p.birth) && p.birthYear > 0) found.add(Anniversary(p, true, p.birthYear))
            if (on(p.death) && p.deathYear > 0) found.add(Anniversary(p, false, p.deathYear))
        }
        return found.sortedWith(compareBy({ it.year }, { if (it.isBirth) 0 else 1 }))
    }

    /** People with a name word starting with every word typed, e.g. "geo bea" finds George Beacall. */
    fun suggest(text: String, limit: Int = 6): List<Relative> {
        val typed = text.lowercase().split(Regex("[\\s()]+")).filter { it.isNotBlank() }
        if (typed.isEmpty()) return emptyList()
        return all().asSequence().filter { person ->
            val words = person.name.lowercase().split(Regex("[\\s()]+"))
            typed.all { t -> words.any { it.startsWith(t) } }
        }.take(limit).toList()
    }

    /** Fetch the whole watchlist again. [done] runs on the main thread. */
    fun refresh(done: (Result) -> Unit = {}) {
        if (refreshing) return
        refreshing = true
        // The WikiTree login lives in the web view's cookies for the site, which also serves the API.
        val cookie = CookieManager.getInstance().getCookie(API)
        Thread {
            val result = try {
                if (cookie.isNullOrBlank()) Result.LOGGED_OUT else fetchAll(cookie)
            } catch (_: Exception) {
                Result.FAILED
            }
            main.post {
                refreshing = false
                done(result)
            }
        }.start()
    }


    /**
     * Bring the stored list up to date. First only IDs and last-changed times are fetched, a few
     * thousand at a time; then details for just the people who are new or have changed. The first
     * time, or when a great many have changed, the whole list is fetched with details instead.
     */
    private fun fetchAll(cookie: String): Result {
        val stored = all().associateBy { it.id }
        val index = LinkedHashMap<String, String>() // id to last-changed time, in watchlist order
        var offset = 0
        while (offset < MAX_PEOPLE) {
            val page = watchlistPage(cookie, "Name,Touched", INDEX_PAGE, offset) ?: return Result.FAILED
            if (page.loggedOut) return Result.LOGGED_OUT
            for (p in page.people) {
                val id = p.optString("Name").ifBlank { continue }
                index[id] = p.optString("Touched")
            }
            if (page.people.size < INDEX_PAGE) break
            offset += INDEX_PAGE
            Thread.sleep(PAUSE) // the API limits how fast it may be called
        }
        // A list stored before death dates were kept is fetched again in full.
        val changed = if (isOldFormat) index.keys.toList() else index.filter { (id, touched) -> stored[id]?.touched != touched || touched.isEmpty() }.keys.toList()
        val fresh = HashMap<String, Relative>()
        if (changed.size > MAX_CHANGED) {
            offset = 0
            while (offset < MAX_PEOPLE) {
                Thread.sleep(PAUSE)
                val page = watchlistPage(cookie, FIELDS, PAGE, offset) ?: return Result.FAILED
                if (page.loggedOut) return Result.LOGGED_OUT
                page.people.mapNotNull(::relative).forEach { fresh[it.id] = it }
                if (page.people.size < PAGE) break
                offset += PAGE
            }
        } else {
            for (ids in changed.chunked(KEYS)) {
                Thread.sleep(PAUSE)
                val text = get("$API?action=getPeople&appId=TreeAppsMobile&fields=$FIELDS&keys=" +
                    URLEncoder.encode(ids.joinToString(","), "UTF-8"), cookie) ?: return Result.FAILED
                val people = JSONArray(text).optJSONObject(0)?.optJSONObject("people") ?: return Result.FAILED
                for (key in people.keys()) {
                    people.optJSONObject(key)?.let(::relative)?.let { fresh[it.id] = it }
                }
            }
        }
        // People no longer on the watchlist drop out; unchanged ones keep what was stored.
        val list = index.keys.mapNotNull { fresh[it] ?: stored[it] }
        val text = StringBuilder()
        for (r in list) {
            text.append(listOf(r.id, r.name, r.birth, r.dates, r.touched, r.place, r.death)
                .joinToString("\t") { it.replace('\t', ' ').replace('\n', ' ') }).append('\n')
        }
        file.writeText(text.toString())
        cached = null
        prefs.edit().putLong(KEY_AT, System.currentTimeMillis()).putInt(KEY_COUNT, list.size)
            .putInt(KEY_FORMAT, FORMAT).apply()
        return Result.OK
    }

    private class Page(val people: List<JSONObject>, val loggedOut: Boolean)

    /** One page of the watchlist, or null if the call failed. */
    private fun watchlistPage(cookie: String, fields: String, limit: Int, offset: Int): Page? {
        val text = get("$API?action=getWatchlist&appId=TreeAppsMobile&getPerson=1&getSpace=0" +
            "&fields=$fields&limit=$limit&offset=$offset", cookie) ?: return null
        val json = JSONArray(text).optJSONObject(0) ?: return null
        // Without a login the API answers with a status and no list, or with an empty list and
        // a count of false rather than a number.
        val list = json.optJSONArray("watchlist") ?: return if (offset == 0) Page(emptyList(), true) else null
        if (offset == 0 && list.length() == 0 && json.opt("watchlistCount") == false) return Page(emptyList(), true)
        return Page((0 until list.length()).mapNotNull { list.optJSONObject(it) }, false)
    }

    private fun relative(p: JSONObject): Relative? {
        val id = p.optString("Name").ifBlank { return null }
        val (name, dates) = PeopleStore.describe(p) ?: return null
        val birth = p.optString("BirthDate").takeIf { it.length == 10 } ?: ""
        val death = p.optString("DeathDate").takeIf { it.length == 10 } ?: ""
        return Relative(id, name, birth, dates, p.optString("Touched"), p.optString("BirthLocation"), death)
    }

    private fun get(address: String, cookie: String): String? {
        val conn = URL(address).openConnection() as HttpURLConnection
        conn.connectTimeout = 15_000
        conn.readTimeout = 30_000
        conn.setRequestProperty("Cookie", cookie)
        return try {
            if (conn.responseCode != 200) null else conn.inputStream.bufferedReader().use { it.readText() }
        } finally {
            conn.disconnect()
        }
    }

    private fun read(): List<Relative> = try {
        file.useLines { lines ->
            lines.mapNotNull { line ->
                val parts = line.split('\t')
                if (parts.size < 4 || parts[0].isBlank()) null
                else Relative(parts[0], parts[1], parts[2], parts[3], parts.getOrElse(4) { "" }, parts.getOrElse(5) { "" },
                    parts.getOrElse(6) { "" })
            }.toList()
        }
    } catch (_: Exception) {
        emptyList()
    }

    /** Forget the list, e.g. after logging out. */
    fun clear() {
        file.delete()
        cached = null
        prefs.edit().remove(KEY_AT).remove(KEY_COUNT).apply()
    }

    companion object {
        private const val API = "https://www.wikitree.com/api.php"
        private const val KEY_AT = "fetchedAt"
        private const val KEY_COUNT = "count"
        private const val KEY_NOTIFY = "notify"
        private const val KEY_FORMAT = "format"
        /** The file's layout. Version 2 added death dates. */
        private const val FORMAT = 2
        private const val WEEK = 7L * 24 * 60 * 60 * 1000
        private const val FIELDS = "Name,Touched,FirstName,RealName,LastNameAtBirth,LastNameCurrent,BirthDate,DeathDate,BirthLocation"
        private const val INDEX_PAGE = 5000
        private const val PAGE = 2000
        /** How many people one getPeople call is asked for. */
        private const val KEYS = 100
        /** With more changes than this, fetching the whole list again is quicker. */
        private const val MAX_CHANGED = 500
        private const val MAX_PEOPLE = 20_000
        private const val PAUSE = 1_500L

        // Shared by every instance in the process (the app, the widget and the notification).
        @Volatile private var cached: List<Relative>? = null
        @Volatile private var refreshing = false
    }
}
