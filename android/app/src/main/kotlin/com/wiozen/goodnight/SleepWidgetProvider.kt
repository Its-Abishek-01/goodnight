package com.wiozen.goodnight

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * "Going to sleep" home-screen widget: you and your partner, and a button
 * that opens the app and checks you in. The texts come from the Flutter side
 * (lib/features/sleep_widget/sleep_widget.dart).
 */
class SleepWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val open = PendingIntent.getActivity(
            context,
            1,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val checkIn = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("goodnight://checkin"),
        )
        val canCheckIn = widgetData.getBoolean("sleep_can", false)
        val label = widgetData.getString("sleep_button", null) ?: "Going to sleep"

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.sleep_widget)
            person(views, widgetData, "me", R.id.sleep_me_dot, R.id.sleep_me_initial,
                R.id.sleep_me_line, "You", SKY, SKY_ON)
            person(views, widgetData, "partner", R.id.sleep_partner_dot, R.id.sleep_partner_initial,
                R.id.sleep_partner_line, "Open GoodNight to set up", ROSE, ROSE_ON)

            views.setTextViewText(R.id.sleep_button, if (canCheckIn) "🌙  $label" else label)
            views.setInt(
                R.id.sleep_button,
                "setBackgroundResource",
                if (canCheckIn) R.drawable.sleep_widget_button else R.drawable.sleep_widget_button_off,
            )
            views.setTextColor(R.id.sleep_button, if (canCheckIn) ON_GOLD else MUTED)
            views.setOnClickPendingIntent(R.id.sleep_button, if (canCheckIn) checkIn else open)
            views.setOnClickPendingIntent(R.id.sleep_root, open)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun person(
        views: RemoteViews,
        data: SharedPreferences,
        key: String,
        dot: Int,
        initial: Int,
        line: Int,
        fallback: String,
        color: Int,
        onColor: Int,
    ) {
        views.setInt(dot, "setColorFilter", data.getInt("sleep_${key}_color", color))
        views.setTextViewText(initial, data.getString("sleep_${key}_initial", null) ?: "")
        views.setTextColor(initial, data.getInt("sleep_${key}_on", onColor))
        views.setTextViewText(line, data.getString("sleep_$key", null) ?: fallback)
    }

    companion object {
        // PartnerColor.sky and .rose, the defaults before the app has synced.
        private const val SKY = 0xFF7FB2F0.toInt()
        private const val SKY_ON = 0xFF0C2A55.toInt()
        private const val ROSE = 0xFFF4A6C6.toInt()
        private const val ROSE_ON = 0xFF5A1534.toInt()
        private const val ON_GOLD = 0xFF3D2600.toInt()
        private const val MUTED = 0xFFA9A3DD.toInt()
    }
}
