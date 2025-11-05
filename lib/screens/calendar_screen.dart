import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import '../models/subject.dart';

class CalendarScreen extends StatefulWidget {
  final String? subjectId;
  const CalendarScreen({super.key, this.subjectId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  final Map<String, bool> _animating = {};
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, List<Color>> _events = {};
  List<Subject> _subjects = [];

  static const _palette = [
    Colors.blue,
    Colors.teal,
    Colors.purple,
    Colors.amber,
    Colors.green,
    Colors.orange,
    Colors.pink,
    Colors.indigo,
    Colors.red,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
  final box = Hive.box<Subject>('subjects');
  _subjects = box.values.toList();
  _buildEvents();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focused,
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            onDaySelected: (s, f) => setState(() {
              _selected = s;
              _focused = f;
            }),
            onFormatChanged: (format) => setState(() => _calendarFormat = format),
            eventLoader: (day) {
              final d = DateTime(day.year, day.month, day.day);
              return _events[d] ?? const [];
            },
            calendarBuilders: CalendarBuilders(markerBuilder: (context, day, events) {
              if (events.isEmpty) return const SizedBox.shrink();
              // events are Colors stored as dynamic
              final colors = events.cast<Color>();
              return Padding(
                padding: const EdgeInsets.only(top: 28.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: colors.take(5).map((c) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.0),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                      )).toList(),
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(_selected.toLocal().toIso8601String().split('T').first, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: box.listenable(),
              builder: (context, Box<Subject> b, _) {
                final subjects = b.values.toList();
                if (subjects.isEmpty) return const Center(child: Text('No subjects added'));

                final dateKey = _selected.toIso8601String().split('T').first;
                final weekday = _selected.weekday; // 1..7
                return ListView.builder(
                  itemCount: subjects.length,
                  itemBuilder: (context, idx) {
                    final s = subjects[idx];
                    final current = s.attendance[dateKey];

                    // If this CalendarScreen is parameterized for a particular subject,
                    // only show that subject and allow marking as before.
                    final today = DateTime.now();

                    if (widget.subjectId != null) {
                      if (s.id != widget.subjectId) return const SizedBox.shrink();

                      final hasSchedule = s.schedule.isEmpty ? true : s.schedule.containsKey(weekday);
                      final inRange = !_selected.isBefore(s.startDate) && !_selected.isAfter(s.endDate);
                      // do not allow marking on future dates
                      final notFuture = !_selected.isAfter(DateTime(today.year, today.month, today.day));
                      final canMark = hasSchedule && inRange && notFuture;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                        child: ListTile(
                          title: Text(s.name),
                          trailing: canMark
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: AnimatedScale(
                                        scale: _animating[s.id] == true ? 1.4 : 1.0,
                                        duration: const Duration(milliseconds: 180),
                                        child: const Icon(Icons.check, color: Colors.green),
                                      ),
                                      onPressed: () => _markAttendance(s, dateKey, true),
                                    ),
                                    IconButton(
                                      icon: AnimatedScale(
                                        scale: _animating[s.id] == true ? 1.4 : 1.0,
                                        duration: const Duration(milliseconds: 180),
                                        child: const Icon(Icons.close, color: Colors.red),
                                      ),
                                      onPressed: () => _markAttendance(s, dateKey, false),
                                    ),
                                  ],
                                )
                              : null,
                          subtitle: current == null ? const Text('Not marked') : Text(current ? 'Present' : 'Absent'),
                        ),
                      );
                    }

                    // Otherwise (multi-subject calendar) show subject row with its color and marking summary
                    final color = _colorForSubject(s);
                    final hasSchedule = s.schedule.isEmpty ? true : s.schedule.containsKey(weekday);
                    final inRange = !_selected.isBefore(s.startDate) && !_selected.isAfter(s.endDate);
                    final notFutureMulti = !_selected.isAfter(DateTime(today.year, today.month, today.day));
                    final canMarkMulti = hasSchedule && inRange && notFutureMulti;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      child: ListTile(
                        leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                        title: Text(s.name),
                        subtitle: current == null ? const Text('Not marked on this date') : Text(current ? 'Present' : 'Absent'),
                        trailing: canMarkMulti
                            ? IconButton(
                                icon: AnimatedScale(
                                  scale: _animating[s.id] == true ? 1.4 : 1.0,
                                  duration: const Duration(milliseconds: 180),
                                  child: const Icon(Icons.check, color: Colors.green),
                                ),
                                onPressed: () => _markAttendance(s, dateKey, true),
                              )
                            : null,
                        onTap: () {
                          try {
                            GoRouter.of(context).push('/calendar/${s.id}');
                          } catch (_) {}
                        },
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _buildEvents() {
    _events = {};
    if (widget.subjectId != null) {
      // subject-specific: show green for present, red for absent
  final matches = _subjects.where((e) => e.id == widget.subjectId).toList();
  if (matches.isEmpty) return;
  final subj = matches.first;
  subj.attendance.forEach((k, v) {
        try {
          final d = DateTime.parse(k);
          final date = DateTime(d.year, d.month, d.day);
          final color = v == true ? Colors.green : Colors.red;
          _events.putIfAbsent(date, () => []).add(color);
        } catch (_) {}
      });
    } else {
      // multi-subject: show colored dots only for presents (green per-subject color)
      for (var i = 0; i < _subjects.length; i++) {
        final s = _subjects[i];
        final color = _colorForSubject(s);
        s.attendance.forEach((k, v) {
          try {
            if (v != true) return; // only show presents in multi-subject view
            final d = DateTime.parse(k);
            final date = DateTime(d.year, d.month, d.day);
            _events.putIfAbsent(date, () => []).add(color);
          } catch (_) {}
        });
      }
    }
  }

  Color _colorForSubject(Subject s) {
    final i = _subjects.indexWhere((e) => e.id == s.id);
    final idx = i < 0 ? s.id.hashCode.abs() % _palette.length : i % _palette.length;
    return _palette[idx];
  }

  void _markAttendance(Subject s, String dateKey, bool present) {
    final box = Hive.box<Subject>('subjects');
  // previous value (if any) - currently unused since totals are computed
  // from the attendance map on demand.
  // final prev = s.attendance[dateKey];

    // Trigger a small scale animation on the subject row
    _animating[s.id] = true;
    setState(() {});

    Future.delayed(const Duration(milliseconds: 250), () {
      _animating[s.id] = false;
      if (mounted) setState(() {});
    });

    // Update attendance map only. Totals are computed on-demand from schedule and
    // attendance map (computeTotalLecturesUntil / computeAttendedLecturesUntil).
    // prevent marking on future dates
    try {
      final dt = DateTime.parse(dateKey);
      final todayDate = DateTime.now();
      final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
      final target = DateTime(dt.year, dt.month, dt.day);
      if (target.isAfter(today)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot mark attendance for future dates')));
        return;
      }
    } catch (_) {}

    s.attendance[dateKey] = present;
    awaitPut(box, s);
    setState(() {});
  }

  // helper to put subject while keeping UI responsive
  void awaitPut(Box<Subject> box, Subject s) {
    // write to box asynchronously; Hive put is synchronous but we keep this
    // helper for future-proofing and potential async wrappers.
    box.put(s.id, s);
  }
}
