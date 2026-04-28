import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/feedback_service.dart';

void main() {
  testWidgets('duplicate suppression shows only one snackbar within 1s', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              AppFeedback.success(context, 'Saved');
              AppFeedback.success(context, 'Saved');
            },
            child: const Text('tap'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('tap'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
