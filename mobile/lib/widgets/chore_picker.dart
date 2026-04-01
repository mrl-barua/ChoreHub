import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/chore.dart';

class ChorePicker extends StatefulWidget {
  final List<Chore> chores;
  final void Function(Chore chore) onSelected;

  const ChorePicker({super.key, required this.chores, required this.onSelected});

  @override
  State<ChorePicker> createState() => _ChorePickerState();
}

class _ChorePickerState extends State<ChorePicker> {
  String _search = '';

  List<Chore> get _filtered {
    if (_search.isEmpty) return widget.chores;
    final q = _search.toLowerCase();
    return widget.chores.where((c) => c.title.toLowerCase().contains(q) || c.category.toLowerCase().contains(q)).toList();
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'cleaning': return Icons.cleaning_services_rounded;
      case 'cooking': return Icons.restaurant_rounded;
      case 'dishwashing': return Icons.local_laundry_service_rounded;
      case 'laundry': return Icons.dry_cleaning_rounded;
      case 'gardening': return Icons.grass_rounded;
      case 'shopping': return Icons.shopping_cart_rounded;
      default: return Icons.task_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('Attach a Chore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search chores...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 8),
              // Chore list
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text('No chores found', style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final chore = _filtered[index];
                          final categoryColor = AppTheme.categoryColors[chore.category] ?? Colors.grey;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_categoryIcon(chore.category), size: 18, color: categoryColor),
                              ),
                              title: Text(chore.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Row(
                                children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: chore.isDone ? AppTheme.accentGreen : AppTheme.accentOrange,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(chore.isDone ? 'Done' : 'Pending', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                ],
                              ),
                              trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6C63FF)),
                              onTap: () {
                                widget.onSelected(chore);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
