import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import '../models/subject.dart';

class AddEditSubjectScreen extends StatefulWidget {
  final Subject? subject;

  const AddEditSubjectScreen({super.key, this.subject});

  @override
  State<AddEditSubjectScreen> createState() => _AddEditSubjectScreenState();
}

class _AddEditSubjectScreenState extends State<AddEditSubjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));
  Map<int, Map<String, int>> _schedule = {}; // weekday -> {'start':minutes,'end':minutes}

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.subject != null) {
      final s = widget.subject!;
      _nameCtrl.text = s.name;
      _start = s.startDate;
      _end = s.endDate;
      _schedule = Map<int, Map<String, int>>.from(s.schedule);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final box = Hive.box<Subject>('subjects');
    final name = _nameCtrl.text.trim();

    // uniqueness check (case-insensitive)
    final existing = box.values.cast<Subject?>().firstWhere(
      (e) => e != null && e.name.toLowerCase() == name.toLowerCase(),
      orElse: () => null,
    );

    if (existing != null && widget.subject == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A subject with this name already exists')));
      return;
    }

    if (existing != null && widget.subject != null && existing.id != widget.subject!.id) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Another subject with this name exists')));
      return;
    }

    if (widget.subject != null) {
      // update
      final id = widget.subject!.id;
      final subject = Subject(
        id: id,
        name: name,
        startDate: _start,
        endDate: _end,
        attendance: widget.subject!.attendance,
        totalLectures: widget.subject!.totalLectures,
        attendedLectures: widget.subject!.attendedLectures,
        schedule: _schedule,
      );
      await box.put(id, subject);
    } else {
      final id = const Uuid().v4();
      final subject = Subject(id: id, name: name, startDate: _start, endDate: _end, schedule: _schedule);
      await box.put(id, subject);
    }

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Subject')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Subject name'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12.0),
              const Text('Weekdays & time', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8.0),
              ...List.generate(7, (i) {
                final weekday = i + 1; // 1..7
                final names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                final selected = _schedule.containsKey(weekday);
                final startMinutes = _schedule[weekday]?['start'];
                final endMinutes = _schedule[weekday]?['end'];

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            title: Text(names[i]),
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  // default to 09:00-10:00 if not set
                                  _schedule[weekday] = {'start': startMinutes ?? (9 * 60), 'end': endMinutes ?? (10 * 60)};
                                } else {
                                  _schedule.remove(weekday);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                        ),
                        if (selected)
                          Row(
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final initial = startMinutes != null ? TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60) : const TimeOfDay(hour: 9, minute: 0);
                                  final picked = await showTimePicker(context: context, initialTime: initial);
                                  if (picked != null) {
                                    setState(() {
                                      final end = _schedule[weekday]?['end'] ?? (picked.hour * 60 + picked.minute + 60);
                                      _schedule[weekday] = {'start': picked.hour * 60 + picked.minute, 'end': end};
                                    });
                                  }
                                },
                                child: Text(startMinutes != null ? '${(startMinutes ~/ 60).toString().padLeft(2, '0')}:${(startMinutes % 60).toString().padLeft(2, '0')}' : 'Start'),
                              ),
                              const SizedBox(width: 8),
                              Text('-'),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  final initial = endMinutes != null ? TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60) : const TimeOfDay(hour: 10, minute: 0);
                                  final picked = await showTimePicker(context: context, initialTime: initial);
                                  if (picked != null) {
                                    setState(() {
                                      final start = _schedule[weekday]?['start'] ?? (picked.hour * 60 + picked.minute - 60);
                                      _schedule[weekday] = {'start': start, 'end': picked.hour * 60 + picked.minute};
                                    });
                                  }
                                },
                                child: Text(endMinutes != null ? '${(endMinutes ~/ 60).toString().padLeft(2, '0')}:${(endMinutes % 60).toString().padLeft(2, '0')}' : 'End'),
                              ),
                            ],
                          )
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                );
              }),
              Row(
                children: [
                  Expanded(
                    child: Text('Start: ${_start.toLocal().toIso8601String().split('T').first}'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _start,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _start = picked);
                    },
                    child: const Text('Pick'),
                  )
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text('End: ${_end.toLocal().toIso8601String().split('T').first}')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _end,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _end = picked);
                    },
                    child: const Text('Pick'),
                  )
                ],
              ),
              const SizedBox(height: 20.0),
              ElevatedButton(onPressed: _save, child: const Text('Save'))
            ],
          ),
        ),
      ),
    );
  }
}
