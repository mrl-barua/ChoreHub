package com.chorehub.mobile

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class ChoresWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        ChoresRemoteViewsFactory(applicationContext)
}

class ChoresRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val chores = mutableListOf<ChoreRow>()

    data class ChoreRow(val id: String, val title: String, val dueTime: String, val priority: String)

    override fun onCreate() {}
    override fun onDestroy() {}

    override fun onDataSetChanged() {
        chores.clear()
        try {
            val raw = HomeWidgetPlugin.getData(context).getString("chores_today", "[]")
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                chores.add(
                    ChoreRow(
                        id = obj.optString("id", ""),
                        title = obj.optString("title", ""),
                        dueTime = obj.optString("dueTime", ""),
                        priority = obj.optString("priority", "low")
                    )
                )
            }
        } catch (_: Exception) {}
    }

    override fun getCount() = chores.size
    override fun hasStableIds() = true
    override fun getItemId(position: Int) = position.toLong()
    override fun getViewTypeCount() = 1
    override fun getLoadingView(): RemoteViews? = null

    override fun getView(position: Int, convertView: RemoteViews?, parent: android.widget.AdapterView<*>?): RemoteViews {
        val row = chores.getOrNull(position) ?: return RemoteViews(context.packageName, R.layout.widget_chore_row)
        val views = RemoteViews(context.packageName, R.layout.widget_chore_row)
        views.setTextViewText(R.id.tv_chore_title, row.title)
        views.setTextViewText(R.id.tv_chore_due, row.dueTime)

        val dotColor = when (row.priority) {
            "high" -> android.graphics.Color.parseColor("#FF453A")
            "medium" -> android.graphics.Color.parseColor("#FF9F0A")
            else -> android.graphics.Color.parseColor("#34C759")
        }
        views.setInt(R.id.priority_dot, "setColorFilter", dotColor)

        val fillIntent = Intent().apply {
            data = android.net.Uri.parse("chorehub://widget?choreId=${row.id}")
        }
        views.setOnClickFillInIntent(R.id.root_row, fillIntent)
        return views
    }
}
