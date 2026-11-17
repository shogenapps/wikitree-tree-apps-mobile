package org.wikitree.treeapps

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Anniversaries (births and deaths on this day): the home-screen widget and the optional morning
 * notification. Both read
 * the watchlist kept on the phone ([WatchlistStore]); neither goes online.
 *
 * The widget is redrawn just after midnight and the notification is posted in the morning, each
 * by an alarm that sets itself again for the next day. Android also calls in after a restart
 * and when the clock or time zone changes.
 */
class BirthdayWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Birthdays.draw(context, manager, ids)
        Birthdays.schedule(context)
    }

    /** Resized: as many rows as fit. */
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: android.os.Bundle) {
        Birthdays.draw(context, manager, intArrayOf(id))
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            Birthdays.ACTION_MIDNIGHT, Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
            -> Birthdays.refresh(context)
            Birthdays.ACTION_MORNING -> {
                Birthdays.announce(context)
                Birthdays.refresh(context)
            }
        }
    }
}

object Birthdays {
    const val ACTION_MIDNIGHT = "org.wikitree.treeapps.BIRTHDAYS_MIDNIGHT"
    const val ACTION_MORNING = "org.wikitree.treeapps.BIRTHDAYS_MORNING"
    private const val CHANNEL = "birthdays"
    private const val MORNING_HOUR = 8

    /** "born 1841 · 185 years ago" or "died 1902 · 124 years ago" */
    fun detail(context: Context, item: Anniversary, today: Calendar = Calendar.getInstance()): String {
        val years = item.years(today)
        val res = context.resources
        return when {
            years <= 0 -> context.getString(if (item.isBirth) R.string.born_in else R.string.died_in, item.year)
            item.isBirth -> res.getQuantityString(R.plurals.born_years_ago, years, item.year, years)
            else -> res.getQuantityString(R.plurals.died_years_ago, years, item.year, years)
        }
    }

    /**
     * The first [count] to show when not all fit: oldest first, but with at least one birth and one
     * death when the day has both, so deaths are not all hidden behind "and N more".
     */
    fun pick(list: List<Anniversary>, count: Int): List<Anniversary> {
        if (count <= 0 || list.size <= count) return list
        val shown = list.take(count).toMutableList()
        for (birth in listOf(true, false)) {
            if (count < 2 || shown.any { it.isBirth == birth }) continue
            list.firstOrNull { it.isBirth == birth }?.let { shown[count - 1] = it }
        }
        return shown.sortedWith(compareBy({ it.year }, { if (it.isBirth) 0 else 1 }))
    }

    /** "3 births · 2 deaths" */
    fun summary(context: Context, list: List<Anniversary>): String {
        val births = list.count { it.isBirth }
        val deaths = list.size - births
        val res = context.resources
        return listOfNotNull(
            if (births > 0) res.getQuantityString(R.plurals.count_births, births, births) else null,
            if (deaths > 0) res.getQuantityString(R.plurals.count_deaths, deaths, deaths) else null,
        ).joinToString(" · ")
    }

    /** Today as "15 November" (or "November 15"), in the phone's own style. */
    fun dayLabel(): String {
        val pattern = android.text.format.DateFormat.getBestDateTimePattern(Locale.getDefault(), "dMMMM")
        return SimpleDateFormat(pattern, Locale.getDefault()).format(Date())
    }

