import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/settings.dart';
import '../models/subject.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Box<Settings> _settingsBox;

  @override
  void initState() {
    super.initState();
    _settingsBox = Hive.box<Settings>('settings');
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _settingsBox.get('prefs') ?? Settings(minAttendance: 75.0, darkMode: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Minimum attendance (%):", style: TextStyle(fontWeight: FontWeight.bold)),
            // textfield
            TextField(
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: prefs.minAttendance.toStringAsFixed(0)),
              onChanged: (v) {
                final val = double.tryParse(v);
                if (val != null && val >= 0 && val <= 100) {
                  prefs.minAttendance = val;
                  _settingsBox.put('prefs', prefs);
                }
              },
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(hintText: 'Enter a value between 0 and 100'),
            ),
            const SizedBox(height: 12.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Dark mode'),
                Switch(
                  value: prefs.darkMode,
                  onChanged: (v) {
                    prefs.darkMode = v;
                    _settingsBox.put('prefs', prefs);
                    setState(() {});
                  },
                )
              ],
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: () async {
                final subjectsBox = Hive.box<Subject>('subjects');
                final messenger = ScaffoldMessenger.of(context);
                await subjectsBox.clear();
                if (!mounted) return;
                messenger.showSnackBar(const SnackBar(content: Text('All data reset')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Reset all data', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
