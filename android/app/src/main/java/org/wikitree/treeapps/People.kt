package org.wikitree.treeapps

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLDecoder
import java.net.URLEncoder

/**
 * One person in the saved or recent list. [view] is the Tree App they were last shown in.
 * [notable] is set on search matches only and is not stored.
 */
data class Person(
    val id: String,
    val name: String,
    val dates: String,
    val view: String,
    val time: Long,
    val notable: Notable? = null,
)

/**
 * A notable person: a "... Notables" category, a Notables Sticker or a Notability template.
 * [tag] is a short line such as "Shropshire Notables" or "Entertainment · California"; [about] is
 * the Notability template's text, if it has one. [rank] orders search matches: 2 with a
 * Notability template or a Notables category, 1 with a sticker only. Mirrors Notable in People.swift.
 */
data class Notable(val tag: String, val about: String, val rank: Int) {
    companion object {
        /**
         * Read from a searchPerson match fetched with Categories and Templates. A template's params
         * come back as an object, or as an empty array when it has none.
         */
        fun from(p: JSONObject): Notable? {
            val cats = p.optJSONArray("Categories")
            val categories = (0 until (cats?.length() ?: 0))
                .map { cats!!.optString(it).replace('_', ' ') }
                .filter { it.endsWith(" Notables") || it == "Notables" }
            val templates = p.optJSONArray("Templates")
            fun params(name: String): Map<String, String>? {
                for (i in 0 until (templates?.length() ?: 0)) {
                    val t = templates!!.optJSONObject(i) ?: continue
                    if (!t.optString("name").equals(name, true)) continue
                    val obj = t.optJSONObject("params") ?: return emptyMap()
                    return obj.keys().asSequence().associateWith { obj.optString(it) }
                }
                return null
            }
            val notability = params("Notability")
            val sticker = params("Notables Sticker") ?: params("Notables")
            if (categories.isEmpty() && notability == null && sticker == null) return null
            val about = plain(notability?.get("text").orEmpty())
            val theme = listOfNotNull(notability?.get("theme"), notability?.get("location")).map(::plain).filter { it.isNotBlank() }
            // The sticker's first unnamed param is the category it shows, e.g. "England, Notables".
            val stickerTag = sticker?.entries?.firstOrNull { it.value.isEmpty() && it.key.endsWith("Notables") }?.key
            // Local categories ("Shropshire Notables") say more than country ones ("England, Notables",
            // with a comma), so they go first.
            val named = (categories + listOfNotNull(stickerTag)).distinct()
                .sortedWith(compareBy<String> { it.contains(',') }.thenBy { it })
                .map { it.replace(",", "") }
            val tag = when {
                theme.isNotEmpty() -> theme.joinToString(" · ")
                named.isEmpty() -> "" // shown as R.string.notable
                else -> named.take(2).joinToString(", ")
            }
            return Notable(tag, about, if (notability != null || categories.isNotEmpty()) 2 else 1)
        }

        /** Wiki text to plain text: links keep their label, bold/italic quotes and templates go. */
        fun plain(wiki: String): String {
            var s = wiki
            listOf(
                "\\[\\[[^\\]|]*\\|([^\\]]*)\\]\\]" to "$1", "\\[\\[([^\\]]*)\\]\\]" to "$1",
                "\\[https?://\\S+ ([^\\]]*)\\]" to "$1", "\\{\\{[^}]*\\}\\}" to "",
                "<[^>]+>" to "", "'{2,}" to "", "\\s+" to " ",
            ).forEach { (pattern, with) -> s = s.replace(Regex(pattern), with) }
            listOf(
                "&quot;" to "\"", "&#34;" to "\"", "&#39;" to "'", "&apos;" to "'",
                "&lt;" to "<", "&gt;" to ">", "&nbsp;" to " ", "&amp;" to "&",
            ).forEach { (entity, char) -> s = s.replace(entity, char) }
            return s.trim()
        }
    }
}

/**
 * Saved (starred) and recently viewed people, kept on the phone only.
 * Names and dates come from the public WikiTree API, looked up once per person and cached.
 */
class PeopleStore(context: Context) {
    private val prefs = context.getSharedPreferences("people", Context.MODE_PRIVATE)
    private val main = Handler(Looper.getMainLooper())
    private val looking = mutableSetOf<String>()

    /** Called on the main thread whenever the lists change (e.g. a name arrives). */
    var onChange: (() -> Unit)? = null

    fun saved(): List<Person> = read(KEY_SAVED)
    fun recent(): List<Person> = read(KEY_RECENT)
    fun isSaved(id: String) = saved().any { it.id.equals(id, true) }

