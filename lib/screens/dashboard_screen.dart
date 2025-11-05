import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import '../models/subject.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Subject>('subjects');

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Subject> b, _) {
          final subjects = b.values.toList(); 
          if (subjects.isEmpty) {
            return const Center(child: Text('No subjects yet. Tap + to add.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final s = subjects[index];
              final percent = s.attendancePercent();
              final color = percent >= 75.0 ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  title: Text(s.name),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: LinearProgressIndicator(
                      value: percent / 100.0,
                      color: color,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  trailing: Text('${percent.toStringAsFixed(0)}%'),
                  onTap: () => context.push('/calendar/${s.id}'),
                  onLongPress: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => SafeArea(
                      child: Wrap(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Edit subject'),
                            onTap: () {
                              Navigator.of(context).pop();
                              context.push('/add-subject', extra: s);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete, color: Colors.redAccent),
                            title: const Text('Delete subject', style: TextStyle(color: Colors.redAccent)),
                            onTap: () async {
                              Navigator.of(context).pop();
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete subject'),
                                  content: const Text('Are you sure you want to delete this subject?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await b.delete(s.id);
                                messenger.showSnackBar(const SnackBar(content: Text('Subject deleted')));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      // FAB is provided by the App shell when on the Dashboard tab.
    );
  }
}
