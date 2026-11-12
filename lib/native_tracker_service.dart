import 'package:flutter/services.dart';

class NativeAppUsage {
  final String packageName;
  final String appName;
  final Duration idleTime;
  final Duration totalForegroundTime;
  final double estimatedBatteryPercent;
  final bool isSystemApp;

  NativeAppUsage({
    required this.packageName,
    required this.appName,
    required this.idleTime,
    required this.totalForegroundTime,
    required this.estimatedBatteryPercent,
    required this.isSystemApp,
  });

  factory NativeAppUsage.fromMap(Map<dynamic, dynamic> map) {
    return NativeAppUsage(
      packageName: map['packageName'] as String? ?? 'unknown',
      appName: map['appName'] as String? ?? 'App',
      idleTime: Duration(milliseconds: (map['idleTimeMillis'] as num?)?.toInt() ?? 0),
      totalForegroundTime: Duration(milliseconds: (map['totalForegroundTimeMillis'] as num?)?.toInt() ?? 0),
      estimatedBatteryPercent: ((map['estimatedBatteryPercent'] as num?)?.toDouble() ?? 0.0),
      isSystemApp: map['isSystemApp'] as bool? ?? false,
    );
  }
}

class NativeBatteryStatus {
  final double batteryPercent;
  final bool isCharging;

  NativeBatteryStatus({
    required this.batteryPercent,
    required this.isCharging,
  });

  factory NativeBatteryStatus.fromMap(Map<dynamic, dynamic> map) {
    return NativeBatteryStatus(
      batteryPercent: ((map['batteryPercent'] as num?)?.toDouble() ?? 100.0),
      isCharging: map['isCharging'] as bool? ?? false,
    );
  }
}

class NativeTrackerService {
  static const MethodChannel _channel = MethodChannel('com.example.simulated_application/tracker');

  /// Check whether the app has been granted android.permission.PACKAGE_USAGE_STATS
  static Future<bool> hasUsagePermission() async {
    try {
      final bool? hasPermission = await _channel.invokeMethod<bool>('hasUsagePermission');
      return hasPermission ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // In tests or desktop environments
      return false;
    }
  }

  /// Directs user to Android's "Apps with Usage Access" settings screen
  static Future<void> requestUsagePermission() async {
    try {
      await _channel.invokeMethod('requestUsagePermission');
    } on PlatformException catch (_) {}
  }

  /// Start foreground native battery and app usage tracker service
  static Future<bool> startTrackerService() async {
    try {
      final bool? started = await _channel.invokeMethod<bool>('startTrackerService');
      return started ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Stop foreground native battery service
  static Future<bool> stopTrackerService() async {
    try {
      final bool? stopped = await _channel.invokeMethod<bool>('stopTrackerService');
      return stopped ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Query live device battery level and charging state
  static Future<NativeBatteryStatus> getBatteryStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getBatteryStatus');
      if (result != null) {
        return NativeBatteryStatus.fromMap(result);
      }
    } on PlatformException catch (_) {}
    return NativeBatteryStatus(batteryPercent: 100.0, isCharging: false);
  }

  /// Fetch live installed apps and their idle times from Android UsageStatsManager
  static Future<List<NativeAppUsage>> getAppsUsageStats({int daysBack = 7}) async {
    try {
      final List<dynamic>? stats = await _channel.invokeListMethod<dynamic>(
        'getAppsUsageStats',
        {'daysBack': daysBack},
      );
      if (stats != null) {
        return stats
            .whereType<Map<dynamic, dynamic>>()
            .map((item) => NativeAppUsage.fromMap(item))
            .toList();
      }
    } on PlatformException catch (_) {}
    return [];
  }
}
