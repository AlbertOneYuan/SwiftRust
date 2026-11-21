import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/mobile/widgets/trackpad_region.dart';

void main() {
  final events = <String>[];
  Future<void> mount(WidgetTester tester) async {
    events.clear();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: TrackpadRegion(
        onMove: (delta, _) => events.add('move'),
        onClick: () => events.add('click'),
        onDoubleClick: () => events.add('double'),
        onSecondaryClick: () => events.add('right'),
        onDragDown: () => events.add('down'),
        onDragUp: () => events.add('up'),
        onScroll: (x, y) => events.add('scroll:$x,$y'),
        onScale: (scale, _) => events.add('scale:$scale'),
        child: const SizedBox.expand(),
      ),
    ));
  }

  testWidgets('tap clicks and moving one finger only moves the pointer',
      (tester) async {
    await mount(tester);
    await tester.tapAt(const Offset(100, 100));
    await tester.pump(kDoubleTapTimeout);
    expect(events, ['click']);
    events.clear();
    await tester.dragFrom(const Offset(100, 100), const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(events, contains('move'));
    expect(events, isNot(contains('down')));
    expect(events, isNot(contains('click')));
  });

  testWidgets('double tap sends a double click', (tester) async {
    await mount(tester);
    await tester.tapAt(const Offset(100, 100));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();
    expect(events, ['double']);
  });

  testWidgets('two finger tap sends one right click without a left click',
      (tester) async {
    await mount(tester);
    final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
    final b = await tester.startGesture(const Offset(200, 100), pointer: 2);
    await tester.pump(const Duration(milliseconds: 60));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(events, ['right']);
  });

  testWidgets('two fingers scroll without moving the cursor or clicking',
      (tester) async {
    await mount(tester);
    final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
    final b = await tester.startGesture(const Offset(200, 100), pointer: 2);
    for (var i = 0; i < 6; i++) {
      await a.moveBy(const Offset(0, 20));
      await b.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(events.where((e) => e.startsWith('scroll:')), isNotEmpty);
    expect(events.where((e) => !e.startsWith('scroll:')), isEmpty);
  });

  testWidgets('pinch zooms the canvas without scrolling or clicking',
      (tester) async {
    await mount(tester);
    final a = await tester.startGesture(const Offset(150, 150), pointer: 1);
    final b = await tester.startGesture(const Offset(250, 150), pointer: 2);
    for (var i = 0; i < 5; i++) {
      await a.moveBy(const Offset(-15, 0));
      await b.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(events.where((e) => e.startsWith('scale:')), isNotEmpty);
    expect(events.where((e) => !e.startsWith('scale:')), isEmpty);
  });

  testWidgets('pinching inward reduces the canvas scale', (tester) async {
    await mount(tester);
    final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
    final b = await tester.startGesture(const Offset(300, 100), pointer: 2);
    for (var i = 0; i < 4; i++) {
      await a.moveBy(const Offset(15, 0));
      await b.moveBy(const Offset(-15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    final scales = events
        .where((e) => e.startsWith('scale:'))
        .map((e) => double.parse(e.substring(6)));
    expect(scales, isNotEmpty);
    expect(scales.reduce((a, b) => a * b), lessThan(1));
    expect(events.where((e) => !e.startsWith('scale:')), isEmpty);
  });

  testWidgets('horizontal two finger scrolling does not zoom', (tester) async {
    await mount(tester);
    final a = await tester.startGesture(const Offset(100, 100), pointer: 1);
    final b = await tester.startGesture(const Offset(200, 100), pointer: 2);
    for (var i = 0; i < 6; i++) {
      await a.moveBy(const Offset(20, 0));
      await b.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(events.where((e) => e.startsWith('scroll:')), isNotEmpty);
    expect(events.where((e) => !e.startsWith('scroll:')), isEmpty);
  });

  testWidgets('long press drags and releases on lift or cancellation',
      (tester) async {
    for (final cancel in [false, true]) {
      await mount(tester);
      final finger = await tester.startGesture(const Offset(100, 100));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(events, ['down']);
      await finger.moveBy(const Offset(50, 0));
      if (cancel) {
        await finger.cancel();
      } else {
        await finger.up();
      }
      await tester.pumpAndSettle();
      expect(events, ['down', 'move', 'up']);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('removing the region releases an active drag', (tester) async {
    await mount(tester);
    final finger = await tester.startGesture(const Offset(100, 100));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    expect(events, ['down', 'up']);
    await finger.up();
  });
}
