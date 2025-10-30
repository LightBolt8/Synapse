import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'app_theme.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ApiService.signup(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        "", // university not requested; storing empty
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! You can now sign in.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24, vertical: AppTheme.spacing32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create your account',
                      style: AppTheme.title2.copyWith(
                        color: AppTheme.primaryLabel,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      'Join to start collaborating',
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
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              hintText: 'Enter your name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: AppTheme.spacing16),
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
                              hintText: 'Create a password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _isSubmitting ? null : _submit(),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: AppTheme.spacing16),
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacing12),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: AppTheme.footnote.copyWith(
                                  color: AppTheme.errorRed,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppTheme.spacing24),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submit,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Create account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: AppTheme.callout.copyWith(
                            color: AppTheme.secondaryLabel,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Sign in'),
                        ),
                      ],
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


