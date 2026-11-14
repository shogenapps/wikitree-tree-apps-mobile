package org.wikitree.treeapps

import android.app.Activity
import android.app.AlertDialog
import android.app.Dialog
import android.graphics.Typeface
import android.text.InputType
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.BaseAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView

/**
 * The People screen: a full-screen list of saved (starred) and recent people, kept on the phone.
 * Tap a person to show them, tap the star to save or unsave, long-press to remove.
 *
 * With [start] set it is the start screen shown when the app is opened afresh: it adds a
 * "Continue" button for the last app and person and the list of Tree Apps, has no Done button,
 * and stays up until something is chosen, so nothing loads before then.
 */
class PeopleDialog(
    private val activity: Activity,
    private val store: PeopleStore,
    private val currentId: String,
    private val currentView: String,
    private val appTitle: (String) -> String?,
    private val onPick: (Person) -> Unit,
    private val start: Start? = null,
) {
    /** What the start screen adds. */
    class Start(
        val continueLabel: String?,
        val apps: List<Pair<String, String>>,
        val onContinue: () -> Unit,
        val onApp: (String) -> Unit,
        val onBack: () -> Unit,
    )

    private sealed class Row {
        data class Header(val text: String) : Row()
        data class Item(val person: Person, val saved: Boolean, val inSaved: Boolean, val match: Boolean = false) : Row()
        data class Empty(val text: String) : Row()
        data class App(val key: String, val title: String) : Row()
    }

    private val dialog = Dialog(activity, android.R.style.Theme_Material_Light_NoActionBar)
    private var rows: List<Row> = emptyList()
    private val adapter = Adapter()
    private lateinit var starButton: Button
    private lateinit var list: ListView

    /** Name search: the people found, a line saying how it went, and a counter to drop late answers. */
    private var matches: List<Person> = emptyList()
    private var searchNote: String? = null
    private var searchRun = 0
    private val density = activity.resources.displayMetrics.density
    private fun dp(v: Int) = (v * density).toInt()

    fun show() {
        val green = activity.getColor(R.color.wt_green)
        val root = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            // Green behind the status bar, as on the main screen; the list area below is tan.
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
        val body = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(activity.getColor(R.color.wt_tan))
        }

        // Title bar, in the shell's green.
        val bar = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(green)
        }
        bar.addView(TextView(activity).apply {
            text = activity.getString(if (start != null) R.string.app_name else R.string.people_title)
            setTextColor(activity.getColor(R.color.on_green))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTypeface(typeface, Typeface.BOLD)
            setPadding(dp(16), 0, 0, 0)
        }, LinearLayout.LayoutParams(0, dp(52), 1f))
        (bar.getChildAt(0) as TextView).gravity = Gravity.CENTER_VERTICAL
        if (start == null) bar.addView(barButton(activity.getString(R.string.done)) { dialog.dismiss() })
        root.addView(bar)

        // Start screen: carry on where the last visit ended.
        if (start?.continueLabel != null) {
            val go = Button(activity).apply {
                text = start.continueLabel
                isAllCaps = false
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setTextColor(activity.getColor(R.color.on_green))
                backgroundTintList = android.content.res.ColorStateList.valueOf(green)
                setOnClickListener {
                    dialog.dismiss()
                    start.onContinue()
                }
            }
            body.addView(go, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(56)).apply {
                setMargins(dp(8), dp(10), dp(8), 0)
            })
        }

        // Find someone: a WikiTree ID opens straight away, anything else is searched for by name.
        val find = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(8), dp(8), 0)
        }
        val input = EditText(activity).apply {
            hint = activity.getString(R.string.find_hint)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS or
                InputType.TYPE_TEXT_FLAG_CAP_WORDS
            imeOptions = EditorInfo.IME_ACTION_SEARCH
            setSingleLine()
        }
        fun submit() {
            val text = input.text.toString().trim()
            if (text.isEmpty()) return
            activity.getSystemService(InputMethodManager::class.java)?.hideSoftInputFromWindow(input.windowToken, 0)
            find(text)
        }
        input.setOnEditorActionListener { _, _, _ -> submit(); true }
        find.addView(input, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        find.addView(actionButton(activity.getString(R.string.find_go)) { submit() })
        body.addView(find)

        // Save or unsave the person on screen.
        val actions = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(dp(8), 0, dp(8), dp(4))
        }
        if (currentId.isNotBlank() && start == null) {
            starButton = actionButton("") {
                store.toggleSaved(currentId, currentView)
            }
            actions.addView(starButton, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        }
        body.addView(actions)

        list = ListView(activity).apply {
            this.adapter = this@PeopleDialog.adapter
            divider = null
            setOnItemClickListener { _, _, pos, _ ->
                when (val row = rows[pos]) {
                    is Row.Item -> {
                        dialog.dismiss()
                        onPick(row.person)
                    }
                    is Row.App -> {
                        dialog.dismiss()
                        start?.onApp(row.key)
                    }
                    else -> {}
                }
            }
            setOnItemLongClickListener { _, _, pos, _ ->
                val row = rows[pos] as? Row.Item ?: return@setOnItemLongClickListener false
                if (row.match) return@setOnItemLongClickListener false
                confirmRemove(row)
                true
            }
        }
        body.addView(list, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        root.addView(body, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))

        store.onChange = { refresh() }
        dialog.setOnDismissListener { store.onChange = null }
        // Back on the start screen leaves the app; nothing has been loaded yet.
        if (start != null) dialog.setOnCancelListener { start.onBack() }
        refresh()
        dialog.setContentView(root)
        dialog.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        dialog.show()
    }

    fun dismiss() = dialog.dismiss()

    /** Open a typed WikiTree ID, or look a name up with the WikiTree API and list the matches. */
    private fun find(text: String) {
        if (ID_PATTERN.matches(text)) {
            dialog.dismiss()
            onPick(Person(text, "", "", currentView, 0))
            return
        }
        val run = ++searchRun
        matches = emptyList()
        searchNote = activity.getString(R.string.find_searching)
        refresh()
        list.setSelection(0)
        store.search(text) { found, total ->
            if (run != searchRun) return@search
            matches = found.orEmpty().map { it.copy(view = currentView) }
            searchNote = when {
                found == null -> activity.getString(R.string.find_failed)
                found.isEmpty() -> activity.getString(R.string.find_none, text)
                total > found.size -> activity.getString(R.string.find_more, found.size, total)
                else -> null
            }
            refresh()
            list.setSelection(0)
        }
    }

    private fun refresh() {
        val saved = store.saved()
        val savedIds = saved.map { it.id.lowercase() }.toSet()
        val recent = store.recent()
        rows = buildList {
            if (matches.isNotEmpty() || searchNote != null) {
                add(Row.Header(activity.getString(R.string.find_matches)))
                matches.forEach { add(Row.Item(it, saved = it.id.lowercase() in savedIds, inSaved = false, match = true)) }
                searchNote?.let { add(Row.Empty(it)) }
            }
            add(Row.Header(activity.getString(R.string.people_saved)))
            if (saved.isEmpty()) add(Row.Empty(activity.getString(R.string.people_saved_empty)))
            saved.forEach { add(Row.Item(it, saved = true, inSaved = true)) }
            add(Row.Header(activity.getString(R.string.people_recent)))
            if (recent.isEmpty()) add(Row.Empty(activity.getString(R.string.people_recent_empty)))
            recent.forEach { add(Row.Item(it, saved = it.id.lowercase() in savedIds, inSaved = false)) }
            if (start != null) {
                add(Row.Header(activity.getString(R.string.start_apps, currentId.ifBlank { "…" })))
                start.apps.forEach { add(Row.App(it.first, it.second)) }
            }
        }
        adapter.notifyDataSetChanged()
        if (::starButton.isInitialized) {
            starButton.text = if (store.isSaved(currentId)) "★  " + activity.getString(R.string.unsave_person, currentId)
            else "☆  " + activity.getString(R.string.save_person, currentId)
        }
    }

    private fun confirmRemove(row: Row.Item) {
        val label = row.person.name.ifBlank { row.person.id }
        val choices = buildList {
            if (row.inSaved) add(activity.getString(R.string.remove_saved) to { store.removeSaved(row.person.id) })
            else {
                add(activity.getString(R.string.remove_recent) to { store.removeRecent(row.person.id) })
                add(activity.getString(R.string.clear_recent) to { store.clearRecent() })
            }
        }
        AlertDialog.Builder(activity)
            .setTitle(label)
            .setItems(choices.map { it.first }.toTypedArray()) { _, which -> choices[which].second() }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    private fun barButton(text: String, onClick: () -> Unit) = Button(activity, null, 0, R.style.BarButton).apply {
        this.text = text
        setOnClickListener { onClick() }
    }

    private fun actionButton(text: String, onClick: () -> Unit) = Button(activity).apply {
        this.text = text
        isAllCaps = false
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
        setOnClickListener { onClick() }
    }

    private inner class Adapter : BaseAdapter() {
        override fun getCount() = rows.size
        override fun getItem(position: Int) = rows[position]
        override fun getItemId(position: Int) = position.toLong()
        override fun getViewTypeCount() = 4
        override fun getItemViewType(position: Int) = when (rows[position]) {
            is Row.Header -> 0
            is Row.Item -> 1
            is Row.Empty -> 2
            is Row.App -> 3
        }
        override fun isEnabled(position: Int) = rows[position] is Row.Item || rows[position] is Row.App

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View =
            when (val row = rows[position]) {
                is Row.Header -> (convertView as? TextView ?: TextView(activity).apply {
                    setPadding(dp(16), dp(18), dp(16), dp(6))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(activity.getColor(R.color.wt_green))
                }).apply { text = row.text.uppercase() }

                is Row.Empty -> (convertView as? TextView ?: TextView(activity).apply {
                    setPadding(dp(16), dp(4), dp(16), dp(8))
                    setTextColor(0xFF6B6B6B.toInt())
                }).apply { text = row.text }

                is Row.App -> (convertView as? TextView ?: TextView(activity).apply {
                    setPadding(dp(16), dp(12), dp(16), dp(12))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    setTextColor(0xFF1F1F1F.toInt())
                }).apply {
                    text = if (row.key == currentView) "${row.title}  ✓" else row.title
                }

                is Row.Item -> itemView(convertView as? LinearLayout, row)
            }

        private fun itemView(reuse: LinearLayout?, row: Row.Item): View {
            val view = reuse ?: LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(16), dp(10), dp(4), dp(10))
                val texts = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
                texts.addView(TextView(activity).apply {
                    tag = "title"
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    setTextColor(0xFF1F1F1F.toInt())
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                })
                texts.addView(TextView(activity).apply {
                    tag = "detail"
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                    setTextColor(0xFF6B6B6B.toInt())
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                })
                addView(texts, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
                addView(TextView(activity).apply {
                    tag = "star"
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
                    gravity = Gravity.CENTER
                    setTextColor(activity.getColor(R.color.wt_green))
                    // The star is its own button; the rest of the row opens the person.
                    isFocusable = false
                }, LinearLayout.LayoutParams(dp(48), dp(48)))
            }
            val p = row.person
            view.findViewWithTag<TextView>("title").text = p.name.ifBlank { p.id }
            view.findViewWithTag<TextView>("detail").text =
                listOfNotNull(
                    p.id.takeIf { p.name.isNotBlank() }, p.dates.ifBlank { null },
                    if (row.match) null else appTitle(p.view),
                )
                    .joinToString("  ·  ")
            view.findViewWithTag<TextView>("star").apply {
                text = if (row.saved) "★" else "☆"
                contentDescription = activity.getString(if (row.saved) R.string.unsave_person else R.string.save_person, p.id)
                setOnClickListener { store.toggleSaved(p.id, p.view) }
            }
            return view
        }
    }

    private companion object {
        /** "Windsor-1": a last name, a dash and a number, with no spaces. */
        val ID_PATTERN = Regex("\\S+-\\d+")
    }
}
