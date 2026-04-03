import 'package:flutter/material.dart';

class ChoreTemplate {
  final String title;
  final String category;
  final String priority;
  final IconData icon;
  const ChoreTemplate({required this.title, required this.category, this.priority = 'medium', required this.icon});
}

const choreTemplates = [
  ChoreTemplate(title: 'Do dishes', category: 'dishwashing', icon: Icons.local_laundry_service_rounded),
  ChoreTemplate(title: 'Vacuum', category: 'cleaning', icon: Icons.cleaning_services_rounded),
  ChoreTemplate(title: 'Mop floors', category: 'cleaning', icon: Icons.cleaning_services_rounded),
  ChoreTemplate(title: 'Do laundry', category: 'laundry', icon: Icons.dry_cleaning_rounded),
  ChoreTemplate(title: 'Cook dinner', category: 'cooking', priority: 'high', icon: Icons.restaurant_rounded),
  ChoreTemplate(title: 'Take out trash', category: 'cleaning', icon: Icons.delete_outline_rounded),
  ChoreTemplate(title: 'Water plants', category: 'gardening', icon: Icons.grass_rounded),
  ChoreTemplate(title: 'Grocery shopping', category: 'shopping', priority: 'high', icon: Icons.shopping_cart_rounded),
  ChoreTemplate(title: 'Clean bathroom', category: 'cleaning', icon: Icons.cleaning_services_rounded),
  ChoreTemplate(title: 'Tidy up', category: 'cleaning', priority: 'low', icon: Icons.cleaning_services_rounded),
];
