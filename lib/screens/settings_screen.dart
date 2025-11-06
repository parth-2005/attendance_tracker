import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/google_service.dart';
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
    final acct = GoogleService.instance.currentUser;

    // Common holiday calendar IDs for some locales. The user can also enter
    // a custom calendar id (for example: en.usa#holiday@group.v.calendar.google.com)
    const commonHolidayIds = {
      'United States': 'en.usa#holiday@group.v.calendar.google.com',
      'United Kingdom': 'en.uk#holiday@group.v.calendar.google.com',
      'India': 'en.indian#holiday@group.v.calendar.google.com',
    };

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
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Require biometric'),
                Switch(
                  value: prefs.useBiometric,
                  onChanged: (v) async {
                    prefs.useBiometric = v;
                    await _settingsBox.put('prefs', prefs);
                    setState(() {});
                  },
                )
              ],
            ),
            const SizedBox(height: 24.0),
            const Divider(),
            const SizedBox(height: 8.0),
            Text('Google account', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8.0),
            acct == null
                ? ElevatedButton.icon(
                    onPressed: () async {
                      final a = await GoogleService.instance.signIn();
                      if (a != null && mounted) setState(() {});
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                  )
                : Row(
                    children: [
                      CircleAvatar(backgroundImage: acct.photoUrl != null ? NetworkImage(acct.photoUrl!) : null, child: acct.photoUrl == null ? const Icon(Icons.person) : null),
                      const SizedBox(width: 12),
                      Expanded(child: Text(acct.displayName ?? acct.email)),
                      TextButton(
                        onPressed: () async {
                          await GoogleService.instance.signOut();
                          if (mounted) setState(() {});
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ElevatedButton(
              onPressed: () async {
                final subjectsBox = Hive.box<Subject>('subjects');
                await subjectsBox.clear();
                if (!mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(const SnackBar(content: Text('All data reset')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Reset all data', style: TextStyle(color: Colors.white)),
            )
            ,
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Holidays & Google Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: prefs.holidayCalendarId.isEmpty ? null : prefs.holidayCalendarId,
                    items: commonHolidayIds.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
                    decoration: const InputDecoration(labelText: 'Choose common holiday calendar'),
                    onChanged: (v) async {
                      prefs.holidayCalendarId = v ?? '';
                      await _settingsBox.put('prefs', prefs);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Or custom calendar id'),
              controller: TextEditingController(text: prefs.holidayCalendarId),
              onChanged: (v) async {
                prefs.holidayCalendarId = v.trim();
                await _settingsBox.put('prefs', prefs);
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      // Ensure signed in
                      if (GoogleService.instance.currentUser == null) {
                        final acct = await GoogleService.instance.signIn();
                        if (acct == null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign-in required to import holidays')));
                          return;
                        }
                      }

                      final calId = prefs.holidayCalendarId.isEmpty ? null : prefs.holidayCalendarId;
                      if (calId == null || calId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select or enter a holiday calendar id first')));
                        return;
                      }

                      final from = DateTime.now().subtract(const Duration(days: 365));
                      final to = DateTime.now().add(const Duration(days: 365));

                      // Use the new helper to get events organized by date
                      final dateMap = await GoogleService.instance.fetchHolidayEventsByDate(calId, from, to);
                      if (!mounted) return;
                      if (dateMap.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No holiday events found or unable to fetch')));
                        return;
                      }

                      // Compute how many subject-markings would be applied
                      final subjectsBox = Hive.box<Subject>('subjects');
                      final dateKeys = dateMap.keys.toList()..sort();
                      int wouldMark = 0;
                      for (final dk in dateKeys) {
                        try {
                          final d = DateTime.parse(dk);
                          for (final s in subjectsBox.values) {
                            if (d.isBefore(s.startDate) || d.isAfter(s.endDate)) continue;
                            if (s.schedule.isNotEmpty && !s.schedule.containsKey(d.weekday)) continue;
                            if (s.attendance[dk] != 'canceled') wouldMark++;
                          }
                        } catch (_) {}
                      }

                      // Show preview dialog with date list and count
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Import holidays — preview'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Found ${dateKeys.length} holiday dates. This will mark $wouldMark subject entries as canceled.'),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: dateKeys.length,
                                    itemBuilder: (_, ix) {
                                      final key = dateKeys[ix];
                                      final evs = dateMap[key] ?? [];
                                      final title = evs.isNotEmpty ? (evs.first.summary ?? evs.first.id ?? 'Holiday') : 'Holiday';
                                      return ListTile(
                                        title: Text(key),
                                        subtitle: Text('$title (${evs.length} event${evs.length == 1 ? '' : 's'})'),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Confirm')),
                          ],
                        ),
                      );

                      if (confirmed != true) return;

                      // Apply markings
                      int marked = 0;
                      for (final dk in dateKeys) {
                        try {
                          final d = DateTime.parse(dk);
                          for (final s in subjectsBox.values) {
                            try {
                              if (d.isBefore(s.startDate) || d.isAfter(s.endDate)) continue;
                              if (s.schedule.isNotEmpty && !s.schedule.containsKey(d.weekday)) continue;
                              if (s.attendance[dk] != 'canceled') {
                                s.attendance[dk] = 'canceled';
                                await subjectsBox.put(s.id, s);
                                marked++;
                              }
                            } catch (_) {}
                          }
                        } catch (_) {}
                      }

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $marked holiday markings')));
                    },
                    child: const Text('Import holidays (mark canceled)'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      // Quick: list visible calendars for user to pick id
                      if (GoogleService.instance.currentUser == null) {
                        final acct = await GoogleService.instance.signIn();
                        if (acct == null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign-in required')));
                          return;
                        }
                      }
                      final list = await GoogleService.instance.listCalendars();
                      if (!mounted) return;
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Choose a calendar'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView(
                              shrinkWrap: true,
                              children: (list as List).map((c) {
                                final dyn = c as dynamic;
                                final id = dyn.id ?? '';
                                final title = dyn.summary ?? id;
                                return ListTile(
                                  title: Text(title),
                                  subtitle: Text(id.toString()),
                                  onTap: () async {
                                    prefs.holidayCalendarId = id.toString();
                                    await _settingsBox.put('prefs', prefs);
                                    if (mounted) setState(() {});
                                    Navigator.of(context).pop();
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text('Choose calendar...'),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
