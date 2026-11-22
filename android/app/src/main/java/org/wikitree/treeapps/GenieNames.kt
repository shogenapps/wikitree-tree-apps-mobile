package org.wikitree.treeapps

/**
 * Finds the people a question to Genie names, among those the start screen knows: the member,
 * Saved and Recent people and (by full name only) the watchlist. "Who are George's parents?"
 * becomes "Who are Beacall-123's parents?", so Genie looks up that George and no other, and
 * the first person named is the one whose profile Genie opens on.
 *
 * A name that fits two people on the start screen (two Georges) comes back as [Result.unsure],
 * for the app to ask which; on the watchlist it is left to Genie. A first or last name on its own must start with a capital letter ("will" is not
 * Will), and doesn't count at the start of the question if it is also a word such as "Will" or
 * "May". The start screen's people win over the watchlist's. Mirrors GenieNames in Wbe.swift.
 */
object GenieNames {
    /** Someone the start screen knows. [onScreen] people match by first or last name alone too. */
    class Known(val id: String, val name: String, val onScreen: Boolean, val dates: String = "")

    /**
     * The question with the people named put in as IDs, and the first of them. Or, when a name
     * on the start screen fits more than one person, [unsure] is that name as typed and
     * [choices] the people it could be: ask which, then resolve again with the answer in `chosen`.
     */
    class Result(
        val question: String, val personId: String?,
        val unsure: String? = null, val choices: List<Known> = emptyList(),
    )

    private val PARENS = Regex("\\(([^)]*)\\)")
    private val SPLIT = Regex("[\\s()]+")
    private val SPACES = Regex("\\s+")
    private val CONNECTION = Regex("(?<![\\p{L}\\p{N}_-])([\\p{L}_]+-\\d+)['’]s (?:connection|relationship) (?:to|with) ([\\p{L}_]+-\\d+)", RegexOption.IGNORE_CASE)

    /** Names that are also words often starting a question ("Will his...?"): not a name there. */
    private val WORDS = setOf("will", "may", "mark", "rose", "grace", "hope", "faith", "joy", "june", "april",
        "august", "bill", "ray", "guy", "art", "dawn", "earl", "king", "major", "rich", "sunny")

    /** [chosen]: names already asked about (as typed, any case) and the ID picked for each. */
    fun resolve(question: String, people: List<Known>, chosen: Map<String, String> = emptyMap()): Result {
        val lower = question.lowercase()
        // phrase -> the ids it could mean; the start screen's people first, then the watchlist.
        val onScreen = linkedMapOf<String, MutableSet<String>>()
        val elsewhere = linkedMapOf<String, MutableSet<String>>()
        val single = mutableSetOf<String>()
        val known = mutableMapOf<String, Known>()
        val firstNames = mutableSetOf<String>()
        for (p in people) {
            if (p.id.isBlank()) continue
            val words = p.name.split(SPLIT).filter { it.isNotBlank() }
            val phrases = mutableListOf(p.id)
            if (words.isNotEmpty()) {
                val first = words.first()
                if (p.onScreen) firstNames += first.lowercase()
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
                into.getOrPut(key) { mutableSetOf() } += p.id.lowercase()
                known.putIfAbsent(p.id.lowercase(), p)
            }
        }
        val picked = chosen.mapKeys { it.key.trim().replace(SPACES, " ").lowercase() }
        val ids = mutableMapOf<String, String>()
        // Names that fit more than one person on the start screen: whom they could be.
        val many = mutableMapOf<String, List<Known>>()
        for ((key, set) in onScreen) {
            when {
                key in picked -> ids[key] = picked.getValue(key)
                set.size == 1 -> ids[key] = known.getValue(set.first()).id
                else -> many[key] = set.map { known.getValue(it) }
            }
        }
        for ((key, set) in elsewhere) {
            if (key in onScreen || key in single) continue
            if (set.size == 1) ids[key] = known.getValue(set.first()).id
        }
        if (ids.isEmpty() && many.isEmpty()) return Result(question, null)
        val alternatives = (ids.keys + many.keys).sortedByDescending { it.length }.joinToString("|") { Regex.escape(it).replace(" ", "\\E\\s+\\Q") }
        val pattern = Regex("(?<![\\p{L}\\p{N}-])(?:$alternatives)(?![\\p{L}\\p{N}-])", RegexOption.IGNORE_CASE)
        var firstId: String? = null
        val out = StringBuilder()
        var at = 0
        for (m in pattern.findAll(question)) {
            val key = m.value.replace(SPACES, " ").lowercase()
            // A first or last name alone must be written as a name.
            if (key in single && !key.contains('-') && !m.value.first().isUpperCase()) continue
            if (key in single && key in WORDS && question.substring(0, m.range.first).isBlank()) continue
            // A shared first or full name is asked about; a shared surname ("the Beacall family") is
            // left to Genie.
            many[key]?.let { if (key !in single || key in firstNames) return Result(question, null, unsure = m.value, choices = it) }
            val id = ids[key] ?: continue
            out.append(question, at, m.range.first).append(id)
            at = m.range.last + 1
            if (firstId == null) firstId = id
        }
        out.append(question, at, question.length)
        // "A's connection to B" in the words Genie's help gives: "connection between A and B".
        val text = CONNECTION.replace(out.toString()) { "connection between ${it.groupValues[1]} and ${it.groupValues[2]}" }
        return Result(text, firstId)
    }
}