    /** Redraw every widget and set the alarms again. Call after the watchlist changes. */
    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        draw(context, manager, manager.getAppWidgetIds(ComponentName(context, BirthdayWidget::class.java)))
        schedule(context)
    }

    fun draw(context: Context, manager: AppWidgetManager, ids: IntArray) {
        if (ids.isEmpty()) return
        val store = WatchlistStore(context)
        val list = if (store.fetchedAt == 0L) emptyList() else store.anniversaries()
        val today = Calendar.getInstance()
        val month = SimpleDateFormat("MMM", Locale.getDefault()).format(today.time).uppercase(Locale.getDefault())
        for (id in ids) {
            // Portrait size: the narrowest width and the tallest height.
            val options = manager.getAppWidgetOptions(id)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 110)
            val narrow = width < 200
            // 14dp padding twice, 46dp of header, then 26dp rows.
            val fits = ((height - 28 - 46) / 26).coerceIn(1, 12)
            val views = RemoteViews(context.packageName, R.layout.widget_birthdays).apply {
                setTextViewText(R.id.widget_month, month)
                setTextViewText(R.id.widget_day, today.get(Calendar.DAY_OF_MONTH).toString())
                setTextViewText(R.id.widget_summary, when {
                    list.isEmpty() -> dayLabel()
                    narrow -> context.getString(R.string.count_today, list.size)
                    else -> summary(context, list)
                })
                setOnClickPendingIntent(R.id.widget_root, openApp(context))
                removeAllViews(R.id.widget_rows)
                val empty = when {
                    store.fetchedAt == 0L -> context.getString(R.string.widget_no_watchlist)
                    list.isEmpty() -> context.getString(R.string.born_widget_nobody)
                    else -> null
                }
                setViewVisibility(R.id.widget_empty, if (empty == null) android.view.View.GONE else android.view.View.VISIBLE)
                setTextViewText(R.id.widget_empty, empty ?: "")
                // The last row makes way for "and N more" when the list is longer than the widget.
                val shown = if (list.size > fits) fits - 1 else list.size
                pick(list, shown).forEach { addView(R.id.widget_rows, row(context, it, today, narrow)) }
                if (shown < list.size) {
                    addView(R.id.widget_rows, RemoteViews(context.packageName, R.layout.widget_more).apply {
                        setTextViewText(R.id.more_text, context.getString(R.string.born_more, list.size - shown))
                    })
                }
            }
            manager.updateAppWidget(id, views)
        }
    }

    private fun row(context: Context, item: Anniversary, today: Calendar, narrow: Boolean) =
        RemoteViews(context.packageName, R.layout.widget_anniversary_row).apply {
            setTextViewText(R.id.row_badge, context.getString(if (item.isBirth) R.string.born_badge else R.string.died_badge))
            setContentDescription(R.id.row_badge, context.getString(if (item.isBirth) R.string.born_label else R.string.died_label))
            setInt(R.id.row_badge, "setBackgroundResource",
                if (item.isBirth) R.drawable.widget_badge_birth else R.drawable.widget_badge_death)
            setTextColor(R.id.row_badge, context.getColor(if (item.isBirth) R.color.wt_gold else R.color.death_ink))
            setTextViewText(R.id.row_name, item.person.name)
            setTextViewText(R.id.row_year, item.year.toString())
            val years = item.years(today)
            val milestone = item.isMilestone(today)
            setTextViewText(R.id.row_years, context.getString(R.string.years_chip, years))
            setInt(R.id.row_years, "setBackgroundResource",
                if (milestone) R.drawable.widget_chip_milestone else R.drawable.widget_chip)
            setTextColor(R.id.row_years, context.getColor(if (milestone) R.color.wt_green else R.color.muted_ink))
            if (narrow || years <= 0) {
                setViewVisibility(R.id.row_years, android.view.View.GONE)
            }
            if (narrow) setViewVisibility(R.id.row_year, android.view.View.GONE)
        }

    /** The morning notification, if it is switched on and there is an anniversary today. */
    fun announce(context: Context) {
        val store = WatchlistStore(context)
        if (!store.notify) return
        val list = store.anniversaries()
        if (list.isEmpty()) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (!manager.areNotificationsEnabled()) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, context.getString(R.string.born_title), NotificationManager.IMPORTANCE_LOW),
        )
        val names = list.take(3).joinToString(", ") {
            "${it.person.name} (${context.getString(if (it.isBirth) R.string.born_badge else R.string.died_badge)} ${it.year})"
        } + if (list.size > 3) " " + context.getString(R.string.born_more, list.size - 3) else ""
        val notification = android.app.Notification.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_notify_person)
            .setColor(context.getColor(R.color.wt_green))
            .setContentTitle(context.getString(R.string.born_title) + ": " + summary(context, list))
            .setContentText(names)
            .setStyle(android.app.Notification.BigTextStyle().bigText(names))
            .setContentIntent(openApp(context))
            .setAutoCancel(true)
            .build()
        manager.notify(1, notification)
    }

    /** Set both daily alarms for their next time. Inexact alarms need no permission. */
    fun schedule(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        fun next(hour: Int, minute: Int) = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour); set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }.timeInMillis
        alarms.set(AlarmManager.RTC, next(0, 1), broadcast(context, ACTION_MIDNIGHT, 1))
        val morning = broadcast(context, ACTION_MORNING, 2)
        if (WatchlistStore(context).notify) alarms.set(AlarmManager.RTC_WAKEUP, next(MORNING_HOUR, 0), morning)
        else alarms.cancel(morning)
    }

    private fun broadcast(context: Context, action: String, code: Int) = PendingIntent.getBroadcast(
        context, code, Intent(context, BirthdayWidget::class.java).setAction(action),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun openApp(context: Context) = PendingIntent.getActivity(
        context, 0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
