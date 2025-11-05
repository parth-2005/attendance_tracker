import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/subject.dart';

class SubjectCalendarScreen extends StatefulWidget {
  final String subjectId;
  const SubjectCalendarScreen({super.key, required this.subjectId});

  @override
  State<SubjectCalendarScreen> createState() => _SubjectCalendarScreenState();
}

class _SubjectCalendarScreenState extends State<SubjectCalendarScreen> {
  late final Box<Subject> _box;
  Subject? _subject;
  DateTime _focused = DateTime.now();

  @override
  void initState() {
    super.initState();
    _box = Hive.box<Subject>('subjects');
    _loadSubject();
  }

  void _loadSubject() {
    setState(() {
      _subject = _box.get(widget.subjectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_subject == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Subject')),
        body: const Center(child: Text('Subject not found')),
      );
    }

    final subj = _subject!;

    // Prepare date sets for fast lookup (present / absent / canceled)
    final present = <DateTime>{};
    final absent = <DateTime>{};
    final canceled = <DateTime>{};
    subj.attendance.forEach((k, v) {
      try {
        final d = DateTime.parse(k);
        final dt = DateTime(d.year, d.month, d.day);
        if (v == 'present') {
          present.add(dt);
        } else if (v == 'canceled') {
          canceled.add(dt);
        } else {
          absent.add(dt);
        }
      } catch (_) {}
    });

    final firstDay = subj.startDate;
    final lastDay = subj.endDate;

    return Scaffold(
      appBar: AppBar(title: Text(subj.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TableCalendar(
              firstDay: firstDay,
              lastDay: lastDay,
              focusedDay: _focused,
              calendarFormat: CalendarFormat.month,
              onPageChanged: (d) => setState(() => _focused = d),
              headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final d = DateTime(day.year, day.month, day.day);
                  if (present.contains(d)) {
                    return _coloredDay(day.day.toString(), Colors.green[400]!);
                  }
                  if (canceled.contains(d)) {
                    return _coloredDay(day.day.toString(), Colors.grey[400]!);
                  }
                  if (absent.contains(d)) {
                    return _coloredDay(day.day.toString(), Colors.red[400]!);
                  }
                  return Center(child: Text('${day.day}'));
                },
                todayBuilder: (context, day, focusedDay) {
                  final d = DateTime(day.year, day.month, day.day);
                  if (present.contains(d)) {
                    return _coloredDay(day.day.toString(), Colors.green[600]!);
                  }
                  if (canceled.contains(d)) {
                    return _coloredDay(day.day.toString(), Colors.grey[600]!);
                  }
                  if (absent.contains(d)) {
                    return _coloredDay(day.day.toString(), Colors.red[600]!);
                  }
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.primary),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(child: Text('${day.day}')),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                _legendDot(Colors.green[400]!, 'Present'),
                const SizedBox(width: 12),
                _legendDot(Colors.red[400]!, 'Absent'),
                const SizedBox(width: 12),
                _legendDot(Colors.grey[400]!, 'Canceled'),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12.0),
              children: [
                Text('Attendance summary', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Total lectures: ${subj.computeTotalLecturesUntil(DateTime.now())}'),
                Text('Attended: ${subj.computeAttendedLecturesUntil(DateTime.now())}'),
                const SizedBox(height: 12),
                const Text('Legend and details shown above.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coloredDay(String text, Color color) {
    return Container(
      margin: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Center(child: Text(text, style: const TextStyle(color: Colors.white))),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
