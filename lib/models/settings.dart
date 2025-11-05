import 'package:hive/hive.dart';

class Settings {
  Settings({required this.minAttendance, required this.darkMode});

  double minAttendance;
  bool darkMode;
}

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 1;

  @override
  Settings read(BinaryReader reader) {
    final min = reader.readDouble();
    final dark = reader.readBool();
    return Settings(minAttendance: min, darkMode: dark);
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer.writeDouble(obj.minAttendance);
    writer.writeBool(obj.darkMode);
  }
}
