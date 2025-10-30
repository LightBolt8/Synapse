import 'package:flutter/material.dart';
import 'app_bottom_nav.dart';
import 'instructor_bottom_nav.dart';
import 'services/api_service.dart';
import 'main.dart';
import 'theme_controller.dart';
import 'app_theme.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.isInstructor = false});
  final bool isInstructor;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _notifications = true;
  bool _dataSaver = false;
  bool _biometrics = false;
  double _textScale = ThemeController.instance.textScaleFactor.value;
  String _language = _localeToLabel(ThemeController.instance.locale.value);

  void _changePasswordDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                decoration: const InputDecoration(labelText: 'Current password'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newController,
                decoration: const InputDecoration(labelText: 'New password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password change requested')));
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme / Brightness
          ListTile(
            title: const Text('Appearance'),
            subtitle: const Text('Light / Dark / System'),
            trailing: DropdownButton<ThemeMode>(
              value: ThemeController.instance.themeMode.value,
              onChanged: (mode) {
                if (mode != null) ThemeController.instance.setThemeMode(mode);
                setState(() {});
              },
              items: const [
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              ],
            ),
          ),
          const Divider(),

          // Text size
          ListTile(
            title: const Text('Text size'),
            subtitle: Slider(
              value: _textScale,
              min: 0.8,
              max: 1.4,
              divisions: 6,
              label: _textScale.toStringAsFixed(1),
              onChanged: (v) {
                setState(() => _textScale = v);
                ThemeController.instance.setTextScale(v);
              },
            ),
          ),
          const Divider(),

          // Language
          ListTile(
            title: const Text('Language'),
            trailing: DropdownButton<String>(
              value: _language,
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: '简体中文', child: Text('简体中文')),
                DropdownMenuItem(value: 'Français', child: Text('Français')),
              ],
              onChanged: (v) {
                final String selected = v ?? 'English';
                setState(() => _language = selected);
                ThemeController.instance.setLocale(_labelToLocale(selected));
              },
            ),
          ),
          const Divider(),

          // Toggles
          SwitchListTile(
            title: const Text('Notifications'),
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
          SwitchListTile(
            title: const Text('Data saver'),
            value: _dataSaver,
            onChanged: (v) => setState(() => _dataSaver = v),
          ),
          SwitchListTile(
            title: const Text('Use biometrics'),
            value: _biometrics,
            onChanged: (v) => setState(() => _biometrics = v),
          ),
          const Divider(),

          // Account
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Account info'),
            subtitle: const Text('Email, name, school'),
            onTap: () {
              // Could navigate to a profile edit page
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account info coming soon')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change password'),
            onTap: _changePasswordDialog,
          ),
          const SizedBox(height: AppTheme.spacing16),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.iosBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                try {
                  await ApiService.signOut();
                } catch (_) {}
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MyApp()),
                  (route) => false,
                );
              },
              child: Text('Sign out', style: AppTheme.headline.copyWith(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 24),

          // Misc
          ListTile(
            leading: const Icon(Icons.vibration),
            title: const Text('Haptics'),
            subtitle: const Text('Enable subtle vibrations'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Haptics toggled')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear cache'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared')));
            },
          ),
        ],
      ),
      bottomNavigationBar: widget.isInstructor
          ? const InstructorBottomNav(currentIndex: 4)
          : const AppBottomNav(currentIndex: 4),
    );
  }
}

String _localeToLabel(Locale? locale) {
  if (locale == null) return 'English';
  if (locale.languageCode == 'zh') return '简体中文';
  if (locale.languageCode == 'fr') return 'Français';
  return 'English';
}

Locale? _labelToLocale(String label) {
  switch (label) {
    case '简体中文':
      return const Locale('zh', 'CN');
    case 'Français':
      return const Locale('fr');
    case 'English':
    default:
      return const Locale('en');
  }
}


