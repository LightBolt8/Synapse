import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'class_search_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'signup_page.dart';
import 'services/api_service.dart';
import 'my_classes_page.dart';
import 'in_class_page.dart';
import 'start_page.dart';
import 'theme_controller.dart';
import 'instructor_my_classes_page.dart';
import 'ai_page.dart';
import 'grades_page.dart';
import 'notes_page.dart';
import 'account_page.dart';
import 'app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<double>(
          valueListenable: ThemeController.instance.textScaleFactor,
          builder: (context, scale, __) {
            return ValueListenableBuilder<Locale?>(
              valueListenable: ThemeController.instance.locale,
              builder: (context, appLocale, ___) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: MaterialApp(
          title: 'CAC Learning',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          locale: appLocale,
          supportedLocales: const [
            Locale('en'), // English
            Locale('zh', 'CN'), // Simplified Chinese
            Locale('fr'), // French
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routes: {
        '/class-search': (context) => const ClassSearchPage(),
        '/sign-up': (context) => const SignUpPage(),
        '/my-classes': (context) => const MyClassesPage(),
        // Student routes for bottom nav
        '/ai': (context) => const AIPage(isInstructor: false),
        '/grades': (context) => const GradesPage(isInstructor: false),
        '/notes': (context) => const NotesPage(isInstructor: false),
        '/account': (context) => const AccountPage(isInstructor: false),
        // Instructor routes
        '/instructor/my-classes': (context) {
          final email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
          return InstructorMyClassesPage(email: email);
        },
        '/instructor/ai': (context) => const AIPage(isInstructor: true),
        '/instructor/grades': (context) => const GradesPage(isInstructor: true),
        '/instructor/notes': (context) => const NotesPage(isInstructor: true),
        '/instructor/account': (context) => const AccountPage(isInstructor: true),
        '/in-class': (context) {
          // Fallback demo route with placeholder ids
          return const InClassPage(classId: 'demo-class', className: 'Class');
        },
          },
          home: const MyHomePage(title: 'Flutter Demo Home Page'),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

 
  void _signIn() async {
  // basic email format check before calling backend
  final email = _emailController.text.trim();
  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!emailRegex.hasMatch(email)) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email address')));
    return;
  }
  debugPrint("🔵 Sign in button pressed!");
  debugPrint("Email: $email");
  debugPrint("Password length: ${_passwordController.text.length}");
  
  setState(() {
    _isLoading = true;
  });

  try {
    debugPrint("🔵 Calling API login...");
    final result = await ApiService.login(
      _emailController.text,
      _passwordController.text,
    );
    
    debugPrint("🟢 Login successful! Result: $result");
    
    // After login, decide where to go based on profile completeness
    try {
      final profile = await ApiService.getProfile(email: _emailController.text.trim());
      final String? role = profile['role'];
      final String? university = profile['university'];
      final String? state = profile['state'];
      final bool needsProfile =
          (role == null || role.isEmpty) ||
          (university == null || university.isEmpty) ||
          (state == null || state.isEmpty);
      if (!mounted) return;
      if (needsProfile) {
        debugPrint("🔵 Navigating to StartPage (collect role/school/state)...");
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => StartPage(email: _emailController.text.trim())),
        );
      } else {
        // role is guaranteed non-null here due to needsProfile == false
        if (role.toLowerCase() == 'instructor') {
          Navigator.of(context).pushReplacementNamed(
            '/instructor/my-classes',
            arguments: _emailController.text.trim(),
          );
        } else {
          debugPrint("🔵 Role=student → go to MyClassesPage...");
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MyClassesPage()),
          );
        }
      }
    } catch (e) {
      // If profile fetch fails, fallback to StartPage so user can complete info
      if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => StartPage(email: _emailController.text.trim())),
          );
    }
    debugPrint("🟢 Navigation complete!");
    
  } catch (e) {
    debugPrint("🔴 Login error: $e");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: ${e.toString()}')));
  }

  setState(() {
    _isLoading = false;
  });
  debugPrint("🔵 Sign in process complete");
}
  
  // Removed unused sign-up dialog and counter

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAC Learning'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Classes',
            onPressed: () {
              Navigator.of(context).pushNamed('/class-search');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
        children: [
          Expanded(
            flex: 2,
            child: Align(
              alignment: const Alignment(0, 0.3),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'Collaborative Learning,\nJust a Click Away',
                  textAlign: TextAlign.center,
                  style: AppTheme.title1.copyWith(
                    color: AppTheme.primaryLabel,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      padding: const EdgeInsets.all(AppTheme.spacing20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
                          TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _isLoading ? null : _signIn(),
                          ),
                          const SizedBox(height: AppTheme.spacing20),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Sign In'),
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text('Forgot password?'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.g_mobiledata, size: 24),
                          label: const Text('Sign in with Google'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.systemGray4),
                            foregroundColor: AppTheme.primaryLabel,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Don\'t have an account?',
                            style: AppTheme.callout.copyWith(
                              color: AppTheme.secondaryLabel,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/sign-up');
                            },
                            child: const Text('Sign up'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
            ),
          ),
        ),
      ),
      // Floating action button removed as counter is unused
    );
  }
}
