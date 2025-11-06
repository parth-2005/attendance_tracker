import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/settings.dart';

/// A widget that blocks its child behind an optional biometric authentication
/// gate if the user enabled biometric protection in settings.
class BiometricGate extends StatefulWidget {
  final Widget child;
  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _authenticated = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAuthenticate());
  }

  Future<void> _maybeAuthenticate() async {
    try {
      final settingsBox = Hive.box<Settings>('settings');
      final prefs = settingsBox.get('prefs') ?? Settings(minAttendance: 75.0, darkMode: true);
      if (!prefs.useBiometric) {
        setState(() { _authenticated = true; _checking = false; });
        return;
      }

      final canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) {
        // Device doesn't support biometrics — allow access but keep setting so user
        // can disable it from settings.
        setState(() { _authenticated = true; _checking = false; });
        return;
      }

      final didAuth = await _auth.authenticate(
        localizedReason: 'Please authenticate to access Attendance Tracker',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      setState(() { _authenticated = didAuth; _checking = false; });
    } catch (_) {
      setState(() { _authenticated = true; _checking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    if (!_authenticated) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Authentication required'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _maybeAuthenticate,
                  child: const Text('Try again'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    // Allow user to disable biometric from settings if they can't auth.
                    final settingsBox = Hive.box<Settings>('settings');
                    final prefs = settingsBox.get('prefs') ?? Settings(minAttendance: 75.0, darkMode: true);
                    prefs.useBiometric = false;
                    await settingsBox.put('prefs', prefs);
                    if (mounted) setState(() { _authenticated = true; });
                  },
                  child: const Text('Disable biometric'),
                )
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
