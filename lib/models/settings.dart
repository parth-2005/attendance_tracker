import 'package:hive/hive.dart';

class Settings {
  Settings({required this.minAttendance, required this.darkMode, this.useBiometric = false, this.holidayCalendarId = ''});

  double minAttendance;
  bool darkMode;
  /// Whether the app is protected by biometric auth
  bool useBiometric;
  /// Optional chosen holiday calendar id (e.g. en.usa#holiday@group.v.calendar.google.com)
  String holidayCalendarId;
}

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 1;

  @override
  Settings read(BinaryReader reader) {
    try {
      final min = reader.readDouble();
      final dark = reader.readBool();
      // older versions had only two fields; newer versions append extra fields.
      bool useBiometric = false;
      String holidayCalendarId = '';
      try {
        useBiometric = reader.readBool();
      } catch (_) {}
      try {
        holidayCalendarId = reader.read() as String? ?? '';
      } catch (_) {}
      return Settings(minAttendance: min, darkMode: dark, useBiometric: useBiometric, holidayCalendarId: holidayCalendarId);
    } catch (_) {
      // fallback defaults
      return Settings(minAttendance: 75.0, darkMode: true);
    }
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer.writeDouble(obj.minAttendance);
    writer.writeBool(obj.darkMode);
    writer.writeBool(obj.useBiometric);
    writer.write(obj.holidayCalendarId);
  }
}