    /**
     * The member logged in to WikiTree in the app, from its cookies (shared with the web view): the
     * ID from the Tree Apps login (WikiTreeAPI_userName) or the site's remember-me cookie, with a
     * site session (wikitree_wtb__session) beside it; null otherwise. With no site session,
     * profiles would show logged out, so the start screen offers to log in instead.
     * Their name is looked up like anyone else's.
     */
    fun me(): Person? {
        val cookies = try {
            CookieManager.getInstance().getCookie("https://www.wikitree.com")
        } catch (_: Exception) {
            null
        } ?: return null
        val pairs = cookies.split(';').map { it.trim() }.filter { it.substringAfter('=', "").isNotEmpty() }
        if (pairs.none { it.substringBefore('=').let { n -> n.endsWith("wtb__session") || n.endsWith("wtb_UserName") } }) return null
        val id = pairs
            .firstOrNull { it.substringBefore('=').let { n -> n == "WikiTreeAPI_userName" || n.endsWith("wtb_UserName") } }
            ?.substringAfter('=')
            ?.let { URLDecoder.decode(it, "UTF-8").replace(' ', '_') }
            ?.takeIf { Regex("\\S+-\\d+").matches(it) } ?: return null
        lookUp(id)
        return Person(id, cachedName(id), cachedDates(id), "", 0)
    }

    /** Note that [id] was shown in [view]. Returns true when the order of the recent list changed. */
    fun visit(id: String, view: String): Boolean {
        if (id.isBlank()) return false
        val list = recent().toMutableList()
        val old = list.firstOrNull { it.id.equals(id, true) }
        val moved = list.indexOf(old) != 0
        if (!moved && old?.view == view) return false
        list.remove(old)
        list.add(0, Person(id, old?.name ?: cachedName(id), old?.dates ?: cachedDates(id), view, System.currentTimeMillis()))
        write(KEY_RECENT, list.take(MAX_RECENT))
        // Keep a saved person's last app current too, so tapping them reopens where they were.
        val saved = saved()
        if (saved.any { it.id.equals(id, true) }) {
            write(KEY_SAVED, saved.map { if (it.id.equals(id, true)) it.copy(view = view) else it })
        }
        lookUp(id)
        return moved || old == null
    }

    fun toggleSaved(id: String, view: String): Boolean {
        val list = saved().toMutableList()
        val existing = list.firstOrNull { it.id.equals(id, true) }
        if (existing != null) list.remove(existing)
        else list.add(0, Person(id, cachedName(id), cachedDates(id), view, System.currentTimeMillis()))
        write(KEY_SAVED, list)
        lookUp(id)
        onChange?.invoke()
        return existing == null
    }

    fun removeSaved(id: String) {
        write(KEY_SAVED, saved().filterNot { it.id.equals(id, true) })
        onChange?.invoke()
    }

    fun removeRecent(id: String) {
        write(KEY_RECENT, recent().filterNot { it.id.equals(id, true) })
        onChange?.invoke()
    }

    fun clearRecent() {
        write(KEY_RECENT, emptyList())
        onChange?.invoke()
    }

    // ---- Names from the WikiTree API -----------------------------------------------------------

    private fun cachedName(id: String) = prefs.getString("name_$id", "") ?: ""
    private fun cachedDates(id: String) = prefs.getString("dates_$id", "") ?: ""

    /** Fetch the person's name and years once, off the main thread. Private profiles may not say. */
    private fun lookUp(id: String) {
        if (prefs.contains("name_$id") || !looking.add(id)) return
        Thread {
            val result = try {
                fetch(id)
            } catch (_: Exception) {
                null
            }
            main.post {
                looking.remove(id)
                if (result == null) return@post
                prefs.edit().putString("name_$id", result.first).putString("dates_$id", result.second).apply()
                for (key in listOf(KEY_SAVED, KEY_RECENT)) {
                    write(key, read(key).map {
                        if (it.id.equals(id, true)) it.copy(name = result.first, dates = result.second) else it
                    })
                }
                onChange?.invoke()
            }
        }.start()
    }

