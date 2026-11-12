package com.example.simulated_application

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.BatteryManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.simulated_application/tracker"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsagePermission" -> {
                    openUsageAccessSettings()
                    result.success(true)
                }
                "startTrackerService" -> {
                    NativeTrackerService.start(this)
                    result.success(true)
                }
                "stopTrackerService" -> {
                    NativeTrackerService.stop(this)
                    result.success(true)
                }
                "getBatteryStatus" -> {
                    result.success(getDeviceBatteryStatus())
                }
                "getAppsUsageStats" -> {
                    val daysBack = call.argument<Int>("daysBack") ?: 7
                    try {
                        val stats = getAppsUsageStats(daysBack)
                        result.success(stats)
                    } catch (e: Exception) {
                        result.error("USAGE_STATS_ERROR", e.localizedMessage, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun getDeviceBatteryStatus(): Map<String, Any> {
        val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val isCharging = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val status = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS)
            status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        } else {
            false
        }

        return mapOf(
            "batteryPercent" to (if (level >= 0) level.toDouble() else NativeTrackerService.currentBatteryPercent),
            "isCharging" to isCharging
        )
    }

    private fun getAppsUsageStats(daysBack: Int): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm = packageManager
        val now = System.currentTimeMillis()

        val calendar = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, -daysBack)
        }
        val startTime = calendar.timeInMillis

        val usageStatsList = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            now
        ) ?: emptyList()

        // Aggregate by package name to get the latest lastTimeUsed and sum of totalVisibleTime
        val aggregatedStats = mutableMapOf<String, AggregatedUsage>()
        var totalForegroundTimeAllApps = 0L

        for (stat in usageStatsList) {
            val pkg = stat.packageName
            val lastUsed = stat.lastTimeUsed
            val totalTime = stat.totalTimeInForeground

            val current = aggregatedStats[pkg]
            if (current == null) {
                aggregatedStats[pkg] = AggregatedUsage(
                    packageName = pkg,
                    lastTimeUsed = lastUsed,
                    totalTimeInForeground = totalTime
                )
            } else {
                current.totalTimeInForeground += totalTime
                if (lastUsed > current.lastTimeUsed) {
                    current.lastTimeUsed = lastUsed
                }
            }
            totalForegroundTimeAllApps += totalTime
        }

        val resultList = mutableListOf<Map<String, Any>>()

        for ((pkgName, usage) in aggregatedStats) {
            val appInfo: ApplicationInfo? = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getApplicationInfo(pkgName, PackageManager.ApplicationInfoFlags.of(0))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getApplicationInfo(pkgName, 0)
                }
            } catch (_: PackageManager.NameNotFoundException) {
                null
            }

            // Exclude non-existent packages or self
            if (appInfo == null || pkgName == packageName) continue

            val appName = pm.getApplicationLabel(appInfo).toString()
            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0 ||
                    (appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0

            val idleTimeMillis = if (usage.lastTimeUsed > 0 && now >= usage.lastTimeUsed) {
                now - usage.lastTimeUsed
            } else {
                // If it was never launched during the interval, assume at least the window interval
                now - startTime
            }

            // Estimated battery usage based on foreground proportion
            val batteryShare = if (totalForegroundTimeAllApps > 0) {
                ((usage.totalTimeInForeground.toDouble() / totalForegroundTimeAllApps.toDouble()) * 25.0)
                    .coerceIn(0.1, 40.0)
            } else {
                0.5
            }

            resultList.add(
                mapOf(
                    "packageName" to pkgName,
                    "appName" to appName,
                    "idleTimeMillis" to idleTimeMillis,
                    "lastTimeUsedMillis" to usage.lastTimeUsed,
                    "totalForegroundTimeMillis" to usage.totalTimeInForeground,
                    "estimatedBatteryPercent" to (Math.round(batteryShare * 10.0) / 10.0),
                    "isSystemApp" to isSystemApp
                )
            )
        }

        // Sort descending by idle time (most inactive first)
        resultList.sortByDescending { it["idleTimeMillis"] as Long }
        return resultList
    }

    private data class AggregatedUsage(
        val packageName: String,
        var lastTimeUsed: Long,
        var totalTimeInForeground: Long
    )
}
