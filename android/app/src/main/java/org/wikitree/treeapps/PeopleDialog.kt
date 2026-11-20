package org.wikitree.treeapps

import android.app.Activity
import android.app.AlertDialog
import android.app.Dialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.ScrollView
import android.widget.Toast
import android.net.Uri
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
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView

/**
 * The People screen: a full-screen list of saved (starred) and recent people, kept on the phone.
 * Tap a person to show them, tap the star to save or unsave, tap the round button on the left for
 * their profile on www.wikitree.com. Long-press a person for a menu: open them in one of the latest
 * Tree Apps or any other, their profile, read their biography aloud, save, share their profile
 * link, copy their ID, remove.
 *
 * With [start] set it is the start screen shown when the app is opened afresh: it adds the member
 * who is logged in, birthdays and the list of Tree Apps, has no Done button, and stays up until
 * something is chosen, so nothing loads before then. Its sections fold away under their headings
 * and stay as they were left.
 */
class PeopleDialog(
    private val activity: Activity,
    private val store: PeopleStore,
    private val currentId: String,
    private val currentView: String,
    private val appTitle: (String) -> String?,
    private val onPick: (Person) -> Unit,
    private val start: Start? = null,
    private val watchlist: WatchlistStore? = null,
    /** Every Tree App (key, title), for the long-press menu's "Open in" items. */
    private val apps: List<Pair<String, String>> = emptyList(),
    /** Called once the screen has closed. */
    private val onClosed: () -> Unit = {},
) {
    /** What the start screen adds. */
    class Start(
        val apps: List<Pair<String, String>>,
        val onApp: (String) -> Unit,
        val onBack: () -> Unit,
        /** Ask Android for leave to post notifications; calls back with whether it was given. */
        val askToNotify: ((Boolean) -> Unit) -> Unit = { it(true) },
    )

    private sealed class Row {
        /** A section heading; with a [key] (start screen only) a tap folds or unfolds the section. */
        data class Header(val text: String, val key: String? = null, val open: Boolean = true, val count: Int = 0) : Row()
        /** [birth] marks an Anniversaries row: true for a birth, false for a death. */
        data class Item(
            val person: Person, val saved: Boolean, val inSaved: Boolean, val match: Boolean = false,
            val birth: Boolean? = null,
        ) : Row()
        data class Empty(val text: String) : Row()
        data class App(val key: String, val title: String) : Row()
        /** A tappable line of text: refresh the watchlist, or switch the notification. */
        data class Action(val text: String, val run: () -> Unit) : Row()
        /** A full-width green button, e.g. "Log in to WikiTree". */
        data class Big(val text: String, val run: () -> Unit) : Row()
    }

    private val dialog = Dialog(activity, R.style.AppDialog)
    private var rows: List<Row> = emptyList()
    private val adapter = Adapter()
    private lateinit var starButton: Button
    private lateinit var list: ListView

    /** Name search: the people found, a line saying how it went, and a counter to drop late answers. */
    private var matches: List<Person> = emptyList()
    private var searchNote: String? = null
    private var searchRun = 0

    /** Watchlist people matching what is being typed, and how the last watchlist refresh went. */
    private var suggestions: List<Relative> = emptyList()
    private var watchlistNote: String? = null
    private var loadingWatchlist = false
    /** Which start-screen sections are open. Birthdays start folded: few people want them every time. */
    private val folds = activity.getSharedPreferences("start", Context.MODE_PRIVATE)
    private fun isOpen(key: String) = start == null || folds.getBoolean("open_$key", key != "born")
    private fun heading(text: String, key: String, count: Int = 0) =
        if (start == null) Row.Header(text) else Row.Header(text, key, isOpen(key), count)

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
            text = activity.getString(if (start != null) R.string.start_title else R.string.people_title)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setTextColor(activity.getColor(R.color.on_green))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTypeface(typeface, Typeface.BOLD)
            setPadding(dp(16), 0, 0, 0)
        }, LinearLayout.LayoutParams(0, dp(52), 1f))
        (bar.getChildAt(0) as TextView).gravity = Gravity.CENTER_VERTICAL
        if (start == null) bar.addView(barButton(activity.getString(R.string.done)) { dialog.dismiss() })
        root.addView(bar)

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
        // While typing, offer people from the watchlist whose names start that way.
        input.addTextChangedListener(object : android.text.TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
            override fun afterTextChanged(s: android.text.Editable?) {
                // Only the name counts here, not "born 1850 in Yorkshire" after it.
                val text = NameSearch.parse(s?.toString().orEmpty()).name
                val found = if (text.length < 2 || watchlist == null) emptyList() else watchlist.suggest(text)
                if (found == suggestions && matches.isEmpty() && searchNote == null) return
                suggestions = found
                // What was found for the old text no longer applies.
                searchRun++
                matches = emptyList()
                searchNote = null
                refresh()
                if (found.isNotEmpty()) list.setSelection(0)
            }
        })
        find.addView(input, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        // Voice search: what is heard goes in the box, for checking before Find. A long press
        // chooses the language.
        if (VoiceSearch.isAvailable(activity)) {
            find.addView(ImageView(activity).apply {
                setImageResource(R.drawable.ic_mic)
                contentDescription = activity.getString(R.string.voice_search)
                scaleType = ImageView.ScaleType.CENTER
                isClickable = true
                isFocusable = true
                val ripple = TypedValue()
                activity.theme.resolveAttribute(android.R.attr.selectableItemBackgroundBorderless, ripple, true)
                setBackgroundResource(ripple.resourceId)
                setOnClickListener { listen(input) }
                setOnLongClickListener {
                    VoiceSearch.chooseLanguage(activity) {
                        Toast.makeText(activity, activity.getString(R.string.voice_language_set, VoiceSearch.languageTitle(activity)), Toast.LENGTH_SHORT).show()
                    }
                    true
                }
            }, LinearLayout.LayoutParams(dp(44), dp(48)))
        }
        find.addView(actionButton(activity.getString(R.string.find_go)) { submit() })
        body.addView(find)
        if (start != null && Genie.isAvailable(activity)) body.addView(genieRow())

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
                    is Row.Header -> row.key?.let {
                        folds.edit().putBoolean("open_$it", !row.open).apply()
                        refresh()
                    }
                    is Row.Item -> {
                        dialog.dismiss()
                        onPick(row.person)
                    }
                    is Row.App -> {
                        dialog.dismiss()
                        start?.onApp(row.key)
                    }
                    is Row.Action -> row.run()
                    is Row.Big -> row.run()
                    else -> {}
                }
            }
            setOnItemLongClickListener { _, _, pos, _ ->
                val row = rows[pos] as? Row.Item ?: return@setOnItemLongClickListener false
                // The list gives the long-press buzz when this returns true.
                personMenu(row)
                true
            }
        }
        body.addView(list, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        root.addView(body, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))

        val onChange = { refresh() }
        store.onChange = onChange
        // Only this screen's own listener: when the screen is drawn again (dark mode switched),
        // the new one is already listening by the time this dismissal arrives.
        dialog.setOnDismissListener {
            if (store.onChange === onChange) store.onChange = null
            onClosed()
        }
        // Back on the start screen leaves the app; nothing has been loaded yet.
        if (start != null) dialog.setOnCancelListener { start.onBack() }
        refresh()
        dialog.setContentView(root)
        dialog.window?.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        dialog.show()
    }

    /**
     * Start screen: ask Genie (WBE's assistant) a question, or search WikiTree in Genie's own words.
     * Genie opens in a page sheet over this screen, about the person the Tree Apps list is for.
     */
    private fun genieRow(): View {
        val row = LinearLayout(activity).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), 0, dp(8), 0)
        }
        // Genie's lamp, from WBE's own icon.
        row.addView(ImageView(activity).apply {
            setImageResource(R.drawable.ic_genie)
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            setPadding(0, 0, dp(6), 0)
        })
        val input = EditText(activity).apply {
            hint = activity.getString(R.string.genie_hint)
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            imeOptions = EditorInfo.IME_ACTION_SEND
            setSingleLine()
        }
        fun ask() {
            activity.getSystemService(InputMethodManager::class.java)?.hideSoftInputFromWindow(input.windowToken, 0)
            val question = input.text.toString().trim()
            input.setText("")
            Genie.open(activity, question, currentId.ifBlank { store.me()?.id ?: "" }, genieKnown())
        }
        input.setOnEditorActionListener { _, _, _ -> ask(); true }
        row.addView(input, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        row.addView(actionButton(activity.getString(R.string.genie_ask)) { ask() }.apply {
            contentDescription = activity.getString(R.string.genie_ask_long)
        })
        return row
    }

    /** The people Genie questions can name: those on the start screen, then the watchlist. */
    private fun genieKnown(): List<GenieNames.Known> = buildList {
        val shown = listOfNotNull(store.me()) + store.saved() + store.recent() + matches
        shown.forEach { add(GenieNames.Known(it.id, it.name, onScreen = true)) }
        watchlist?.anniversaries()?.forEach { add(GenieNames.Known(it.person.id, it.person.name, onScreen = true)) }
        watchlist?.all()?.forEach { add(GenieNames.Known(it.id, it.name, onScreen = false)) }
    }

    fun dismiss() = dialog.dismiss()
    val isShowing get() = dialog.isShowing

    /** Names in the member's own tree, which voice search is steered towards. */
    private fun treeNames(): NameSounds {
        val mine = store.saved() + store.recent() + listOfNotNull(store.me())
        return NameSounds(watchlist?.all().orEmpty().map { it.name } + mine.map { it.name })
    }

    /** Birthplaces of the people on the watchlist, for putting right a place the phone misheard. */
    private fun treePlaces() = NameSounds(watchlist?.all().orEmpty().map { it.place }, loose = true)

    /** Listen for a name and put what was heard in the search box, for checking before Find. */
    private fun listen(input: EditText) {
        activity.getSystemService(InputMethodManager::class.java)?.hideSoftInputFromWindow(input.windowToken, 0)
        val names = treeNames()
        val places = treePlaces()
        val started = VoiceSearch.listen(activity, names.hints() + places.hints(30)) { heard ->
            val best = VoiceSearch.best(heard, names, places)
            if (best == null || best.isEmpty) {
                Toast.makeText(activity, activity.getString(R.string.voice_no_name, heard.first()), Toast.LENGTH_LONG).show()
            } else {
                input.setText(best.text(activity.resources.configuration.locales[0].language))
                input.setSelection(input.text.length)
            }
        }
        if (!started) Toast.makeText(activity, R.string.voice_unavailable, Toast.LENGTH_LONG).show()
    }

    /** Open a typed WikiTree ID, or look a name up with the WikiTree API and list the matches. */
    private fun find(text: String) {
        if (ID_PATTERN.matches(text)) {
            dialog.dismiss()
            onPick(Person(text, "", "", currentView, 0))
            return
        }
        if (NameSearch.parse(text).isEmpty) {
            searchRun++
            suggestions = emptyList()
            matches = emptyList()
            searchNote = activity.getString(R.string.find_no_name)
            refresh()
            return
        }
        val run = ++searchRun
        suggestions = emptyList()
        matches = emptyList()
        searchNote = activity.getString(R.string.find_searching)
        refresh()
        list.setSelection(0)
        search(run, text, NameSearch.parse(text), placeDropped = false)
    }

    /**
     * Look [query] up and list the matches. A place is easily misheard or spelled another way, so
     * when nobody matches with it, the search is tried once more without it, and says so.
     */
    private fun search(run: Int, text: String, query: NameSearch, placeDropped: Boolean) {
        store.search(query.text()) { found, total ->
            if (run != searchRun) return@search
            val hasPlace = query.bornPlace.isNotEmpty() || query.diedPlace.isNotEmpty()
            if (found != null && found.isEmpty() && hasPlace) {
                search(run, text, query.copy(bornPlace = "", diedPlace = ""), placeDropped = true)
                return@search
            }
            matches = found.orEmpty().map { it.copy(view = currentView) }
            searchNote = when {
                found == null -> activity.getString(R.string.find_failed)
                found.isEmpty() -> activity.getString(if (query.hasMore || placeDropped) R.string.find_none_more else R.string.find_none, text)
                placeDropped -> activity.getString(R.string.find_any_place)
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
        // A saved person is already listed under Saved, so they are not repeated under Recent.
        val recent = store.recent().filter { it.id.lowercase() !in savedIds }
        rows = buildList {
            if (start != null) {
                val me = store.me()
                if (me != null) {
                    add(heading(activity.getString(R.string.logged_in_as), "me"))
                    if (isOpen("me")) add(Row.Item(me.copy(view = currentView), saved = me.id.lowercase() in savedIds, inSaved = false, match = true))
                } else {
                    // The site ends a login now and then; logging in again is one tap away, and
                    // the phone's password manager can fill the form.
                    add(Row.Big(activity.getString(R.string.log_in_again)) {
                        WikiTreeLogin(activity) { refresh() }.show()
                    })
                }
            }
            if (suggestions.isNotEmpty()) {
                add(Row.Header(activity.getString(R.string.watchlist_suggestions)))
                suggestions.forEach {
                    add(Row.Item(Person(it.id, it.name, listOf(it.dates, it.place).filter(String::isNotBlank).joinToString("  ·  "), currentView, 0), saved = it.id.lowercase() in savedIds, inSaved = false, match = true))
                }
            }
            if (matches.isNotEmpty() || searchNote != null) {
                add(Row.Header(activity.getString(R.string.find_matches)))
                matches.forEach { add(Row.Item(it, saved = it.id.lowercase() in savedIds, inSaved = false, match = true)) }
                searchNote?.let { add(Row.Empty(it)) }
            }
            if (start != null && watchlist != null) addBirthdays(watchlist, savedIds)
            add(heading(activity.getString(R.string.people_saved), "saved", saved.size))
            if (isOpen("saved")) {
                if (saved.isEmpty()) add(Row.Empty(activity.getString(R.string.people_saved_empty)))
                saved.forEach { add(Row.Item(it, saved = true, inSaved = true)) }
            }
            add(heading(activity.getString(R.string.people_recent), "recent", recent.size))
            if (isOpen("recent")) {
                if (recent.isEmpty()) add(Row.Empty(activity.getString(R.string.people_recent_empty)))
                recent.forEach { add(Row.Item(it, saved = it.id.lowercase() in savedIds, inSaved = false)) }
            }
            // The Tree Apps list needs someone to show: the last person, else the member.
            val appsFor = currentId.ifBlank { store.me()?.id ?: "" }
            if (start != null && appsFor.isNotBlank()) {
                add(heading(activity.getString(R.string.start_apps, appsFor), "apps"))
                if (isOpen("apps")) start.apps.forEach { add(Row.App(it.first, it.second)) }
            }
        }
        adapter.notifyDataSetChanged()
        if (::starButton.isInitialized) {
            starButton.text = if (store.isSaved(currentId)) "★  " + activity.getString(R.string.unsave_person, currentId)
            else "☆  " + activity.getString(R.string.save_person, currentId)
        }
    }

    private var allBirthdays = false

    /** Start screen: who on the watchlist was born or died today, then the watchlist and notification lines. */
    private fun MutableList<Row>.addBirthdays(watchlist: WatchlistStore, savedIds: Set<String>) {
        val loaded = watchlist.fetchedAt != 0L
        add(heading(activity.getString(R.string.born_header, Birthdays.dayLabel()), "born", if (loaded) watchlist.anniversaries().size else 0))
        if (!isOpen("born")) return
        if (loaded) {
            val list = watchlist.anniversaries()
            if (list.isEmpty()) add(Row.Empty(activity.getString(R.string.born_nobody)))
            // A long list would push Saved and Recent off the screen, so it starts short.
            val shown = if (allBirthdays || list.size <= BIRTHDAYS_SHOWN + 1) list else Birthdays.pick(list, BIRTHDAYS_SHOWN)
            shown.forEach {
                val person = Person(it.person.id, it.person.name, Birthdays.detail(activity, it), currentView, 0)
                add(Row.Item(person, saved = it.person.id.lowercase() in savedIds, inSaved = false, match = true, birth = it.isBirth))
            }
            if (shown.size < list.size) {
                add(Row.Action(activity.getString(R.string.born_show_all, list.size)) {
                    allBirthdays = true
                    refresh()
                })
            }
        }
        val status = when {
            loadingWatchlist -> activity.getString(R.string.watchlist_loading)
            watchlistNote != null -> watchlistNote!!
            loaded -> activity.getString(
                R.string.watchlist_status, "%,d".format(watchlist.count),
                android.text.format.DateFormat.getMediumDateFormat(activity).format(watchlist.fetchedAt),
            )
            else -> activity.getString(R.string.watchlist_none)
        }
        add(Row.Action(status) { loadWatchlist(watchlist) })
        if (loaded) {
            add(Row.Action(activity.getString(if (watchlist.notify) R.string.notify_on else R.string.notify_off)) {
                if (watchlist.notify) {
                    watchlist.notify = false
                    Birthdays.schedule(activity)
                    refresh()
                } else start?.askToNotify?.invoke { allowed ->
                    watchlist.notify = allowed
                    Birthdays.schedule(activity)
                    refresh()
                }
            })
        }
    }

    /** Fetch the watchlist now. Also used for the weekly refresh when the start screen opens. */
    fun loadWatchlist(watchlist: WatchlistStore, quiet: Boolean = false) {
        if (loadingWatchlist) return
        loadingWatchlist = true
        watchlistNote = null
        refresh()
        watchlist.refresh { result ->
            loadingWatchlist = false
            watchlistNote = when (result) {
                WatchlistStore.Result.OK -> null
                // A weekly refresh that fails keeps quiet: the list from last time still stands.
                else -> if (quiet && watchlist.fetchedAt != 0L) null
                else activity.getString(
                    if (result == WatchlistStore.Result.LOGGED_OUT) R.string.watchlist_logged_out else R.string.watchlist_failed,
                )
            }
            Birthdays.refresh(activity)
            if (dialog.isShowing) refresh()
        }
    }

    private fun profileLink(id: String) = "https://www.wikitree.com/wiki/" + Uri.encode(id)

    /**
     * The long-press menu, as a sheet from the bottom: who the person is, then the Tree Apps used
     * most recently and all of them, the profile, save, share, copy and (Saved, Recent) remove.
     */
    private fun personMenu(row: Row.Item) {
        val p = row.person
        val sheet = Dialog(activity, android.R.style.Theme_Material_Light_Dialog_NoActionBar)
        val content = LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(8), 0, dp(16))
        }
        // The card: name, ID and dates, and why they are notable.
        content.addView(LinearLayout(activity).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(12), dp(20), dp(12))
            addView(TextView(activity).apply {
                text = p.name.ifBlank { p.id }
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(activity.getColor(R.color.text_primary))
            })
            addView(TextView(activity).apply {
                text = listOfNotNull(p.id.takeIf { p.name.isNotBlank() }, p.dates.ifBlank { null }).joinToString("  ·  ")
                visibility = if (text.isBlank()) View.GONE else View.VISIBLE
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setTextColor(activity.getColor(R.color.text_secondary))
            })
            p.notable?.let { n ->
                addView(TextView(activity).apply {
                    text = "✪  " + n.tag.ifBlank { activity.getString(R.string.notable) }
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(activity.getColor(R.color.notable))
                })
                if (n.about.isNotBlank()) addView(TextView(activity).apply {
                    text = n.about
                    maxLines = 6
                    ellipsize = TextUtils.TruncateAt.END
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                    setTextColor(activity.getColor(R.color.text_primary))
                })
            }
        })
        fun divider() = content.addView(View(activity).apply { setBackgroundColor(activity.getColor(R.color.text_secondary)); alpha = 0.3f },
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1)).apply { setMargins(0, dp(4), 0, dp(4)) })
        fun item(text: String, red: Boolean = false, run: () -> Unit) = content.addView(TextView(activity).apply {
            this.text = text
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTextColor(activity.getColor(if (red) R.color.text_error else R.color.text_primary))
            minHeight = dp(48)
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(20), 0, dp(20), 0)
            val ripple = TypedValue()
            activity.theme.resolveAttribute(android.R.attr.selectableItemBackground, ripple, true)
            setBackgroundResource(ripple.resourceId)
            setOnClickListener { sheet.dismiss(); run() }
        })
        fun open(key: String) {
            dialog.dismiss()
            onPick(p.copy(view = key))
        }
        divider()
        val title = { key: String -> apps.firstOrNull { it.first == key }?.second ?: appTitle(key) ?: key }
        recentApps().forEach { key -> item(title(key)) { open(key) } }
        if (apps.isNotEmpty()) item(activity.getString(R.string.menu_all_apps)) {
            AlertDialog.Builder(activity)
                .setTitle(p.name.ifBlank { p.id })
                .setItems(apps.map { it.second }.toTypedArray()) { _, which -> open(apps[which].first) }
                .setNegativeButton(R.string.cancel, null)
                .show()
        }
        divider()
        item(activity.getString(R.string.person_menu_profile)) { openProfile(p.id) }
        item(activity.getString(R.string.menu_read_bio)) { openProfile(p.id, listen = true) }
        item(activity.getString(if (row.saved) R.string.menu_unsave else R.string.menu_save)) {
            store.toggleSaved(p.id, p.view.ifBlank { currentView })
        }
        item(activity.getString(R.string.menu_share_link)) {
            val link = profileLink(p.id)
            val text = if (p.name.isBlank()) link else activity.getString(R.string.menu_share_text, p.name, p.id, link)
            activity.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_SUBJECT, p.name.ifBlank { p.id })
                putExtra(Intent.EXTRA_TEXT, text)
            }, null))
        }
        item(activity.getString(R.string.menu_copy_id)) {
            val clip = activity.getSystemService(ClipboardManager::class.java)
            clip.setPrimaryClip(ClipData.newPlainText("WikiTree ID", p.id))
            // Android 13 and later show their own note when something is copied.
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                Toast.makeText(activity, activity.getString(R.string.menu_copied, p.id), Toast.LENGTH_SHORT).show()
            }
        }
        if (!row.match && !row.inSaved) {
            divider()
            item(activity.getString(R.string.remove_recent), red = true) { store.removeRecent(p.id) }
            item(activity.getString(R.string.clear_recent), red = true) { store.clearRecent() }
        }
        sheet.setContentView(ScrollView(activity).apply { addView(content) })
        sheet.setCanceledOnTouchOutside(true)
        sheet.setOnDismissListener { if (dialog.isShowing) refresh() }
        sheet.window?.apply {
            setGravity(Gravity.BOTTOM)
            setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            setBackgroundDrawable(android.graphics.drawable.GradientDrawable().apply {
                setColor(activity.getColor(R.color.sheet_bg))
                val r = dp(16).toFloat()
                cornerRadii = floatArrayOf(r, r, r, r, 0f, 0f, 0f, 0f)
            })
            setWindowAnimations(android.R.style.Animation_InputMethod)
        }
        sheet.show()
    }

    /** The Tree Apps used most recently, newest first, from the apps the recent people were shown in. */
    private fun recentApps(limit: Int = 3) =
        store.recent().map { it.view }.filter { it.isNotBlank() }.distinct().take(limit)

    /** A profile on www.wikitree.com, over the app and with the member's WikiTree login. */
    private fun openProfile(id: String, listen: Boolean = false) {
        WikiTreeSheet(activity).show(Uri.parse(profileLink(id)), listen)
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
        override fun getViewTypeCount() = 6
        override fun getItemViewType(position: Int) = when (rows[position]) {
            is Row.Header -> 0
            is Row.Item -> 1
            is Row.Empty -> 2
            is Row.App -> 3
            is Row.Action -> 4
            is Row.Big -> 5
        }
        override fun isEnabled(position: Int) = when (val row = rows[position]) {
            is Row.Header -> row.key != null
            is Row.Empty -> false
            else -> true
        }

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View =
            when (val row = rows[position]) {
                is Row.Header -> (convertView as? TextView ?: TextView(activity).apply {
                    setPadding(dp(16), dp(18), dp(16), dp(6))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(activity.getColor(R.color.wt_accent))
                }).apply {
                    // ▾ open, ▸ folded; folded, the heading says how many are inside.
                    val title = row.text.uppercase()
                    text = when {
                        row.key == null -> title
                        row.open -> "▾  $title"
                        row.count > 0 -> "▸  $title (${row.count})"
                        else -> "▸  $title"
                    }
                }

                is Row.Empty -> (convertView as? TextView ?: TextView(activity).apply {
                    setPadding(dp(16), dp(4), dp(16), dp(8))
                    setTextColor(activity.getColor(R.color.text_secondary))
                }).apply { text = row.text }

                is Row.App -> (convertView as? TextView ?: TextView(activity).apply {
                    setPadding(dp(16), dp(12), dp(16), dp(12))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    setTextColor(activity.getColor(R.color.text_primary))
                }).apply {
                    text = if (row.key == currentView) "${row.title}  ✓" else row.title
                }

                is Row.Action -> (convertView as? TextView ?: TextView(activity).apply {
                    setPadding(dp(16), dp(8), dp(16), dp(8))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                    setTextColor(activity.getColor(R.color.wt_accent))
                }).apply { text = row.text }

                is Row.Big -> (convertView as? android.widget.FrameLayout ?: android.widget.FrameLayout(activity).apply {
                    setPadding(dp(12), dp(10), dp(12), dp(6))
                    addView(TextView(activity).apply {
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                        setTypeface(typeface, Typeface.BOLD)
                        setTextColor(activity.getColor(R.color.on_green))
                        gravity = Gravity.CENTER
                        minHeight = dp(52)
                        setPadding(dp(16), dp(10), dp(16), dp(10))
                        background = android.graphics.drawable.GradientDrawable().apply {
                            setColor(activity.getColor(R.color.wt_button))
                            cornerRadius = dp(8).toFloat()
                        }
                        // The row takes the tap, so the list's click works as for the other rows.
                        isClickable = false
                        isFocusable = false
                    }, android.widget.FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
                }).apply { (getChildAt(0) as TextView).text = row.text }

                is Row.Item -> itemView(convertView as? LinearLayout, row)
            }

        private fun itemView(reuse: LinearLayout?, row: Row.Item): View {
            val view = reuse ?: LinearLayout(activity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(8), dp(10), dp(4), dp(10))
                // The person's profile on www.wikitree.com. Its own button, like the star.
                addView(android.widget.FrameLayout(activity).apply {
                    tag = "profile"
                    isFocusable = false
                    addView(ImageView(activity).apply {
                        tag = "profileIcon"
                        setImageResource(R.drawable.ic_shortcut_person)
                        setPadding(dp(8), dp(8), dp(8), dp(8))
                    }, android.widget.FrameLayout.LayoutParams(dp(48), dp(48)))
                    // Anniversaries rows: "b." or "d." in place of the person icon.
                    addView(TextView(activity).apply {
                        tag = "badge"
                        gravity = Gravity.CENTER
                        includeFontPadding = false
                        setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                        setTypeface(typeface, Typeface.BOLD)
                    }, android.widget.FrameLayout.LayoutParams(dp(32), dp(32), Gravity.CENTER))
                }, LinearLayout.LayoutParams(dp(48), dp(48)).apply { marginEnd = dp(4) })
                val texts = LinearLayout(activity).apply { orientation = LinearLayout.VERTICAL }
                texts.addView(TextView(activity).apply {
                    tag = "title"
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                    setTextColor(activity.getColor(R.color.text_primary))
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                })
                texts.addView(TextView(activity).apply {
                    tag = "detail"
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                    setTextColor(activity.getColor(R.color.text_secondary))
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                })
                // Notable search matches: why they are notable, and the Notability text if any.
                texts.addView(TextView(activity).apply {
                    tag = "notable"
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(activity.getColor(R.color.notable))
                    maxLines = 1
                    ellipsize = TextUtils.TruncateAt.END
                })
                texts.addView(TextView(activity).apply {
                    tag = "about"
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                    setTextColor(activity.getColor(R.color.text_primary))
                    maxLines = 4
                    ellipsize = TextUtils.TruncateAt.END
                })
                addView(texts, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
                addView(TextView(activity).apply {
                    tag = "star"
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
                    gravity = Gravity.CENTER
                    setTextColor(activity.getColor(R.color.wt_accent))
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
            view.findViewWithTag<View>("profile").apply {
                contentDescription = activity.getString(R.string.open_profile_of, p.name.ifBlank { p.id })
                setOnClickListener { openProfile(p.id) }
            }
            val birth = row.birth
            view.findViewWithTag<ImageView>("profileIcon").visibility = if (birth == null) View.VISIBLE else View.GONE
            view.findViewWithTag<TextView>("badge").apply {
                visibility = if (birth == null) View.GONE else View.VISIBLE
                if (birth != null) {
                    text = activity.getString(if (birth) R.string.born_badge else R.string.died_badge)
                    setTextColor(activity.getColor(if (birth) R.color.wt_gold else R.color.death_ink))
                    setBackgroundResource(if (birth) R.drawable.widget_badge_birth else R.drawable.widget_badge_death)
                }
            }
            val notable = p.notable
            view.findViewWithTag<TextView>("notable").apply {
                visibility = if (notable == null) View.GONE else View.VISIBLE
                text = notable?.let { "✪  " + it.tag.ifBlank { activity.getString(R.string.notable) } }
            }
            view.findViewWithTag<TextView>("about").apply {
                visibility = if (notable?.about.isNullOrBlank()) View.GONE else View.VISIBLE
                text = notable?.about
            }
            view.setBackgroundColor(if (notable == null) 0 else activity.getColor(R.color.notable_tint))
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
        const val BIRTHDAYS_SHOWN = 3
    }
}
