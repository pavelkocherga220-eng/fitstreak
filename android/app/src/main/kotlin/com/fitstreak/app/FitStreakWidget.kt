package com.fitstreak.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class FitStreakWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            val imagePath = widgetData.getString("widget_image", null)

            if (imagePath != null) {
                val imageFile = File(imagePath)
                if (imageFile.exists()) {
                    try {
                        val authority = "${context.packageName}.fileprovider"
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            context, authority, imageFile
                        )
                        views.setImageViewUri(R.id.widget_image, uri)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}