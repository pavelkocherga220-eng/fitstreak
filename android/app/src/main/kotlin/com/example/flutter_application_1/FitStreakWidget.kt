package com.example.flutter_application_1

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
            // Берем НОВЫЙ макет (widget_layout)
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            
            // Достаем путь к картинке
            val imagePath = widgetData.getString("widget_image", null)
            
            if (imagePath != null) {
                val imageFile = File(imagePath)
                if (imageFile.exists()) {
                    try {
                        val authority = "${context.packageName}.fileprovider"
                        val uri = androidx.core.content.FileProvider.getUriForFile(context, authority, imageFile)
                        views.setImageViewUri(R.id.widget_image, uri)
                    } catch (e: Exception) {
                        // Логируем ошибку, чтобы понять, что не так
                        e.printStackTrace()
                    }
                }
            }
            
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}