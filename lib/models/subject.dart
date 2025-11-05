import 'package:hive/hive.dart';

class Subject {
  Subject({
    required this.id,
    required this.name,
    Map<String, String>? attendance,
    DateTime? startDate,
    DateTime? endDate,
    int? totalLectures,
    int? attendedLectures,
    Map<int, Map<String, int>>? schedule,
  })  : attendance = attendance ?? {},
    startDate = startDate ?? DateTime.now(),
    endDate = endDate ?? DateTime.now(),
    totalLectures = totalLectures ?? 0,
    attendedLectures = attendedLectures ?? 0,
    schedule = schedule ?? {};

  String id;
  String name;
  /// attendance: dateKey (yyyy-MM-dd) -> one of 'present','absent','canceled'
  Map<String, String> attendance;
  int totalLectures;
  int attendedLectures;
  DateTime startDate;
  DateTime endDate;
  /// schedule: weekday (1=Mon .. 7=Sun) -> {'start': minutes, 'end': minutes}
  Map<int, Map<String, int>> schedule;

  double attendancePercent() {
    // compute up to today by default
    final total = computeTotalLecturesUntil(DateTime.now());
    if (total == 0) return 0.0;
    final attended = computeAttendedLecturesUntil(DateTime.now());
    return (attended / total) * 100.0;
  }

  int computeTotalLecturesUntil(DateTime date) {
    // count scheduled lecture days from startDate up to min(endDate, date)
    final last = endDate.isBefore(date) ? endDate : date;
    if (startDate.isAfter(last)) return 0;
    int count = 0;
    DateTime d = DateTime(startDate.year, startDate.month, startDate.day);
    while (!d.isAfter(last)) {
      final wk = d.weekday; // 1..7
      if (schedule.containsKey(wk)) count++;
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  int computeAttendedLecturesUntil(DateTime date) {
    final last = endDate.isBefore(date) ? endDate : date;
    int count = 0;
    attendance.forEach((k, v) {
      if (v != 'present') return;
      try {
        final dt = DateTime.parse(k);
        if (dt.isAfter(last) || dt.isBefore(startDate)) return;
        if (!schedule.containsKey(dt.weekday)) return;
        count++;
      } catch (_) {}
    });
    return count;
  }
}

class SubjectAdapter extends TypeAdapter<Subject> {
  @override
  final int typeId = 0;

  @override
  Subject read(BinaryReader reader) {
    try {
      final id = reader.read() as String;
      final name = reader.read() as String;
      // Support older stored formats (Map<String,bool>) and newer string states.
      final rawAttendance = Map<String, dynamic>.from(reader.read() as Map? ?? {});
      final attendanceMap = <String, String>{};
      rawAttendance.forEach((k, v) {
        try {
          if (v is bool) {
            attendanceMap[k] = v ? 'present' : 'absent';
          } else if (v is String) {
            // accept existing string states (present/absent/canceled) or any other string
            attendanceMap[k] = v;
          } else if (v is int) {
            // treat 1 as present, 0 as absent
            attendanceMap[k] = v == 1 ? 'present' : 'absent';
          }
        } catch (_) {}
      });
      final totalLectures = reader.read() as int;
      final attendedLectures = reader.read() as int;
      final startMillis = reader.read() as int;
      final endMillis = reader.read() as int;
      final rawSchedule = reader.read() as Map? ?? {};
      final scheduleMap = <int, Map<String, int>>{};
      rawSchedule.forEach((k, v) {
        try {
          final wk = k is String ? int.parse(k) : (k as int);
          if (v is Map) {
            final start = (v['start'] ?? v['s'] ?? 0) as int;
            final end = (v['end'] ?? v['e'] ?? 0) as int;
            scheduleMap[wk] = {'start': start, 'end': end};
          }
        } catch (_) {}
      });

      return Subject(
        id: id,
        name: name,
  attendance: attendanceMap,
        totalLectures: totalLectures,
        attendedLectures: attendedLectures,
        startDate: DateTime.fromMillisecondsSinceEpoch(startMillis),
        endDate: DateTime.fromMillisecondsSinceEpoch(endMillis),
        schedule: scheduleMap,
      );
    } catch (e) {
      // If the stored data is an older/partial format or corrupted, recover gracefully.
      // Create a minimal Subject instance so the app can continue. The corrupted entry
      // will be overwritten if the user edits/saves the subject again.
      final fallbackId = DateTime.now().microsecondsSinceEpoch.toString();
      return Subject(id: fallbackId, name: 'Unknown', attendance: {}, schedule: {});
    }
  }

  @override
  void write(BinaryWriter writer, Subject obj) {
    writer.write(obj.id);
    writer.write(obj.name);
    writer.write(obj.attendance);
    writer.write(obj.totalLectures);
    writer.write(obj.attendedLectures);
    writer.write(obj.startDate.millisecondsSinceEpoch);
    writer.write(obj.endDate.millisecondsSinceEpoch);
    // Write schedule as a map of int -> map
    writer.write(obj.schedule);
  }
}

