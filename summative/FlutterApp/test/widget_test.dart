import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pay_estimator/main.dart';

void main() {
  testWidgets('Prediction page has 11 input fields and a Predict button', (tester) async {
    await tester.pumpWidget(const PayEstimatorApp());

    expect(find.byType(TextFormField), findsNWidgets(11));
    expect(find.text('Predict'), findsOneWidget);
  });
}