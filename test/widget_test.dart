// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_optimizer/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.simulated_application/tracker'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'hasUsagePermission':
            return false;
          case 'getBatteryStatus':
            return {'batteryPercent': 85.0, 'isCharging': false};
          case 'getAppsUsageStats':
            return [];
          case 'startTrackerService':
          case 'stopTrackerService':
          case 'requestUsagePermission':
            return true;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.example.simulated_application/tracker'),
      null,
    );
  });

  testWidgets('HibernationApp renders without layout overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const HibernationApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HibernationApp), findsOneWidget);
    expect(find.textContaining('Application Matrix'), findsOneWidget);
  });

  testWidgets('HibernationApp renders on narrow screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const HibernationApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HibernationApp), findsOneWidget);
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(const HibernationApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('swipe right marks an app for hibernation',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    final hibernatedBadge = find.descendant(
      of: find.byType(Card),
      matching: find.text('Hibernated'),
    );

    expect(hibernatedBadge, findsNothing);

    await tester.drag(find.text('Video Streamer'), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(hibernatedBadge, findsOneWidget);
    expect(
      find.text('Video Streamer marked for hibernation.'),
      findsOneWidget,
    );
  });

  testWidgets('swipe left adds protection to an app',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    final essentialBadge = find.descendant(
      of: find.byType(Card),
      matching: find.text('Essential'),
    );
    final initialEssentialCount = essentialBadge.evaluate().length;
    expect(initialEssentialCount, greaterThan(0));

    await tester.drag(find.text('Video Streamer'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(essentialBadge, findsNWidgets(initialEssentialCount + 1));
    expect(
      find.text('Video Streamer added to protection list.'),
      findsOneWidget,
    );
  });

  testWidgets('double tap opens app details', (WidgetTester tester) async {
    await pumpDashboard(tester);

    final appFinder = find.text('Video Streamer');
    await tester.tap(appFinder);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(appFinder);
    await tester.pumpAndSettle();

    expect(find.text('Battery drain'), findsOneWidget);
    expect(find.text('Idle time'), findsOneWidget);
  });

  testWidgets('long press opens application options',
      (WidgetTester tester) async {
    await pumpDashboard(tester);

    await tester.longPress(find.text('Video Streamer'));
    await tester.pumpAndSettle();

    expect(find.text('View app details'), findsOneWidget);
    expect(find.text('Mark for hibernation'), findsOneWidget);
    expect(find.text('Add to protection list'), findsOneWidget);
  });

  testWidgets('tap selects an application', (WidgetTester tester) async {
    await pumpDashboard(tester);

    expect(find.byIcon(Icons.check), findsNothing);

    await tester.tap(find.text('Video Streamer'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('pinch in gradually hides only the pinched app column texts', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    double titleFontSize() =>
        tester.widget<Text>(find.text('Video Streamer')).style!.fontSize!;

    expect(find.text('Video Streamer'), findsOneWidget);
    expect(titleFontSize(), 15.0);
    expect(find.byKey(const ValueKey('app-column')), findsOneWidget);

    final dashboardCenter = tester.getCenter(find.text('Active Apps'));
    var first = await tester.startGesture(dashboardCenter - const Offset(40, 0));
    var second =
        await tester.startGesture(dashboardCenter + const Offset(40, 0));
    await tester.pump();

    // Pinch out: the apps grow but stay in their column.
    await first.moveTo(dashboardCenter - const Offset(140, 0));
    await second.moveTo(dashboardCenter + const Offset(140, 0));
    await tester.pump();

    expect(find.text('Apps enlarged • 140%'), findsOneWidget);
    expect(find.text('Video Streamer'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-column')), findsOneWidget);
    expect(titleFontSize(), 18.0);

    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    // Reset zoom back to 100% by pinching in (1.4 * 50 / 70 = 1.0).
    first = await tester.startGesture(dashboardCenter - const Offset(70, 0));
    second = await tester.startGesture(dashboardCenter + const Offset(70, 0));
    await tester.pump();
    await first.moveTo(dashboardCenter - const Offset(50, 0));
    await second.moveTo(dashboardCenter + const Offset(50, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(titleFontSize(), 15.0);

    // Pinch in: all apps' logos, texts, and status gradually shrink inside the column.
    first = await tester.startGesture(dashboardCenter - const Offset(40, 0));
    second = await tester.startGesture(dashboardCenter + const Offset(40, 0));
    await tester.pump();

    await first.moveTo(dashboardCenter - const Offset(28, 0));
    await second.moveTo(dashboardCenter + const Offset(28, 0));
    await tester.pump();

    expect(find.text('Minimizing apps • 70%'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-column')), findsOneWidget);
    expect(
      tester.widget<Opacity>(find.byKey(const ValueKey('app-logo-1'))).opacity,
      closeTo(0.4, 0.01),
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('app-content-1')))
          .opacity,
      closeTo(0.4, 0.01),
    );
    expect(
      tester.widget<Opacity>(find.byKey(const ValueKey('app-logo-2'))).opacity,
      closeTo(0.4, 0.01),
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('app-content-2')))
          .opacity,
      closeTo(0.4, 0.01),
    );

    // Keep pinching in to 50%: all apps' logos, texts, and status shrink away,
    // while the column container remains.
    await first.moveTo(dashboardCenter - const Offset(20, 0));
    await second.moveTo(dashboardCenter + const Offset(20, 0));
    await tester.pump();

    expect(find.text('Apps minimized • pinch out to show'), findsOneWidget);
    expect(find.byKey(const ValueKey('app-column')), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('app-list-layer')))
          .opacity,
      0.0,
    );
    final summaryFinder = find.byKey(const ValueKey('pinch-summary-overview'));
    expect(summaryFinder, findsOneWidget);
    expect(
      find.descendant(
        of: summaryFinder,
        matching: find.text('Device Overview Summary'),
      ),
      findsOneWidget,
    );
    for (final label in [
      'Active',
      'Unused',
      'Protected',
      'Hibernated',
      'Memory in Use',
      'Battery Savings',
    ]) {
      expect(
        find.descendant(of: summaryFinder, matching: find.text(label)),
        findsOneWidget,
      );
    }
    for (final id in ['1', '2', '3']) {
      expect(
        tester
            .widget<Opacity>(find.byKey(ValueKey('app-logo-$id')))
            .opacity,
        0.0,
      );
      expect(
        tester
            .widget<Opacity>(find.byKey(ValueKey('app-content-$id')))
            .opacity,
        0.0,
      );
    }

    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    // Pinch out on the app column to bring all apps' logos, texts, and status back.
    final columnCenter =
        tester.getCenter(find.byKey(const ValueKey('app-column')));
    first = await tester.startGesture(columnCenter - const Offset(20, 0));
    second = await tester.startGesture(columnCenter + const Offset(20, 0));
    await tester.pump();

    await first.moveTo(columnCenter - const Offset(40, 0));
    await second.moveTo(columnCenter + const Offset(40, 0));
    await tester.pump();

    expect(find.text('Dashboard 100%'), findsOneWidget);
    expect(find.byKey(const ValueKey('pinch-summary-overview')), findsNothing);
    expect(find.text('Video Streamer'), findsOneWidget);
    for (final id in ['1', '2', '3']) {
      expect(
        tester
            .widget<Opacity>(find.byKey(ValueKey('app-logo-$id')))
            .opacity,
        1.0,
      );
      expect(
        tester
            .widget<Opacity>(find.byKey(ValueKey('app-content-$id')))
            .opacity,
        1.0,
      );
    }

    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    expect(find.textContaining('Dashboard'), findsNothing);
  });
}
