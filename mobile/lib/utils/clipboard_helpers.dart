import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/feedback_service.dart';

Future<void> copyWithFeedback(
  BuildContext c,
  String value, {
  String label = 'Copied',
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (c.mounted) {
    AppFeedback.success(c, '$label to clipboard');
  }
}
