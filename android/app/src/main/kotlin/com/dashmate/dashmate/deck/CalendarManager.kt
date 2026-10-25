package com.dashmate.dashmate.deck

import android.Manifest
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

    /**
     * Returns `{ "access": Boolean, "events": [ {title, begin, end, where, allDay, color} ] }`
     * for calendar instances in the next 7 days (max 40).
     */
    // RECONSTRUCTED: jadx failed on this method; rebuilt from --show-bad-code output
    // (inverted conditions in the bad output were corrected).
    fun getUpcomingEvents(context: Context): JSONObject {
        val root = JSONObject()
        val hasPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.READ_CALENDAR
        ) == PackageManager.PERMISSION_GRANTED
        root.put("access", hasPermission)
        val eventsArray = JSONArray()

        if (!hasPermission) {
            root.put("events", eventsArray)
            return root
        }

        try {
            val now = System.currentTimeMillis()
            val endRange = now + 7L * 24 * 60 * 60 * 1000 // 604800000
            val builder = CalendarContract.Instances.CONTENT_URI.buildUpon()
            ContentUris.appendId(builder, now)
            ContentUris.appendId(builder, endRange)

            val projection = arrayOf(
                "title", "begin", "end", "eventLocation", "allDay", "displayColor"
            )
            val cursor = context.contentResolver.query(
                builder.build(), projection, null, null, "begin ASC"
            )
            cursor?.use { c ->
                val titleIdx = c.getColumnIndex("title")
                val beginIdx = c.getColumnIndex("begin")
                val endIdx = c.getColumnIndex("end")
                val locIdx = c.getColumnIndex("eventLocation")
                val allDayIdx = c.getColumnIndex("allDay")
                val colorIdx = c.getColumnIndex("displayColor")

                while (c.moveToNext()) {
                    if (eventsArray.length() >= 40) break

                    val title: String? = if (titleIdx >= 0) c.getString(titleIdx) else "Event"
                    val begin = if (beginIdx >= 0) c.getLong(beginIdx) else now
                    val end = if (endIdx >= 0) c.getLong(endIdx) else begin + 3600000L
                    val where = if (locIdx >= 0) c.getString(locIdx) ?: "" else ""
                    val allDay = allDayIdx >= 0 && c.getInt(allDayIdx) == 1
                    val colorInt = if (colorIdx >= 0) c.getInt(colorIdx) else 0x5EF3D6
                    val color = String.format("#%06X", colorInt and 0xFFFFFF)

                    val ev = JSONObject()
                    ev.put("title", title ?: "Event")
                    ev.put("begin", begin)
                    ev.put("end", end)
                    ev.put("where", where)
                    ev.put("allDay", allDay)
                    ev.put("color", color)
                    eventsArray.put(ev)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error querying calendar events: " + e.message)
        }

        root.put("events", eventsArray)
        return root
    }
}
