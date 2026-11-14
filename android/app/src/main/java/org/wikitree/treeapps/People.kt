package org.wikitree.treeapps

import android.content.Context
import android.os.Handler
import android.os.Looper
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** One person in the saved or recent list. [view] is the Tree App they were last shown in. */
data class Person(val id: String, val name: String, val dates: String, val view: String, val time: Long)

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
     * Search WikiTree by name: the last word is the last name, anything before it the first name.
     * [done] gets up to [SEARCH_LIMIT] people (their dates include the birthplace) and the total
     * number of matches, or null if the search failed.
     */
    fun search(text: String, done: (List<Person>?, Int) -> Unit) {
        val words = text.trim().split(Regex("\\s+"))
        val last = words.last()
        val first = words.dropLast(1).joinToString(" ")
        Thread {
            val result = try {
                val json = get(
                    "https://api.wikitree.com/api.php?action=searchPerson&appId=TreeAppsMobile" +
                        "&fields=Name,FirstName,RealName,LastNameAtBirth,LastNameCurrent,BirthDate,DeathDate,BirthLocation" +
                        "&limit=$SEARCH_LIMIT&LastName=" + URLEncoder.encode(last, "UTF-8") +
                        "&FirstName=" + URLEncoder.encode(first, "UTF-8"),
                )?.let { JSONArray(it).optJSONObject(0) }
                val found = json?.optJSONArray("matches")
                if (json == null) null
                else (0 until (found?.length() ?: 0)).mapNotNull { i ->
                    val p = found?.optJSONObject(i) ?: return@mapNotNull null
                    val id = p.optString("Name").ifBlank { return@mapNotNull null }
                    val (name, dates) = describe(p) ?: return@mapNotNull null
                    val detail = listOf(dates, p.optString("BirthLocation")).filter { it.isNotBlank() }.joinToString("  ·  ")
                    Person(id, name, detail, "", 0)
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
