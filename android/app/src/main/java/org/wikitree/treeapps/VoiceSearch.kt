package org.wikitree.treeapps

import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.os.Build
import android.speech.RecognizerIntent
import java.net.URLEncoder
import java.text.Normalizer
import java.util.Locale

// Voice search for the name search: the phone's own speech recognition turns speech into text, a
// few plain rules split the text into name, years and place, and names that sound like someone
// on the member's watchlist (or Saved and Recent) are spelled the way the tree spells them.
// No AI or language model is involved. Mirrors VoiceSearch.swift on iOS.

/**
 * A name search, read from what was typed or said: "John Smith, born 1850 in Yorkshire",
 * "Mary Jones 1820-1890", "Jan van der Berg died 1901 in Amsterdam". A first year is the birth,
 * a second the death, unless "born" or "died" says otherwise; "in" (or "at", "from") starts a
 * place. Everything else is the name: its last word is the last name, with "van", "de" and the
 * like before it. A few words in other languages work too ("geboren", "urodzona w").
 */
data class NameSearch(
    val names: List<String> = emptyList(),
    val born: String = "",
    val died: String = "",
    val bornPlace: String = "",
    val diedPlace: String = "",
    /** "about 1850": the years are searched with a wider spread. */
    val about: Boolean = false,
) {
    private val lastCount: Int
        get() {
            if (names.isEmpty()) return 0
            var i = names.size - 1
            while (i > 0 && names[i - 1].lowercase() in PARTICLES) i--
            return names.size - i
        }
    val first get() = names.dropLast(lastCount).joinToString(" ")
    val last get() = names.takeLast(lastCount).joinToString(" ")
    val isEmpty get() = names.isEmpty()
    /** A year or place was given as well as the name. */
    val hasMore get() = born.isNotEmpty() || died.isNotEmpty() || bornPlace.isNotEmpty() || diedPlace.isNotEmpty()
    /** The name alone, for the watchlist suggestions while typing. */
    val name get() = names.joinToString(" ")

    /**
     * The search written out, to put in the search box: "John Smith, born 1850 in Yorkshire", with
     * the joining words in the app's [language] ("geboren 1850 in Bayern").
     */
    fun text(language: String = "en"): String = buildString {
        val w = JOINERS[language.take(2)] ?: JOINERS.getValue("en")
        append(names.joinToString(" "))
        fun part(word: String, year: String, place: String, isBirth: Boolean) {
            if (year.isEmpty() && place.isEmpty()) return
            append(", ").append(word)
            if (year.isNotEmpty()) append(if (about && isBirth) " ${w[3]} $year" else " $year")
            if (place.isNotEmpty()) append(" ${w[2]} ").append(place)
        }
        part(w[0], born, bornPlace, true)
        part(w[1], died, diedPlace, false)
    }

    /** The searchPerson parameters beyond the name, ready to add to the URL. */
    val queryString: String
        get() = buildString {
            fun add(key: String, value: String) = append("&$key=").append(URLEncoder.encode(value, "UTF-8"))
            if (born.isNotEmpty()) add("BirthDate", "$born-01-01")
            if (died.isNotEmpty()) add("DeathDate", "$died-01-01")
            // A year said aloud is rarely exact in the records.
            if (born.isNotEmpty() || died.isNotEmpty()) add("dateSpread", if (about) "5" else "2")
            // WikiTree matches any one word of the place, so "Leeds, Yorkshire" finds everyone in
            // Yorkshire. Only the first part (the town) is sent.
            if (bornPlace.isNotEmpty()) add("BirthLocation", bornPlace.substringBefore(',').trim())
            if (diedPlace.isNotEmpty()) add("DeathLocation", diedPlace.substringBefore(',').trim())
        }

    companion object {
        /** The words that join a written-out search (born, died, in, about), each one the parser reads back. */
        private val JOINERS = mapOf(
            "en" to listOf("born", "died", "in", "about"),
            "de" to listOf("geboren", "gestorben", "in", "um"),
            "nl" to listOf("geboren", "overleden", "in", "circa"),
            "fr" to listOf("né", "mort", "à", "environ"),
            "es" to listOf("nacido", "fallecido", "en", "circa"),
            "it" to listOf("nato", "morto", "in", "circa"),
            "sv" to listOf("född", "död", "i", "ca."),
        )

        private val BORN = setOf(
            "born", "b", "b.", "birth", "geboren", "geb.", "né", "née", "nacido", "nacida", "nato", "nata",
            "urodzony", "urodzona", "urodził", "urodziła", "född", "født", "syntynyt",
        )
        private val DIED = setOf(
            "died", "d", "d.", "death", "dead", "gestorben", "gest.", "overleden", "mort", "morte", "décédé",
            "décédée", "murió", "fallecido", "fallecida", "morto", "morta", "zmarł", "zmarła", "död", "døde", "kuollut",
        )
        private val PLACE = setOf("in", "at", "from", "à", "en", "w", "we", "i")
        private val ABOUT = setOf(
            "about", "around", "circa", "ca", "ca.", "c", "c.", "abt", "abt.", "approximately", "um", "ungefähr",
            "environ", "około",
        )
        private val JOIN = setOf("and", "to", "until", "till", "-")
        private val PARTICLES = setOf(
            "van", "von", "de", "der", "den", "du", "la", "le", "di", "da", "del", "della", "dos", "das", "ten",
            "ter", "op", "st", "st.", "zu",
        )
        private const val EDGE = ",;:!?\"“”()"

        private fun trimmed(token: String) = token.trim { it in EDGE }

        private fun year(token: String): String? {
            var t = trimmed(token).removeSuffix(".").removeSuffix("s")
            if (t.length != 4 || !t.all { it in '0'..'9' }) return null
            return t.takeIf { it.toInt() in 1000..2099 }
        }

        private enum class Event { BORN, DIED }

        fun parse(text: String): NameSearch {
            // "1820-1890" is a birth and a death.
            val tokens = mutableListOf<String>()
            for (raw in text.replace('–', '-').replace('—', '-').split(Regex("\\s+")).filter { it.isNotEmpty() }) {
                val parts = raw.split("-")
                val a = parts.getOrNull(0)?.let(::year)
                val b = parts.getOrNull(1)?.let(::year)
                if (parts.size == 2 && a != null && b != null) tokens += listOf(a, "-", b) else tokens += raw
            }
            val names = mutableListOf<String>()
            var born = ""
            var died = ""
            val bornPlace = StringBuilder()
            val diedPlace = StringBuilder()
            var about = false
            var pending: Event? = null
            var place: Event? = null
            // Words after "born" or "died" that are not a year are a place ("born Leeds").
            var afterEvent = false
            fun addPlace(word: String, to: Event) {
                val sb = if (to == Event.BORN) bornPlace else diedPlace
                if (sb.isNotEmpty() && !sb.endsWith(", ")) sb.append(' ')
                sb.append(word)
            }
            for ((i, raw) in tokens.withIndex()) {
                val word = trimmed(raw).lowercase()
                val bare = word.removeSuffix(".")
                val y = year(raw)
                if (y != null) {
                    val event = pending ?: if (born.isEmpty()) Event.BORN else Event.DIED
                    if (event == Event.BORN && born.isEmpty()) born = y else if (died.isEmpty()) died = y
                    place = null
                    afterEvent = false
                    continue
                }
                // A bare "b" or "d" (or "B.") is "born" or "died" only before a year ("b 1850"); otherwise
                // it is more likely part of a name the phone heard in pieces ("Thomas B Cole").
                val next = tokens.getOrNull(i + 1)
                if ((bare == "b" || bare == "d") && (next == null || (year(next) == null && trimmed(next).lowercase() !in ABOUT))) {
                    names += raw.trim { it in EDGE }.removeSuffix(".")
                    continue
                }
                if (word in BORN || bare in BORN) { pending = Event.BORN; place = null; afterEvent = true; continue }
                if (word in DIED || bare in DIED) { pending = Event.DIED; place = null; afterEvent = true; continue }
                if (word in ABOUT) { about = true; continue }
                if (place == null && word in JOIN) continue
                if (word in PLACE && i + 1 < tokens.size) {
                    if (year(tokens[i + 1]) != null) continue // "born in 1850"
                    val event = pending ?: Event.BORN
                    if (place == null) {
                        val sb = if (event == Event.BORN) bornPlace else diedPlace
                        if (sb.isNotEmpty()) sb.append(", ")
                    }
                    place = event
                    continue
                }
                if (place == null && afterEvent && names.isNotEmpty() && pending != null) place = pending
                val into = place
                if (into != null) {
                    addPlace(raw, into)
                    continue
                }
                val name = trimmed(raw).removeSuffix(".")
                if (name.isNotEmpty()) names += name
            }
            fun tidy(sb: StringBuilder) = sb.toString().trim { it in " ,.;" }
            return NameSearch(names, born, died, tidy(bornPlace), tidy(diedPlace), about)
        }
    }
}

