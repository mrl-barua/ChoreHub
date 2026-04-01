import 'package:flutter/material.dart';
import '../models/chore.dart';

class ChoreCard extends StatelessWidget {
  final Chore chore;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const ChoreCard({
    super.key,
    required this.chore,
    required this.onToggle,
    required this.onTap,
  });

  IconData _categoryIcon() {
    switch (chore.category) {
      case 'cleaning':
        return Icons.cleaning_services;
      case 'cooking':
        return Icons.restaurant;
      case 'dishwashing':
        return Icons.local_laundry_service;
      default:
        return Icons.task;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  chore.isDone ? Icons.check_circle : Icons.circle_outlined,
                  color: chore.isDone ? Colors.green : Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              Icon(_categoryIcon(), size: 20, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chore.title,
                      style: TextStyle(
                        fontSize: 16,
                        decoration: chore.isDone ? TextDecoration.lineThrough : null,
                        color: chore.isDone ? Colors.grey : null,
                      ),
                    ),
                    if (chore.timeSlot != null)
                      Text(
                        chore.timeSlot![0].toUpperCase() + chore.timeSlot!.substring(1),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              if (chore.dueDate != null)
                Text(chore.dueDate!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
