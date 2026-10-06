package com.wiozen.goodnight

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget showing the latest selfie from your partner. */
class SelfieWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val path = widgetData.getString("selfie_path", null)
        val caption = widgetData.getString("selfie_caption", null) ?: "No selfie yet"
        val bitmap = path?.let { decodeScaled(it, MAX_SIDE) }

        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.selfie_widget)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.selfie_image, bitmap)
            } else {
                views.setImageViewResource(R.id.selfie_image, R.mipmap.ic_launcher)
            }
            views.setTextViewText(R.id.selfie_caption, caption)
            views.setOnClickPendingIntent(R.id.selfie_root, open)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** Decodes a downscaled copy so the widget stays under the binder size limit. */
    private fun decodeScaled(path: String, maxSide: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > maxSide * 2) sample *= 2
        return BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
    }

    companion object {
        private const val MAX_SIDE = 480
    }
}
