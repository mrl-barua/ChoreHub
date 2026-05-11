package com.chorehub.mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ChoresWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val streak = widgetData.getString("streak", "0") ?: "0"
            val views = RemoteViews(context.packageName, R.layout.widget_chores)
            views.setTextViewText(R.id.tv_header, "Today's Chores · 🔥 $streak day streak")

            // Progression streak row (Kid Motivation Loop). Hidden when missing
            // or zero so we don't surface "🔥 0" noise.
            val progressionStreak =
                widgetData.getString("progression_streak", "0")?.toIntOrNull() ?: 0
            if (progressionStreak > 0) {
                views.setTextViewText(R.id.streak_text, "🔥 $progressionStreak")
                views.setViewVisibility(R.id.streak_text, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.streak_text, View.GONE)
            }

            val intent = Intent(context, ChoresWidgetService::class.java)
            views.setRemoteAdapter(R.id.chores_list, intent)
            views.setEmptyView(R.id.chores_list, R.id.tv_empty)

            // Tap on header → open dashboard
            val headerIntent = es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java,
                android.net.Uri.parse("chorehub://widget?route=/dashboard")
            )
            views.setOnClickPendingIntent(R.id.tv_header, headerIntent)

            // Tap on "+ Add Chore" footer
            val addIntent = es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java,
                android.net.Uri.parse("chorehub://widget?action=create")
            )
            views.setOnClickPendingIntent(R.id.btn_add_chore, addIntent)

            // Tap template for list items (handled per-row in factory)
            val listItemIntent = Intent(context, MainActivity::class.java)
            val pendingTemplate = android.app.PendingIntent.getActivity(
                context, 0, listItemIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.chores_list, pendingTemplate)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
