import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wael_app/core/constants.dart';
import 'package:wael_app/widgets/framed_poster_card.dart';

import 'widget_layer_harness.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Size screen,
  double width = double.infinity,
  String asset = AppConstants.imgPoster,
  double fraction = 0.55,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await pumpLocalized(
    tester,
    const Locale('en'),
    Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: FramedPosterCard(
            imageAsset: asset,
            aspectRatio: AppConstants.posterAspectRatio,
            maxHeightFraction: fraction,
            semanticLabel: 'poster',
          ),
        ),
      ),
    ),
  );
}

void main() {
  Size cardSize(WidgetTester tester) => tester.getSize(
    find.descendant(
      of: find.byType(FramedPosterCard),
      matching: find.byType(ClipRRect),
    ),
  );

  testWidgets('is as tall as the allowed fraction of the screen', (
    tester,
  ) async {
    await _pump(tester, screen: const Size(390, 800), fraction: 0.5);
    final frame = tester.getSize(
      find
          .descendant(
            of: find.byType(FramedPosterCard),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(frame.height, closeTo(400, 0.5));
    expect(
      frame.width / frame.height,
      closeTo(AppConstants.posterAspectRatio, 0.01),
    );
  });

  testWidgets('never exceeds the width it is given', (tester) async {
    await _pump(tester, screen: const Size(390, 1200), width: 150);
    final frame = tester.getSize(
      find
          .descendant(
            of: find.byType(FramedPosterCard),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(frame.width, lessThanOrEqualTo(150));
    expect(
      frame.width / frame.height,
      closeTo(AppConstants.posterAspectRatio, 0.01),
    );
  });

  testWidgets('shows the whole image (contain) and is labelled', (
    tester,
  ) async {
    await _pump(tester, screen: const Size(360, 640));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(cardSize(tester).height, greaterThan(0));
    expect(find.bySemanticsLabel('poster'), findsOneWidget);
  });

  testWidgets('a missing image falls back to a flat surface, no crash', (
    tester,
  ) async {
    await _pump(tester, screen: const Size(360, 640), asset: 'assets/none.png');
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(FramedPosterCard), findsOneWidget);
  });
}
