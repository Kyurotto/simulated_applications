import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_tracker_service.dart';

void main() {
  runApp(const HibernationApp());
}

class HibernationApp extends StatelessWidget {
  const HibernationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Sleeper & Optimizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

enum AppCategory { active, unused, essential }

class TrackedApp {
  final String id;
  final String name;
  final String packageName;
  final IconData icon;
  final double batteryUsagePercent; // e.g. 14.2%
  final Duration idleTime; // Time elapsed since last active
  bool isHibernated;
  bool isException;
  final bool isNative;

  TrackedApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.icon,
    required this.batteryUsagePercent,
    required this.idleTime,
    this.isHibernated = false,
    this.isException = false,
    this.isNative = false,
  });

  AppCategory get category {
    if (isException) return AppCategory.essential;
    if (idleTime.inHours >= 12 && !isHibernated) return AppCategory.unused;
    return AppCategory.active;
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const double _minDashboardZoom = 0.5;
  static const double _maxDashboardZoom = 1.4;

  final Duration inactivityThreshold = const Duration(hours: 12);
  bool autoHibernateEnabled = true;
  bool hasUsagePermission = false;
  bool isLoading = false;
  double deviceBatteryLevel = 100.0;
  bool isDeviceCharging = false;

  List<TrackedApp> _apps = [];

  // Gesture state
  String? _selectedAppId;
  double _dashboardZoom = 1.0;
  bool _isPinching = false;
  final Map<int, Offset> _pointers = {};
  double _pinchStartDistance = 0;
  double _pinchStartZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSampleApps();
    _initNativeTracking();
  }

  Future<void> _initNativeTracking() async {
    setState(() => isLoading = true);
    final permitted = await NativeTrackerService.hasUsagePermission();
    final battery = await NativeTrackerService.getBatteryStatus();

    setState(() {
      hasUsagePermission = permitted;
      deviceBatteryLevel = battery.batteryPercent;
      isDeviceCharging = battery.isCharging;
    });

    if (permitted) {
      await _loadNativeApps();
      await NativeTrackerService.startTrackerService();
    }
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadNativeApps() async {
    setState(() => isLoading = true);
    final nativeList =
        await NativeTrackerService.getAppsUsageStats(daysBack: 7);
    if (!mounted) return;

    if (nativeList.isNotEmpty) {
      final List<TrackedApp> updatedList = nativeList.map((app) {
        return TrackedApp(
          id: app.packageName,
          packageName: app.packageName,
          name: app.appName,
          icon: _resolveAppIcon(app.appName, app.packageName, app.isSystemApp),
          batteryUsagePercent: app.estimatedBatteryPercent,
          idleTime: app.idleTime,
          isException: app.isSystemApp,
          isNative: true,
        );
      }).toList();

      setState(() {
        _apps = updatedList;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  IconData _resolveAppIcon(String name, String pkg, bool isSystem) {
    final lower = '$name $pkg'.toLowerCase();
    if (lower.contains('phone') ||
        lower.contains('dialer') ||
        lower.contains('contact')) {
      return Icons.phone_android;
    }
    if (lower.contains('message') ||
        lower.contains('chat') ||
        lower.contains('sms')) {
      return Icons.message;
    }
    if (lower.contains('camera') ||
        lower.contains('photo') ||
        lower.contains('gallery')) {
      return Icons.photo_camera;
    }
    if (lower.contains('map') ||
        lower.contains('nav') ||
        lower.contains('gps')) {
      return Icons.map_outlined;
    }
    if (lower.contains('video') ||
        lower.contains('media') ||
        lower.contains('youtube')) {
      return Icons.ondemand_video;
    }
    if (lower.contains('music') ||
        lower.contains('audio') ||
        lower.contains('spotify')) {
      return Icons.music_note;
    }
    if (lower.contains('clock') || lower.contains('alarm')) {
      return Icons.alarm;
    }
    if (lower.contains('cloud') ||
        lower.contains('drive') ||
        lower.contains('dropbox')) {
      return Icons.cloud_sync;
    }
    if (lower.contains('game') || lower.contains('play')) {
      return Icons.sports_esports;
    }
    if (isSystem) return Icons.security;
    return Icons.apps;
  }

  void _loadSampleApps() {
    _apps = [
      TrackedApp(
        id: '1',
        packageName: 'com.android.phone',
        name: 'Phone & Contacts',
        icon: Icons.phone_android,
        batteryUsagePercent: 1.2,
        idleTime: const Duration(hours: 1),
        isException: true,
      ),
      TrackedApp(
        id: '2',
        packageName: 'com.example.videostreamer',
        name: 'Video Streamer',
        icon: Icons.ondemand_video,
        batteryUsagePercent: 24.5,
        idleTime: const Duration(hours: 26),
      ),
      TrackedApp(
        id: '3',
        packageName: 'com.example.socialfeed',
        name: 'Social Feed Pro',
        icon: Icons.alternate_email,
        batteryUsagePercent: 18.0,
        idleTime: const Duration(hours: 15),
      ),
      TrackedApp(
        id: '4',
        packageName: 'com.android.deskclock',
        name: 'Alarm & Clock',
        icon: Icons.alarm,
        batteryUsagePercent: 0.5,
        idleTime: const Duration(hours: 48),
        isException: true,
      ),
      TrackedApp(
        id: '5',
        packageName: 'com.example.clouddrive',
        name: 'Cloud Drive Sync',
        icon: Icons.cloud_sync,
        batteryUsagePercent: 11.4,
        idleTime: const Duration(hours: 18),
      ),
      TrackedApp(
        id: '6',
        packageName: 'com.google.android.apps.maps',
        name: 'Navigation Maps',
        icon: Icons.map_outlined,
        batteryUsagePercent: 8.7,
        idleTime: const Duration(hours: 3),
      ),
      TrackedApp(
        id: '7',
        packageName: 'com.example.runner3d',
        name: 'Casual Runner 3D',
        icon: Icons.sports_esports,
        batteryUsagePercent: 15.6,
        idleTime: const Duration(hours: 36),
      ),
    ];
  }

  Future<void> _requestUsagePermissionAndRefresh() async {
    await NativeTrackerService.requestUsagePermission();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please grant "Usage Access" in Android Settings and return.'),
        ),
      );
    }
  }

  void _runAutoHibernation() {
    int hibernatedCount = 0;
    setState(() {
      for (var app in _apps) {
        if (!app.isException &&
            !app.isHibernated &&
            app.idleTime >= inactivityThreshold) {
          app.isHibernated = true;
          hibernatedCount++;
        }
      }
    });

    if (mounted && hibernatedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Auto-hibernated $hibernatedCount unused applications.'),
          backgroundColor: Colors.deepPurple,
        ),
      );
    }
  }

  void _optimizeNow() {
    int optimizedCount = 0;
    double savedBattery = 0.0;

    setState(() {
      for (var app in _apps) {
        if (!app.isException && !app.isHibernated) {
          app.isHibernated = true;
          optimizedCount++;
          savedBattery += app.batteryUsagePercent;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Optimized $optimizedCount apps! Saved ~${savedBattery.toStringAsFixed(1)}% battery drain.',
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleException(TrackedApp app) {
    setState(() {
      app.isException = !app.isException;
      if (app.isException && app.isHibernated) {
        app.isHibernated = false;
      }
    });
  }

  void _toggleHibernation(TrackedApp app) {
    setState(() {
      app.isHibernated = !app.isHibernated;
    });
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Swipe right action: mark an application for hibernation.
  void _markForHibernation(TrackedApp app) {
    if (app.isException) {
      _showSnack(
        '${app.name} is protected. Remove protection before hibernating.',
        color: Colors.amber.shade800,
      );
      return;
    }
    if (app.isHibernated) {
      _showSnack('${app.name} is already hibernated.', color: Colors.blueGrey);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => app.isHibernated = true);
    _showSnack(
      '${app.name} marked for hibernation.',
      color: Colors.indigo.shade700,
    );
  }

  /// Swipe left action: add an application to the protection list.
  void _addProtection(TrackedApp app) {
    if (app.isException) {
      _showSnack(
        '${app.name} is already protected.',
        color: Colors.teal.shade700,
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      app.isException = true;
      app.isHibernated = false;
    });
    _showSnack(
      '${app.name} added to protection list.',
      color: Colors.teal.shade700,
    );
  }

  void _removeProtection(TrackedApp app) {
    if (!app.isException) return;
    HapticFeedback.lightImpact();
    setState(() => app.isException = false);
    _showSnack(
      '${app.name} removed from protection.',
      color: Colors.orange.shade800,
    );
  }

  void _wakeApp(TrackedApp app) {
    if (!app.isHibernated) return;
    HapticFeedback.lightImpact();
    setState(() => app.isHibernated = false);
    _showSnack('${app.name} is active again.', color: Colors.green.shade700);
  }

  /// Tap action: select / deselect an application.
  void _selectApp(TrackedApp app) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAppId = _selectedAppId == app.id ? null : app.id;
    });
  }

  /// 1.0 while all app logos, texts, and status badges are fully visible;
  /// smoothly scales/fades to 0.0 as the user pinches in.
  double get _appsContentVisibility {
    if (_dashboardZoom >= 1.0) return 1.0;
    return ((_dashboardZoom - _minDashboardZoom) / (1.0 - _minDashboardZoom))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  String _pinchStatusLabel() {
    if (_appsContentVisibility <= 0.001) {
      return 'Apps minimized • pinch out to show';
    }
    final percent = (_dashboardZoom * 100).round();
    if (_dashboardZoom < 1.0) return 'Minimizing apps • $percent%';
    if (_dashboardZoom > 1.0) return 'Apps enlarged • $percent%';
    return 'Dashboard 100%';
  }

  String _appStatusLabel(TrackedApp app) {
    if (app.isException) return 'Essential';
    if (app.isHibernated) return 'Hibernated';
    if (app.idleTime >= inactivityThreshold) return 'Unused';
    return 'Active';
  }

  Color _appStatusColor(TrackedApp app) {
    if (app.isException) return Colors.amber;
    if (app.isHibernated) return Colors.blueGrey;
    if (app.idleTime >= inactivityThreshold) return Colors.redAccent;
    return Colors.greenAccent;
  }

  String _categoryLabel(AppCategory category) {
    switch (category) {
      case AppCategory.active:
        return 'Active';
      case AppCategory.unused:
        return 'Unused';
      case AppCategory.essential:
        return 'Essential';
    }
  }

  void _showGestureGuide() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Gesture controls',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _buildGestureRow(
                Icons.swipe_right_alt,
                'Swipe right',
                'Mark an app for hibernation',
              ),
              _buildGestureRow(
                Icons.swipe_left_alt,
                'Swipe left',
                'Add an app for protection',
              ),
              _buildGestureRow(
                Icons.touch_app,
                'Double tap',
                'View app details',
              ),
              _buildGestureRow(
                Icons.more_horiz,
                'Long press',
                'Show options for an application',
              ),
              _buildGestureRow(
                Icons.zoom_out_map,
                'Pinch out',
                'Enlarge the apps while keeping the column layout',
              ),
              _buildGestureRow(
                Icons.zoom_in_map,
                'Pinch in',
                'Minimize the menu by hiding apps one by one',
              ),
              _buildGestureRow(
                Icons.ads_click,
                'Tap',
                'Select an application',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGestureRow(IconData icon, String gesture, String description) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.5),
        child: Icon(icon, size: 18),
      ),
      title: Text(gesture, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
    );
  }

  /// Double tap action: read-only details sheet.
  void _showAppDetails(TrackedApp app) {
    final statusColor = _appStatusColor(app);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(app.icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            app.packageName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusChip(_appStatusLabel(app), statusColor),
                    _buildStatusChip(
                      app.isException ? 'Protected' : 'Not protected',
                      app.isException ? Colors.tealAccent : Colors.white70,
                    ),
                    _buildStatusChip(
                      app.isNative ? 'Live data' : 'Simulated',
                      app.isNative ? Colors.lightBlueAccent : Colors.white70,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                _buildDetailRow('Category', _categoryLabel(app.category)),
                _buildDetailRow(
                  'Battery drain',
                  '${app.batteryUsagePercent.toStringAsFixed(1)}%',
                ),
                _buildDetailRow('Idle time', _formatIdleTime(app.idleTime)),
                _buildDetailRow(
                  'Protection',
                  app.isException
                      ? 'Essential / never hibernates'
                      : 'Eligible for hibernation',
                ),
                _buildDetailRow(
                  'State',
                  app.isHibernated ? 'Hibernated' : 'Running',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tip: long-press this app for quick actions.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Long press action: contextual options sheet.
  Future<void> _showAppOptions(TrackedApp app) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(app.icon, color: Colors.white),
                ),
                title: Text(
                  app.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  app.packageName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View app details'),
                onTap: () => Navigator.pop(sheetContext, 'details'),
              ),
              ListTile(
                enabled: !app.isException,
                leading: Icon(
                  app.isHibernated ? Icons.play_arrow : Icons.nightlight_round,
                ),
                title: Text(
                  app.isHibernated
                      ? 'Wake application'
                      : 'Mark for hibernation',
                ),
                subtitle: app.isException
                    ? const Text('Protected apps cannot be hibernated')
                    : null,
                onTap: app.isException
                    ? null
                    : () => Navigator.pop(sheetContext, 'hibernate'),
              ),
              ListTile(
                leading: Icon(
                  app.isException ? Icons.shield_outlined : Icons.shield,
                ),
                title: Text(
                  app.isException
                      ? 'Remove protection'
                      : 'Add to protection list',
                ),
                onTap: () => Navigator.pop(sheetContext, 'protect'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'details') {
      _showAppDetails(app);
    } else if (action == 'hibernate') {
      if (app.isHibernated) {
        _wakeApp(app);
      } else {
        _markForHibernation(app);
      }
    } else if (action == 'protect') {
      if (app.isException) {
        _removeProtection(app);
      } else {
        _addProtection(app);
      }
    }
  }

  void _handlePointerDown(int pointer, Offset position) {
    _pointers[pointer] = position;
    if (_pointers.length == 2) {
      _pinchStartDistance = _currentPointerDistance();
      _pinchStartZoom = _dashboardZoom;
      if (!_isPinching) {
        setState(() => _isPinching = true);
      }
    }
  }

  void _handlePointerMove(int pointer, Offset position) {
    if (!_pointers.containsKey(pointer)) return;
    _pointers[pointer] = position;
    if (_pointers.length != 2 || _pinchStartDistance <= 0) return;

    final distance = _currentPointerDistance();
    final zoom = (_pinchStartZoom * (distance / _pinchStartDistance))
        .clamp(_minDashboardZoom, _maxDashboardZoom)
        .toDouble();
    if ((zoom - _dashboardZoom).abs() >= 0.005) {
      setState(() => _dashboardZoom = zoom);
    }
  }

  void _handlePointerEnd(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length < 2) {
      _pinchStartDistance = 0;
      if (_isPinching && mounted) {
        setState(() => _isPinching = false);
      }
    } else if (_pointers.length == 2) {
      _pinchStartDistance = _currentPointerDistance();
      _pinchStartZoom = _dashboardZoom;
    }
  }

  double _currentPointerDistance() {
    final points = _pointers.values.take(2).toList(growable: false);
    if (points.length < 2) return 0;
    return (points[0] - points[1]).distance;
  }

  String _formatIdleTime(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _apps.where((a) => !a.isHibernated).length;
    final hibernatedCount = _apps.where((a) => a.isHibernated).length;
    final totalDrain = _apps
        .where((a) => !a.isHibernated)
        .fold(0.0, (sum, a) => sum + a.batteryUsagePercent);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hibernation & Memory Manager'),
        actions: [
          IconButton(
            tooltip: 'Gesture guide',
            icon: const Icon(Icons.gesture),
            onPressed: _showGestureGuide,
          ),
          IconButton(
            tooltip: 'Refresh live usage & battery stats',
            icon: const Icon(Icons.refresh),
            onPressed: _initNativeTracking,
          ),
          IconButton(
            tooltip: 'Run Auto-Hibernation',
            icon: const Icon(Icons.bolt),
            onPressed: _runAutoHibernation,
          ),
        ],
      ),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) =>
            _handlePointerDown(event.pointer, event.position),
        onPointerMove: (event) =>
            _handlePointerMove(event.pointer, event.position),
        onPointerUp: (event) => _handlePointerEnd(event.pointer),
        onPointerCancel: (event) => _handlePointerEnd(event.pointer),
        child: Stack(
          children: [
            Column(
              children: [
                if (!hasUsagePermission) _buildPermissionNoticeBanner(),
                _buildMetricsOverview(activeCount, hibernatedCount, totalDrain),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          hasUsagePermission
                              ? 'Live Tracked Apps (${_apps.length})'
                              : 'Application Matrix (Simulated)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _optimizeNow,
                        icon: const Icon(Icons.cleaning_services, size: 18),
                        label: const Text('Clean Now'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.tealAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Container(
                          key: const ValueKey('app-column'),
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              IgnorePointer(
                                ignoring: _appsContentVisibility < 0.5,
                                child: Opacity(
                                  key: const ValueKey('app-list-layer'),
                                  opacity: _appsContentVisibility,
                                  child: ListView.builder(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: _apps.length,
                                    itemBuilder: (context, index) =>
                                        _buildAppCard(_apps[index]),
                                  ),
                                ),
                              ),
                              if (1.0 - _appsContentVisibility > 0.001)
                                _buildPinchSummaryOverview(
                                  1.0 - _appsContentVisibility,
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            if (_isPinching)
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 8),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pinch, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _pinchStatusLabel(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionNoticeBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amber),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Grant Usage Access permission to read live idle times and device apps.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _requestUsagePermissionAndRefresh,
            child: const Text('Grant',
                style: TextStyle(color: Colors.amberAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsOverview(int active, int hibernated, double drain) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                  child: _buildMetricItem(
                      'Active Apps', '$active', Colors.lightBlueAccent)),
              Expanded(
                  child: _buildMetricItem(
                      'Hibernated', '$hibernated', Colors.orangeAccent)),
              Expanded(
                  child: _buildMetricItem('Est. Drain',
                      '${drain.toStringAsFixed(1)}%', Colors.pinkAccent)),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDeviceCharging
                    ? Icons.battery_charging_full
                    : Icons.battery_std,
                size: 16,
                color:
                    isDeviceCharging ? Colors.greenAccent : Colors.tealAccent,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Device Battery: ${deviceBatteryLevel.toStringAsFixed(0)}%${isDeviceCharging ? ' (Charging)' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildPinchSummaryOverview(double visibility) {
    final protectedCount = _apps.where((a) => a.isException).length;
    final hibernatedCount =
        _apps.where((a) => !a.isException && a.isHibernated).length;
    final unusedCount = _apps
        .where((a) =>
            !a.isException &&
            !a.isHibernated &&
            a.idleTime >= inactivityThreshold)
        .length;
    final activeCount = _apps
        .where((a) =>
            !a.isException &&
            !a.isHibernated &&
            a.idleTime < inactivityThreshold)
        .length;

    final activeDrain = _apps
        .where((a) => !a.isHibernated)
        .fold(0.0, (sum, a) => sum + a.batteryUsagePercent);
    final batterySavings = _apps
        .where((a) => a.isHibernated)
        .fold(0.0, (sum, a) => sum + a.batteryUsagePercent);
    final runningAppsCount = activeCount + unusedCount + protectedCount;
    final memoryInUseMb = (runningAppsCount * 120 + activeDrain * 12).round();
    final memoryLabel = memoryInUseMb >= 1024
        ? '${(memoryInUseMb / 1024).toStringAsFixed(2)} GB'
        : '$memoryInUseMb MB';

    return IgnorePointer(
      ignoring: visibility < 0.5,
      child: Opacity(
        key: const ValueKey('pinch-summary-overview'),
        opacity: visibility,
        child: Transform.scale(
          scale: 0.85 + 0.15 * visibility,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.analytics_outlined,
                            size: 22, color: Colors.tealAccent),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Device Overview Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryStatTile(
                            'Active',
                            '$activeCount',
                            Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryStatTile(
                            'Unused',
                            '$unusedCount',
                            Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryStatTile(
                            'Protected',
                            '$protectedCount',
                            Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryStatTile(
                            'Hibernated',
                            '$hibernatedCount',
                            Colors.lightBlueAccent,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryStatTile(
                            'Memory in Use',
                            memoryLabel,
                            Colors.purpleAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSummaryStatTile(
                            'Battery Savings',
                            '${batterySavings.toStringAsFixed(1)}%',
                            Colors.tealAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Center(
                      child: Text(
                        'Pinch out to show apps again',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStatTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard(TrackedApp app) {
    final zoom = _dashboardZoom;
    final appVisibility = _appsContentVisibility;
    final isSelected = _selectedAppId == app.id;
    final expanded = zoom > 1.15;
    final avatarRadius = (22.0 * zoom).clamp(17.0, 30.0).toDouble();
    final titleSize = (15.0 * zoom).clamp(13.0, 18.0).toDouble();
    final subtitleSize = (12.0 * zoom).clamp(10.0, 14.0).toDouble();
    final badgeSize = (10.0 * zoom).clamp(9.0, 12.0).toDouble();
    final iconSize = (20.0 * zoom).clamp(17.0, 24.0).toDouble();
    final cardVerticalMargin = (5.0 * zoom).clamp(3.0, 8.0).toDouble();
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = _appStatusColor(app);
    final badgeText = _appStatusLabel(app);

    return Dismissible(
      key: ValueKey(app.id),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.32,
        DismissDirection.endToStart: 0.32,
      },
      background: _buildSwipeAction(
        alignment: Alignment.centerLeft,
        color: Colors.indigo,
        icon: Icons.nightlight_round,
        label: 'Hibernate',
        verticalMargin: cardVerticalMargin,
      ),
      secondaryBackground: _buildSwipeAction(
        alignment: Alignment.centerRight,
        color: Colors.teal,
        icon: Icons.shield,
        label: 'Protect',
        verticalMargin: cardVerticalMargin,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _markForHibernation(app);
        } else {
          _addProtection(app);
        }
        // Quick action, not a deletion: let the card snap back into place.
        return false;
      },
      child: GestureDetector(
        onTap: () => _selectApp(app),
        onDoubleTap: () => _showAppDetails(app),
        onLongPress: () => _showAppOptions(app),
        child: Card(
          margin: EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: cardVerticalMargin,
          ),
          color:
              isSelected ? colorScheme.primary.withValues(alpha: 0.12) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 2.0,
            ),
            leading: Opacity(
              key: ValueKey('app-logo-${app.id}'),
              opacity: appVisibility,
              child: Transform.scale(
                scale: appVisibility,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        app.icon,
                        color: Colors.white,
                        size: avatarRadius * 1.15,
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              size: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            title: IgnorePointer(
              ignoring: appVisibility < 0.5,
              child: Opacity(
                key: ValueKey('app-content-${app.id}'),
                opacity: appVisibility,
                child: Transform.scale(
                  scale: appVisibility,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              app.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w600,
                                decoration: app.isHibernated
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: badgeColor, width: 0.8),
                              ),
                              child: Text(
                                badgeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: badgeSize,
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '${app.batteryUsagePercent.toStringAsFixed(1)}% drain  •  '
                          'Idle ${_formatIdleTime(app.idleTime)}'
                          '${expanded ? '\n${app.packageName}' : ''}',
                          style: TextStyle(
                            fontSize: subtitleSize,
                            color: Colors.white70,
                          ),
                          maxLines: expanded ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  iconSize: iconSize,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: app.isException
                      ? 'Remove from Exception List'
                      : 'Add to Exception List',
                  icon: Icon(
                    app.isException ? Icons.star : Icons.star_border,
                    color: app.isException ? Colors.amber : Colors.white38,
                  ),
                  onPressed: () => _toggleException(app),
                ),
                const SizedBox(width: 2),
                IconButton(
                  iconSize: iconSize,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: app.isHibernated
                      ? 'Wake Application'
                      : 'Hibernate Application',
                  icon: Icon(
                    app.isHibernated ? Icons.play_arrow : Icons.pause,
                    color: app.isException ? Colors.grey : Colors.white70,
                  ),
                  onPressed:
                      app.isException ? null : () => _toggleHibernation(app),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeAction({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
    required double verticalMargin,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: verticalMargin),
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