/**
 * The names in the member's own tree (watchlist, Saved, Recent), for putting right a name the
 * phone heard a little wrong: "Beecall" sounds like "Beacall", so it becomes "Beacall".
 */
class NameSounds(names: List<String>) {
    private val count = HashMap<String, Int>()
    /** Folded spelling → the spelling used most in the tree. */
    private val spelling = HashMap<String, String>()
    private val byKey = HashMap<String, MutableList<String>>()

    init {
        val seen = HashMap<String, HashMap<String, Int>>()
        for (name in names) {
            for (w in name.split(Regex("[\\s(),]+"))) {
                val f = fold(w)
                if (f.length < 2) continue
                val m = seen.getOrPut(f) { HashMap() }
                m[w] = (m[w] ?: 0) + 1
            }
        }
        for ((f, spellings) in seen) {
            count[f] = spellings.values.sum()
            spelling[f] = spellings.entries.sortedWith(compareBy({ -it.value }, { it.key })).first().key
            byKey.getOrPut(key(f)) { mutableListOf() } += f
        }
    }

    val isEmpty get() = count.isEmpty()

    /** The most common names, as hints for the recognizer. */
    fun hints(limit: Int = 100): List<String> =
        count.entries.sortedWith(compareBy({ -it.value }, { it.key })).take(limit).mapNotNull { spelling[it.key] }

