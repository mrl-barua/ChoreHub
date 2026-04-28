import 'package:flutter/material.dart';
import '../config/theme.dart';

const Map<String, Color> choreStatusColors = {
  'awaiting': AppTheme.accentOrange,
  'declined': AppTheme.accentRed,
  'done': AppTheme.accentGreen,
  'pending': AppTheme.textSecondary,
};

class ChoreStatus {
  static const pending = 'pending';
  static const done = 'done';
}

class ChorePriority {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
}

class AssignmentStatus {
  static const unassigned = 'unassigned';
  static const pendingAcceptance = 'pending_acceptance';
  static const accepted = 'accepted';
  static const declined = 'declined';
}

class ChoreAction {
  static const created = 'created';
  static const assigned = 'assigned';
  static const completed = 'completed';
  static const reopened = 'reopened';
}
