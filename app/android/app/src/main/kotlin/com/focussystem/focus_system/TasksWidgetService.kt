package com.focussystem.focus_system

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

/** Supplies the rows of the widget's task list. */
class TasksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = TasksFactory(applicationContext)
}

private class TasksFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var tasks: List<JSONObject> = emptyList()

    override fun onCreate() {}
    override fun onDestroy() {}

    override fun onDataSetChanged() {
        val raw = HomeWidgetPlugin.getData(context).getString("tasks_json", "[]") ?: "[]"
        tasks = try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getJSONObject(it) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    override fun getCount() = tasks.size
    override fun getViewTypeCount() = 1
    override fun hasStableIds() = true
    override fun getLoadingView(): RemoteViews? = null
    override fun getItemId(position: Int) = tasks.getOrNull(position)?.optString("id")?.hashCode()?.toLong() ?: position.toLong()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_task_item)
        val t = tasks.getOrNull(position) ?: return views
        val id = t.optString("id")
        val completed = t.optBoolean("completed")
        val priority = t.optBoolean("priority")

        views.setTextViewText(R.id.item_title, t.optString("title"))
        views.setInt(
            R.id.item_title,
            "setPaintFlags",
            if (completed) Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG else Paint.ANTI_ALIAS_FLAG,
        )
        views.setTextColor(
            R.id.item_title,
            context.getColor(if (completed) R.color.fs_text_muted else R.color.fs_text),
        )
        views.setImageViewResource(
            R.id.item_check,
            when {
                completed -> R.drawable.ic_widget_checked
                priority -> R.drawable.ic_widget_circle_priority
                else -> R.drawable.ic_widget_circle
            },
        )

        // Meta line: "PRIORITY · 09:00 · Work · 1/3"
        val meta = buildList {
            if (priority && !completed) add("Priority")
            t.optString("time").takeIf { it.isNotEmpty() }?.let { add(it) }
            t.optString("goal").takeIf { it.isNotEmpty() }?.let { add(it) }
            t.optString("subtasks").takeIf { it.isNotEmpty() }?.let { add("☑ $it") }
        }.joinToString(" · ")
        views.setViewVisibility(R.id.item_meta, if (meta.isEmpty()) View.GONE else View.VISIBLE)
        views.setTextViewText(R.id.item_meta, meta)
        views.setTextColor(
            R.id.item_meta,
            if (priority && !completed) context.getColor(R.color.fs_frog) else context.getColor(R.color.fs_text_muted),
        )
        val goalColor = t.optString("color")
        views.setViewVisibility(R.id.item_goal_dot, if (goalColor.isEmpty()) View.GONE else View.VISIBLE)
        if (goalColor.isNotEmpty()) {
            runCatching { views.setInt(R.id.item_goal_dot, "setColorFilter", Color.parseColor(goalColor)) }
        }

        views.setOnClickFillInIntent(
            R.id.item_check,
            Intent().setData(Uri.parse("focussystem://toggle?id=${Uri.encode(id)}&completed=${!completed}")),
        )
        views.setOnClickFillInIntent(
            R.id.item_body,
            Intent().setData(Uri.parse("focussystem://task?id=${Uri.encode(id)}")),
        )
        return views
    }
}