    fun knows(word: String) = count.containsKey(fold(word))

    /** The tree's spelling of a name that sounds like [word], or null if none is close. */
    fun match(word: String, joined: Boolean = false): String? {
        val f = fold(word)
        if (f.length < 2) return null
        spelling[f]?.let { return it }
        val k = key(f)
        var candidates: List<String> = byKey[k].orEmpty()
        // Words run together ("B Cole") must sound exactly like the name; a single word may be a
        // sound or so off.
        if (candidates.isEmpty() && k.length >= 3 && !joined) {
            candidates = byKey.filterKeys { distance(it, k) == 1 }.values.flatten()
        }
        val limit = if (joined) maxOf(4, f.length * 2 / 3) else maxOf(2, f.length / 3)
        return candidates.map { it to distance(it, f) }
            .filter { it.second <= limit }
            .minWithOrNull(compareBy({ it.second }, { -(count[it.first] ?: 0) }))
            ?.let { spelling[it.first] }
    }

    /**
     * Put the names in a search right. Two or three heard words that together sound like one name
     * ("B Cole", "Bee Call") are joined first, as long as the first of them is not a name already.
     */
    fun correct(search: NameSearch): NameSearch {
        if (isEmpty) return search
        val words = search.names.toMutableList()
        var i = 0
        while (i + 1 < words.size) {
            if (!knows(words[i])) {
                for (n in 3 downTo 2) {
                    if (i + n > words.size) continue
                    val joined = match(words.subList(i, i + n).joinToString(""), joined = true)
                    if (joined != null && fold(joined).length >= 4) {
                        words[i] = joined
                        repeat(n - 1) { words.removeAt(i + 1) }
                        break
                    }
                }
            }
            i++
        }
        return search.copy(names = words.map { match(it) ?: it })
    }

    /** How many words of a heard search are names from the tree, to choose among alternatives. */
    fun score(search: NameSearch) = search.names.count { knows(it) }

    companion object {
        /** Lower case, accents taken off, letters only. */
        fun fold(s: String): String {
            val t = s.lowercase().replace("ß", "ss").replace("æ", "ae").replace("ø", "o").replace("ł", "l").replace("đ", "d")
            return Normalizer.normalize(t, Normalizer.Form.NFD).filter { it in 'a'..'z' }
        }

        /**
         * A rough key for how a name sounds, in the spirit of Metaphone: letters that sound alike
         * become one letter and vowels drop out, so "Beacall", "Beecall" and "Bickel" all give "bkl".
         */
        fun key(folded: String): String {
            var s = folded
            for ((a, b) in listOf("kn" to "n", "gn" to "n", "pn" to "n", "wr" to "r", "ps" to "s", "wh" to "w", "x" to "s")) {
                if (s.startsWith(a)) { s = b + s.drop(a.length); break }
            }
            for ((a, b) in listOf(
                "sch" to "sk", "tch" to "ch", "ph" to "f", "gh" to "g", "ck" to "k", "th" to "t",
                "sh" to "x", "ch" to "x", "cz" to "x", "sz" to "x", "ce" to "se", "ci" to "si",
                "cy" to "sy", "c" to "k", "q" to "k", "x" to "ks", "z" to "s", "v" to "f",
                "dg" to "j", "j" to "y",
            )) s = s.replace(a, b)
            val out = StringBuilder()
            for ((i, c) in s.withIndex()) {
                if (c == 'w') {
                    // A "w" before a vowel sounds like "v"; elsewhere ("Lowe") it is silent.
                    if (i + 1 < s.length && s[i + 1] in "aeiouy" && out.lastOrNull() != 'f') out.append('f')
                    continue
                }
                if (c in "aeiouyh") {
                    if (i == 0) out.append('a')
                    continue
                }
                if (out.lastOrNull() != c) out.append(c)
            }
            return out.toString()
        }

        fun distance(a: String, b: String): Int {
            val d = IntArray(b.length + 1) { it }
            for (i in 1..a.length) {
                var previous = d[0]
                d[0] = i
                for (j in 1..b.length) {
                    val t = d[j]
                    d[j] = minOf(d[j] + 1, d[j - 1] + 1, previous + if (a[i - 1] == b[j - 1]) 0 else 1)
                    previous = t
                }
            }
            return d[b.length]
        }
    }
}