    /**
     * Search WikiTree by name, with birth and death years and places if given (see [NameSearch]):
     * the last word of the name is the last name, anything before it the first name.
     * [done] gets the people (their dates include the birthplace) and the total number of matches,
     * or null if the search failed. Notable people among the first [SEARCH_FETCH] matches come
     * first, then up to [SEARCH_LIMIT] others, each in WikiTree's order. Categories and Templates
     * come in the same call to tell notables apart.
     */
    fun search(text: String, done: (List<Person>?, Int) -> Unit) {
        val query = NameSearch.parse(text)
        val last = query.last
        val first = query.first
        Thread {
            val result = try {
                val json = get(
                    "https://api.wikitree.com/api.php?action=searchPerson&appId=TreeAppsMobile" +
                        "&fields=Name,FirstName,RealName,LastNameAtBirth,LastNameCurrent,BirthDate,DeathDate,BirthLocation,Categories,Templates" +
                        "&limit=$SEARCH_FETCH&LastName=" + URLEncoder.encode(last, "UTF-8") +
                        "&FirstName=" + URLEncoder.encode(first, "UTF-8") + query.queryString,
                )?.let { JSONArray(it).optJSONObject(0) }
                val found = json?.optJSONArray("matches")
                if (json == null) null
                else (0 until (found?.length() ?: 0)).mapNotNull { i ->
                    val p = found?.optJSONObject(i) ?: return@mapNotNull null
                    val id = p.optString("Name").ifBlank { return@mapNotNull null }
                    val (name, dates) = describe(p) ?: return@mapNotNull null
                    val detail = listOf(dates, p.optString("BirthLocation")).filter { it.isNotBlank() }.joinToString("  ·  ")
                    Person(id, name, detail, "", 0, Notable.from(p))
                }.let { list ->
                    list.filter { it.notable != null }.sortedByDescending { it.notable!!.rank } +
                        list.filter { it.notable == null }.take(SEARCH_LIMIT)
                } to json.optInt("total")
            } catch (_: Exception) {
                null
            }
            main.post { done(result?.first, result?.second ?: 0) }
        }.start()
    }

    private fun fetch(id: String): Pair<String, String>? {
        val url = URL(
            "https://api.wikitree.com/api.php?action=getProfile&appId=TreeAppsMobile" +
                "&fields=Name,FirstName,RealName,LastNameAtBirth,LastNameCurrent,BirthDate,DeathDate,BirthDecade,DeathDecade" +
                "&key=" + URLEncoder.encode(id, "UTF-8"),
        )
        val text = get(url.toString()) ?: return null
        val profile = JSONArray(text).optJSONObject(0)?.optJSONObject("profile") ?: return null
        return describe(profile)
    }

    private fun get(address: String): String? {
        val conn = URL(address).openConnection() as HttpURLConnection
        conn.connectTimeout = 10_000
        conn.readTimeout = 10_000
        return try {
            if (conn.responseCode != 200) null else conn.inputStream.bufferedReader().use { it.readText() }
        } finally {
            conn.disconnect()
        }
    }

    companion object {
        const val SEARCH_LIMIT = 10
        /** Matches fetched per search: notables among them are all shown, the rest only up to [SEARCH_LIMIT]. */
        const val SEARCH_FETCH = 50
        private const val KEY_SAVED = "saved"
        private const val KEY_RECENT = "recent"
        private const val MAX_RECENT = 25

        /** "Donald Cameron" and "1841–1878" from a getProfile result. */
        fun describe(p: JSONObject): Pair<String, String>? {
            val first = p.optString("RealName").ifBlank { p.optString("FirstName") }
            val birthName = p.optString("LastNameAtBirth")
            val current = p.optString("LastNameCurrent")
            val last = if (current.isNotBlank() && current != birthName && birthName.isNotBlank()) "($birthName) $current"
            else birthName.ifBlank { current }
            val name = "$first $last".trim()
            if (name.isBlank()) return null
            fun year(date: String, decade: String): String {
                val y = date.take(4)
                return if (y.length == 4 && y != "0000") y else decade.takeIf { it.isNotBlank() && it != "unknown" } ?: ""
            }
            val born = year(p.optString("BirthDate"), p.optString("BirthDecade"))
            val died = year(p.optString("DeathDate"), p.optString("DeathDecade"))
            val dates = if (born.isBlank() && died.isBlank()) "" else "$born–$died"
            return name to dates
        }
    }

    private fun read(key: String): List<Person> {
        val arr = try {
            JSONArray(prefs.getString(key, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        return (0 until arr.length()).mapNotNull { i ->
            arr.optJSONObject(i)?.let {
                Person(it.optString("id"), it.optString("name"), it.optString("dates"), it.optString("view"), it.optLong("time"))
            }?.takeIf { it.id.isNotBlank() }
        }
    }

    private fun write(key: String, list: List<Person>) {
        val arr = JSONArray()
        list.forEach {
            arr.put(JSONObject().put("id", it.id).put("name", it.name).put("dates", it.dates).put("view", it.view).put("time", it.time))
        }
        prefs.edit().putString(key, arr.toString()).apply()
    }
}
