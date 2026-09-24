package com.focussystem.focus_system

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/**
 * Invisible trampoline for taps inside the widget's task list. A collection can
 * only have one click template, so both kinds of tap come here:
 *   focussystem://toggle?id=..&completed=..  → tick instantly, sync in background
 *   focussystem://task?id=..                  → open the app on that task
 */
class WidgetActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = intent?.data
        when (uri?.host) {
            "toggle" -> {
                val id = uri.getQueryParameter("id")
                val completed = uri.getQueryParameter("completed") == "true"
                if (id != null) markLocally(id, completed)
                // Dart (widgetBackgroundCallback) calls the API and refreshes the widget.
                runCatching { HomeWidgetBackgroundIntent.getBroadcast(this, uri).send() }
            }
            null -> {}
            else -> startActivity(
                Intent(this, MainActivity::class.java).apply {
                    action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                    data = uri
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
            )
        }
        finish()
        if (Build.VERSION.SDK_INT >= 34) {
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }

    /** Optimistic update so the checkbox flips immediately. */
    private fun markLocally(id: String, completed: Boolean) {
        val prefs = HomeWidgetPlugin.getData(this)
        val arr = runCatching { JSONArray(prefs.getString("tasks_json", "[]")) }.getOrNull() ?: return
        for (i in 0 until arr.length()) {
            val t = arr.getJSONObject(i)
            if (t.optString("id") == id) {
                t.put("completed", completed)
                if (completed) t.put("priority", false)
            }
        }
        prefs.edit().putString("tasks_json", arr.toString()).apply()
        TasksWidgetProvider.refreshAll(this)
    }
}
