import 'package:flutter/material.dart';
import '../config/theme.dart';

class CategoryHelpers {
  static IconData iconFor(String category) {
    switch (category) {
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'cooking':
        return Icons.restaurant_rounded;
      case 'dishwashing':
        return Icons.local_laundry_service_rounded;
      case 'laundry':
        return Icons.dry_cleaning_rounded;
      case 'gardening':
        return Icons.grass_rounded;
      case 'shopping':
        return Icons.shopping_cart_rounded;
      default:
        return Icons.task_rounded;
    }
  }

  static Color colorFor(String category) {
    return AppTheme.categoryColors[category] ?? Colors.grey;
  }

  static Color priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppTheme.priorityHigh;
      case 'low':
        return AppTheme.priorityLow;
      default:
        return AppTheme.priorityMedium;
    }
  }

  static Color historyActionColor(String action) {
    switch (action) {
      case 'created':
        return AppTheme.accentBlue;
      case 'completed':
        return AppTheme.accentGreen;
      case 'assigned':
        return AppTheme.accent;
      case 'accepted':
        return AppTheme.accentGreen;
      case 'declined':
        return AppTheme.accentRed;
      case 'reopened':
        return AppTheme.accentOrange;
      default:
        return Colors.grey;
    }
  }

  static IconData historyActionIcon(String action) {
    switch (action) {
      case 'created':
        return Icons.add_circle_outline_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'assigned':
        return Icons.person_add_rounded;
      case 'accepted':
        return Icons.thumb_up_rounded;
      case 'declined':
        return Icons.thumb_down_rounded;
      case 'reopened':
        return Icons.refresh_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  static Color assignmentStatusColor(String status) {
    switch (status) {
      case 'pending_acceptance':
        return Colors.orange;
      case 'accepted':
        return AppTheme.accentGreen;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