/**
 * Listening, through the phone's own speech recognition screen (Google's, on most phones). It
 * asks for the microphone itself, so the app needs no microphone permission. The result comes
 * back through [MainActivity.onActivityResult], which hands it to [onResult].
 */
object VoiceSearch {
    private const val REQ = 3
    private var pending: ((List<String>) -> Unit)? = null

    /** Languages offered besides the phone's own. */
    private val OFFERED = listOf(
        "en-GB", "en-US", "en-AU", "en-CA", "en-IE", "en-NZ", "en-ZA", "cy-GB", "ga-IE", "gd-GB", "de-DE",
        "de-AT", "de-CH", "nl-NL", "nl-BE", "fr-FR", "fr-CA", "it-IT", "es-ES", "es-MX", "pt-PT", "pt-BR",
        "sv-SE", "nb-NO", "da-DK", "fi-FI", "is-IS", "pl-PL", "cs-CZ", "sk-SK", "hu-HU", "ro-RO", "hr-HR",
        "sl-SI", "lt-LT", "lv-LV", "et-EE", "uk-UA", "ru-RU", "el-GR", "he-IL", "tr-TR", "ja-JP", "zh-CN", "ko-KR",
    )

    private fun prefs(context: Context) = context.getSharedPreferences("voice", Context.MODE_PRIVATE)

    /** The chosen language tag, or null for the phone's own. */
    fun language(context: Context): String? = prefs(context).getString("language", null)

    /** "Polski (Polska)": each language in its own words, so it can be found by its speakers. */
    fun title(tag: String): String {
        val locale = Locale.forLanguageTag(tag)
        return locale.getDisplayName(locale).replaceFirstChar { it.titlecase(locale) }
    }

    fun languageTitle(context: Context): String = language(context)?.let(::title) ?: title(Locale.getDefault().toLanguageTag())

    fun isAvailable(activity: Activity): Boolean =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).resolveActivity(activity.packageManager) != null

    /** Choose the language voice search listens for. */
    fun chooseLanguage(activity: Activity, done: () -> Unit = {}) {
        // The phone's own language is already the first choice.
        // Compare language and country only: with regional preferences set (Android 14 and later)
        // the phone's tag also carries "-u-…" extensions.
        val phone = Locale.getDefault().let { if (it.country.isEmpty()) it.language else "${it.language}-${it.country}" }
        val tags = listOf<String?>(null) + OFFERED.filter { it != phone }.sortedBy { title(it).lowercase() }
        val titles = tags.map { tag ->
            tag?.let(::title) ?: activity.getString(R.string.voice_phone_language, title(Locale.getDefault().toLanguageTag()))
        }
        AlertDialog.Builder(activity)
            .setTitle(R.string.voice_language_title)
            .setSingleChoiceItems(titles.toTypedArray(), tags.indexOf(language(activity)).coerceAtLeast(0)) { d, which ->
                prefs(activity).edit().putString("language", tags[which]).apply()
                d.dismiss()
                done()
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    /** Listen for a name; [done] gets what was heard, every alternative, best first. */
    fun listen(activity: Activity, hints: List<String>, done: (List<String>) -> Unit): Boolean {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PROMPT, activity.getString(R.string.voice_prompt))
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            language(activity)?.let {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, it)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, it)
            }
            // Names from the tree, for recognizers that take hints (Android 13 and later).
            if (Build.VERSION.SDK_INT >= 33) putStringArrayListExtra(RecognizerIntent.EXTRA_BIASING_STRINGS, ArrayList(hints))
        }
        return try {
            pending = done
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQ)
            true
        } catch (_: ActivityNotFoundException) {
            pending = null
            false
        }
    }

    /** Called from the activity's onActivityResult; true if it was the answer to [listen]. */
    fun onResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ) return false
        val done = pending
        pending = null
        val heard = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS).orEmpty()
        if (resultCode == Activity.RESULT_OK && heard.isNotEmpty()) done?.invoke(heard)
        return true
    }

    /** Of the recognizer's guesses, the one with most names from the tree, put right; else its best. */
    fun best(heard: List<String>, names: NameSounds): NameSearch? =
        heard.map { names.correct(NameSearch.parse(it)) }
            .withIndex()
            .maxWithOrNull(compareBy({ names.score(it.value) }, { -it.index }))
            ?.value
}
