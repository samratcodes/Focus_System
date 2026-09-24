package com.focussystem.focus_system

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Home-screen widget in the style of Google Tasks: today's tasks with
 * checkboxes, a live focus countdown and quick add. Data is written by the
 * Flutter app (lib/services/widget_sync.dart) into HomeWidgetPreferences.
 */
class TasksWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, id, widgetData))
        }
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.task_list)
        scheduleFocusRefresh(context, widgetData)
    }

    private fun buildViews(context: Context, widgetId: Int, prefs: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_tasks)
        val signedIn = prefs.getBoolean("signed_in", false)

        views.setOnClickPendingIntent(R.id.header, launch(context, "focussystem://open"))
        views.setViewVisibility(R.id.signed_out, if (signedIn) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.content, if (signedIn) View.VISIBLE else View.GONE)
        if (!signedIn) {
            views.setOnClickPendingIntent(R.id.signed_out, launch(context, "focussystem://open"))
            return views
        }

        // Header: date + progress
        val (done, total) = counts(prefs.getString("tasks_json", "[]") ?: "[]")
        views.setTextViewText(R.id.date_label, prefs.getString("date_label", "") ?: "")
        views.setTextViewText(R.id.count_label, "$done/$total")
        views.setProgressBar(R.id.progress, 100, if (total == 0) 0 else done * 100 / total, false)
        views.setOnClickPendingIntent(R.id.btn_add, launch(context, "focussystem://add"))
        views.setOnClickPendingIntent(
            R.id.btn_refresh,
            HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("focussystem://refresh")),
        )

        // Focus strip: live countdown via Chronometer (no app process needed while it ticks)
        val running = prefs.getBoolean("focus_running", false)
        val endsAt = prefs.getString("focus_ends_at", "0")?.toLongOrNull() ?: 0L
        val remaining = endsAt - System.currentTimeMillis()
        val label = prefs.getString("focus_label", "FOCUS") ?: "FOCUS"
        val task = prefs.getString("focus_task", "") ?: ""
        views.setTextViewText(R.id.focus_label, label)
        views.setTextColor(
            R.id.focus_label,
            context.getColor(if (label == "FOCUS") R.color.fs_primary else R.color.fs_success),
        )
        views.setTextViewText(R.id.focus_task, if (task.isEmpty()) "Deep work session" else task)
        if (running && remaining > 0) {
            views.setViewVisibility(R.id.focus_chrono, View.VISIBLE)
            views.setViewVisibility(R.id.focus_static, View.GONE)
            views.setChronometerCountDown(R.id.focus_chrono, true)
            views.setChronometer(R.id.focus_chrono, SystemClock.elapsedRealtime() + remaining, null, true)
            views.setImageViewResource(R.id.btn_focus, R.drawable.ic_widget_pause)
            views.setOnClickPendingIntent(
                R.id.btn_focus,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("focussystem://focus?action=pause")),
            )
        } else {
            views.setViewVisibility(R.id.focus_chrono, View.GONE)
            views.setViewVisibility(R.id.focus_static, View.VISIBLE)
            views.setTextViewText(
                R.id.focus_static,
                if (running) "00:00" else (prefs.getString("focus_paused_clock", "25:00") ?: "25:00"),
            )
            views.setImageViewResource(R.id.btn_focus, R.drawable.ic_widget_play)
            views.setOnClickPendingIntent(
                R.id.btn_focus,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("focussystem://focus?action=start")),
            )
        }
        views.setOnClickPendingIntent(R.id.focus_strip, launch(context, "focussystem://focus"))

        // Task list (collection): rows are rendered by TasksWidgetService.
        val serviceIntent = Intent(context, TasksWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        @Suppress("DEPRECATION")
        views.setRemoteAdapter(R.id.task_list, serviceIntent)
        views.setEmptyView(R.id.task_list, R.id.empty_view)
        views.setOnClickPendingIntent(R.id.empty_view, launch(context, "focussystem://add"))
        // One template for all rows; each row fills in its own data URI.
        val template = PendingIntent.getActivity(
            context,
            42,
            Intent(context, WidgetActionActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        views.setPendingIntentTemplate(R.id.task_list, template)
        return views
    }

    private fun launch(context: Context, uri: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

    /**
     * When the current focus phase ends, ask Dart to fetch the next phase from the
     * server so the widget keeps counting down without the app being opened.
     */
    private fun scheduleFocusRefresh(context: Context, data: SharedPreferences) {
        val alarm = context.getSystemService(AlarmManager::class.java) ?: return
        val pending = HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("focussystem://refresh?phase=1"))
        alarm.cancel(pending)
        val endsAt = data.getString("focus_ends_at", "0")?.toLongOrNull() ?: 0L
        if (data.getBoolean("focus_running", false) && endsAt > System.currentTimeMillis()) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC, endsAt + 3_000, pending)
        }
    }

    companion object {
        fun counts(json: String): Pair<Int, Int> = try {
            val arr = JSONArray(json)
            var done = 0
            for (i in 0 until arr.length()) if (arr.getJSONObject(i).optBoolean("completed")) done++
            Pair(done, arr.length())
        } catch (_: Exception) {
            Pair(0, 0)
        }

        /** Re-render every placed widget from the cached data. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TasksWidgetProvider::class.java))
            if (ids.isEmpty()) return
            TasksWidgetProvider().onUpdate(context, manager, ids, HomeWidgetPlugin.getData(context))
        }
    }
}
