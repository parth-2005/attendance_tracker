import 'package:attendance_tracker/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'widgets/biometric_gate.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/subject.dart';
import 'models/settings.dart';
// uuid will be used in the add subject screen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase early
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  await Hive.initFlutter();
  Hive.registerAdapter(SubjectAdapter());
  Hive.registerAdapter(SettingsAdapter());

  // Open boxes (recover from corrupted/old box by deleting and recreating if open fails)
  try {
    await Hive.openBox<Subject>('subjects');
  } catch (e) {
    // attempt to recover by deleting the box and reopening
    try {
      await Hive.deleteBoxFromDisk('subjects');
    } catch (_) {}
    await Hive.openBox<Subject>('subjects');
  }

  try {
    await Hive.openBox<Settings>('settings');
  } catch (e) {
    try {
      await Hive.deleteBoxFromDisk('settings');
    } catch (_) {}
    await Hive.openBox<Settings>('settings');
  }

  // Remove any fallback 'Unknown' subjects created during earlier recovery
  final subjectsBox = Hive.box<Subject>('subjects');
  final toRemove = <dynamic>[];
  for (final key in subjectsBox.keys) {
    try {
      final s = subjectsBox.get(key);
      if (s != null && s.name == 'Unknown') toRemove.add(key);
    } catch (_) {}
  }
  for (final k in toRemove) {
    await subjectsBox.delete(k);
  }

  // Ensure a default settings entry
  final settingsBox = Hive.box<Settings>('settings');
  if (!settingsBox.containsKey('prefs')) {
    settingsBox.put('prefs', Settings(minAttendance: 75.0, darkMode: true));
  }

  runApp(BiometricGate(child: const App()));
}