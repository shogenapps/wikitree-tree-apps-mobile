package org.wikitree.treeapps

/**
 * Finds the people a question to Genie names, among those the start screen knows: the member,
 * Saved and Recent people and (by full name only) the watchlist. "Who are George's parents?"
 * becomes "Who are Beacall-123's parents?", so Genie looks up that George and no other, and
 * the first person named is the one whose profile Genie opens on.
 *
 * A name counts only when it is one person's: two Georges on the start screen leave "George"
 * to Genie. A first or last name on its own must start with a capital letter ("will" is not
 * Will), and doesn't count at the start of the question if it is also a word such as "Will" or
 * "May". The start screen's people win over the watchlist's. Mirrors GenieNames in Wbe.swift.
 */
object GenieNames {
    /** Someone the start screen knows. [onScreen] people match by first or last name alone too. */
    class Known(val id: String, val name: String, val onScreen: Boolean)

    class Result(val question: String, val personId: String?)

    private val PARENS = Regex("\\(([^)]*)\\)")
    private val SPLIT = Regex("[\\s()]+")
    private val SPACES = Regex("\\s+")

    /** Names that are also words often starting a question ("Will his...?"): not a name there. */
    private val WORDS = setOf("will", "may", "mark", "rose", "grace", "hope", "faith", "joy", "june", "april",
        "august", "bill", "ray", "guy", "art", "dawn", "earl", "king", "major", "rich", "sunny")

    fun resolve(question: String, people: List<Known>): Result {
        val lower = question.lowercase()
        // phrase -> the ids it could mean; the start screen's people first, then the watchlist.
        val onScreen = linkedMapOf<String, MutableSet<String>>()
        val elsewhere = linkedMapOf<String, MutableSet<String>>()
        val single = mutableSetOf<String>()
        for (p in people) {
            if (p.id.isBlank()) continue
            val words = p.name.split(SPLIT).filter { it.isNotBlank() }
            val phrases = mutableListOf(p.id)
            if (words.isNotEmpty()) {
                val first = words.first()
                phrases += words.joinToString(" ")
                if (words.size > 1) phrases += "$first ${words.last()}"
                PARENS.find(p.name)?.groupValues?.get(1)?.trim()?.takeIf { it.isNotEmpty() }?.let { phrases += "$first $it" }
                if (p.onScreen) {
                    for (w in listOf(first, words.last())) {
                        if (w.length >= 3) {
                            phrases += w
                            single += w.lowercase()
                        }
                    }
                }
            }
            val into = if (p.onScreen) onScreen else elsewhere
            for (phrase in phrases) {
                val key = phrase.trim().replace(SPACES, " ").lowercase()
                // Only what the question could contain is kept, so a long watchlist costs little.
                if (key.length < 3 || !lower.contains(key)) continue
                into.getOrPut(key) { mutableSetOf() } += p.id
            }
        }
        val ids = mutableMapOf<String, String>()
        for ((key, set) in onScreen) if (set.distinctBy { it.lowercase() }.size == 1) ids[key] = set.first()
        for ((key, set) in elsewhere) {
            if (key in onScreen || key in single) continue
            if (set.distinctBy { it.lowercase() }.size == 1) ids[key] = set.first()
        }
        if (ids.isEmpty()) return Result(question, null)
        val alternatives = ids.keys.sortedByDescending { it.length }.joinToString("|") { Regex.escape(it).replace(" ", "\\E\\s+\\Q") }
        val pattern = Regex("(?<![\\p{L}\\p{N}-])(?:$alternatives)(?![\\p{L}\\p{N}-])", RegexOption.IGNORE_CASE)
        var firstId: String? = null
        val out = pattern.replace(question) { m ->
            val key = m.value.replace(SPACES, " ").lowercase()
            val id = ids[key] ?: return@replace m.value
            // A first or last name alone must be written as a name.
            if (key in single && !key.contains('-') && !m.value.first().isUpperCase()) return@replace m.value
            if (key in single && key in WORDS && question.substring(0, m.range.first).isBlank()) return@replace m.value
            if (firstId == null) firstId = id
            id
        }
        return Result(out, firstId)
    }
}
