import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arena/app.dart';

void main() {
  testWidgets('App boots to a black screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ArenaApp());
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
