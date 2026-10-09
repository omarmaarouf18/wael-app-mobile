import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/widgets/app_bottom_nav.dart';

void main() {
  testWidgets('a long nav label stays on one line, centred under its icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNav(
            currentIndex: 2,
            onTap: (_) {},
            items: const [
              AppNavItem(icon: Icons.home, label: 'Home'),
              AppNavItem(icon: Icons.school_outlined, label: 'Courses'),
              AppNavItem(icon: Icons.edit_note, label: 'Notes & books'),
              AppNavItem(icon: Icons.tune, label: 'Settings'),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final label = find.text('NOTES & BOOKS');
    final text = tester.widget<Text>(label);
    expect(text.maxLines, 1);
    expect(text.textAlign, TextAlign.center);
    final labelCentre = tester.getRect(label).center.dx;
    final iconCentre = tester.getRect(find.byIcon(Icons.edit_note)).center.dx;
    expect((labelCentre - iconCentre).abs(), lessThan(1.0));
  });
}
