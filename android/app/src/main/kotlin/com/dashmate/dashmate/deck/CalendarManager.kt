package com.dashmate.dashmate.deck

import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import android.util.Log
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

object CalendarManager {
    private const val TAG = "CalendarManager"

    fun getUpcomingEvents(context: Context): JSONObject {
        val result = JSONObject()
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.READ_CALENDAR
        ) == PackageManager.PERMISSION_GRANTED

        result.put("access", hasPermission)

        val eventsArray = JSONArray()
        if (!hasPermission) {
            result.put("events", eventsArray)
            return result
        }

        try {
            val now = System.currentTimeMillis()
            val endRange = now + (7 * 24 * 60 * 60 * 1000L) // 7 days ahead

            val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
            ContentUris.appendId(builder, now)
            ContentUris.appendId(builder, endRange)

            val projection = arrayOf(
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.END,
                CalendarContract.Instances.EVENT_LOCATION,
                CalendarContract.Instances.ALL_DAY,
                CalendarContract.Instances.DISPLAY_COLOR
            )

            val cursor = context.contentResolver.query(
                builder.build(),
                projection,
                null,
                null,
                "${CalendarContract.Instances.BEGIN} ASC"
            )

            cursor?.use {
                val titleIdx = it.getColumnIndex(CalendarContract.Instances.TITLE)
                val beginIdx = it.getColumnIndex(CalendarContract.Instances.BEGIN)
                val endIdx = it.getColumnIndex(CalendarContract.Instances.END)
                val locIdx = it.getColumnIndex(CalendarContract.Instances.EVENT_LOCATION)
                val allDayIdx = it.getColumnIndex(CalendarContract.Instances.ALL_DAY)
                val colorIdx = it.getColumnIndex(CalendarContract.Instances.DISPLAY_COLOR)

                while (it.moveToNext() && eventsArray.length() < 40) {
                    val title = if (titleIdx >= 0) it.getString(titleIdx) else "Event"
                    val begin = if (beginIdx >= 0) it.getLong(beginIdx) else now
                    val end = if (endIdx >= 0) it.getLong(endIdx) else (begin + 3600000L)
                    val loc = if (locIdx >= 0) it.getString(locIdx) ?: "" else ""
                    val allDay = if (allDayIdx >= 0) it.getInt(allDayIdx) == 1 else false
                    val colorInt = if (colorIdx >= 0) it.getInt(colorIdx) else 0x5EF2D6
                    val hexColor = String.format("#%06X", 0xFFFFFF and colorInt)

                    val evObj = JSONObject().apply {
                        put("title", title ?: "Event")
                        put("begin", begin)
                        put("end", end)
                        put("where", loc)
                        put("allDay", allDay)
                        put("color", hexColor)
                    }
                    eventsArray.put(evObj)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error querying calendar events: ${e.message}")
        }

        result.put("events", eventsArray)
        return result
    }
}
