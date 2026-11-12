package com.example.simulated_application

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class NativeTrackerService : Service() {

    companion object {
        const val CHANNEL_ID = "app_tracker_monitoring_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_BATTERY_UPDATE = "com.example.simulated_application.BATTERY_UPDATE"
        const val EXTRA_BATTERY_PERCENT = "battery_percent"
        const val EXTRA_IS_CHARGING = "is_charging"

        var currentBatteryPercent: Double = 100.0
            private set
        var isCurrentlyCharging: Boolean = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, NativeTrackerService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, NativeTrackerService::class.java)
            context.stopService(intent)
        }
    }

    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_BATTERY_CHANGED) {
                val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)

                if (level != -1 && scale > 0) {
                    currentBatteryPercent = (level.toDouble() / scale.toDouble()) * 100.0
                }

                isCurrentlyCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL

                val updateIntent = Intent(ACTION_BATTERY_UPDATE).apply {
                    putExtra(EXTRA_BATTERY_PERCENT, currentBatteryPercent)
                    putExtra(EXTRA_IS_CHARGING, isCurrentlyCharging)
                    setPackage(packageName)
                }
                sendBroadcast(updateIntent)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification("Active battery & app usage tracking active"))

        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        registerReceiver(batteryReceiver, filter)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(batteryReceiver)
        } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Tracker & Battery Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors background battery drain and idle app status"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App Tracker Service")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
