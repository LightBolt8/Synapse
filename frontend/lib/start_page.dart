import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'my_classes_page.dart';
import 'create_class_page.dart';
import 'app_theme.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key, required this.email});

  final String email;

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  String _role = 'student';
  final TextEditingController _schoolController = TextEditingController();
  final List<String> _states = const [
    'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY'
  ];
  String? _selectedState;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiService.updateProfile(
        role: _role,
        university: _schoolController.text.trim(),
        state: (_selectedState ?? '').trim(),
        email: widget.email,
      );
      if (!mounted) return;
      if (_role == 'instructor') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => CreateClassPage(email: widget.email)),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MyClassesPage()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppTheme.spacing24),
                    Text(
                      'Tell us about you',
                      style: AppTheme.title1.copyWith(
                        color: AppTheme.primaryLabel,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      'Help us personalize your experience',
                      style: AppTheme.callout.copyWith(
                        color: AppTheme.secondaryLabel,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacing32),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      padding: const EdgeInsets.all(AppTheme.spacing24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'I am a...',
                            style: AppTheme.headline.copyWith(
                              color: AppTheme.primaryLabel,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          // iOS-style segmented control look
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.systemGray6,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _role = 'student'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
                                      decoration: BoxDecoration(
                                        color: _role == 'student' ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium - 2),
                                        boxShadow: _role == 'student'
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Student',
                                        style: AppTheme.callout.copyWith(
                                          color: _role == 'student'
                                              ? AppTheme.primaryLabel
                                              : AppTheme.secondaryLabel,
                                          fontWeight: _role == 'student' ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _role = 'instructor'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
                                      decoration: BoxDecoration(
                                        color: _role == 'instructor' ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium - 2),
                                        boxShadow: _role == 'instructor'
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Instructor',
                                        style: AppTheme.callout.copyWith(
                                          color: _role == 'instructor'
                                              ? AppTheme.primaryLabel
                                              : AppTheme.secondaryLabel,
                                          fontWeight: _role == 'instructor' ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing24),
                          TextField(
                            controller: _schoolController,
                            decoration: const InputDecoration(
                              labelText: 'School / University',
                              hintText: 'Enter your institution',
                              prefixIcon: Icon(Icons.school_outlined),
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          DropdownButtonFormField<String>(
                            value: _selectedState,
                            items: _states
                                .map((abbr) => DropdownMenuItem(value: abbr, child: Text(abbr)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedState = v),
                            decoration: const InputDecoration(
                              labelText: 'State',
                              hintText: 'Select your state',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AppTheme.spacing16),
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacing12),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Text(
                                _error!,
                                style: AppTheme.footnote.copyWith(
                                  color: AppTheme.errorRed,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


