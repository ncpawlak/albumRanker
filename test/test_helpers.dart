import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text currently shown by the rating picker ("Not rated", "7", "7.5"…).
String ratingText(WidgetTester tester) => tester
    .widget<Text>(find
        .descendant(of: find.byKey(const ValueKey('rating-value')), matching: find.byType(Text), matchRoot: true)
        .first)
    .data!;

/// Sets the rating picker to [target] with the −/+ buttons, like a user would.
Future<void> setRating(WidgetTester tester, double target) async {
  for (var i = 0; i < 25; i++) {
    final shown = double.tryParse(ratingText(tester));
    if (shown == target) return;
    final key = shown == null || shown < target ? 'rating-plus' : 'rating-minus';
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pump();
  }
  fail('Could not set rating to $target (showing ${ratingText(tester)})');
}
