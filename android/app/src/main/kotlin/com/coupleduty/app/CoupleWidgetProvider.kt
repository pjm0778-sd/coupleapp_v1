package com.coupleduty.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * 커플듀티 홈 위젯 — Small (2×2) + Medium (4×2) 공통 Provider
 *
 * 데이터는 home_widget 패키지가 FlutterSharedPreferences 에 "flutter." 접두사로 저장.
 * Medium 여부는 provider 클래스명에 "Medium" 포함 여부로 판단.
 */
open class CoupleWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val info     = appWidgetManager.getAppWidgetInfo(id)
            val isMedium = info?.provider?.className?.contains("Medium") == true
            updateWidget(context, appWidgetManager, id, isMedium)
        }
    }

    companion object {
        private const val PREFS = "FlutterSharedPreferences"

        fun updateWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            isMedium: Boolean,
        ) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

            // ── 데이터 읽기 ──────────────────────────────────────
            val dDays           = prefs.getLong("flutter.d_days", 0L)
            val partnerName     = prefs.getString("flutter.partner_name",     "애인") ?: "애인"
            val mySchedule      = prefs.getString("flutter.my_schedule",      "여유로운 하루") ?: "여유로운 하루"
            val partnerSchedule = prefs.getString("flutter.partner_schedule", "여유로운 하루") ?: "여유로운 하루"
            val myWeather       = prefs.getString("flutter.my_weather",       "") ?: ""
            val partnerWeather  = prefs.getString("flutter.partner_weather",  "") ?: ""
            val nextDateDays    = prefs.getLong("flutter.next_date_days", -1L)
            val nextDateLabel   = prefs.getString("flutter.next_date_label",  "") ?: ""

            // ── 레이아웃 선택 ────────────────────────────────────
            val layout = if (isMedium) R.layout.widget_medium else R.layout.widget_small
            val views  = RemoteViews(context.packageName, layout)

            // ── Small 전용 ─────────────────────────────────────
            if (!isMedium) {
                views.setTextViewText(R.id.tv_d_days, dDays.toString())
            }

            // ── Medium 헤더 ─────────────────────────────────────
            if (isMedium) {
                val lastChar = partnerName.lastOrNull() ?: ' '
                val postfix = if (lastChar.code in 0xAC00..0xD7A3 && (lastChar.code - 0xAC00) % 28 != 0) "과" else "와"
                views.setTextViewText(R.id.tv_partner_name, "${partnerName}${postfix} 함께한지 D+$dDays")
            }

            // ── 공통 일정 ─────────────────────────────────────
            views.setTextViewText(R.id.tv_my_schedule,      mySchedule)
            views.setTextViewText(R.id.tv_partner_schedule, partnerSchedule)

            // 파트너 라벨: 닉네임 앞 2글자 (공간 제한)
            val shortPartner = if (partnerName.length >= 2) partnerName.take(2) else partnerName
            views.setTextViewText(R.id.tv_partner_label, shortPartner)

            // ── Medium 전용 ─────────────────────────────────────
            if (isMedium) {
                // 날씨
                views.setTextViewText(R.id.tv_my_weather,      myWeather)
                views.setTextViewText(R.id.tv_partner_weather, partnerWeather)

                // 다음 데이트
                if (nextDateDays >= 0L && nextDateLabel.isNotEmpty()) {
                    val dText = when (nextDateDays) {
                        0L   -> "오늘!"
                        else -> "D-$nextDateDays"
                    }
                    views.setTextViewText(R.id.tv_next_date,   "💕 설레는 다음 만남까지")
                    views.setTextViewText(R.id.tv_next_date_d, dText)
                    views.setViewVisibility(R.id.layout_next_date,     View.VISIBLE)
                    views.setViewVisibility(R.id.layout_next_date_row, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.layout_next_date,     View.GONE)
                    views.setViewVisibility(R.id.layout_next_date_row, View.GONE)
                }
            }

            // ── 탭 시 앱 열기 ────────────────────────────────────
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, widgetId, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            manager.updateAppWidget(widgetId, views)
        }
    }
}

