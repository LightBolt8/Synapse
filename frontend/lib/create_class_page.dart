import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'my_classes_page.dart';

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key, required this.email});
  final String email;

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    try {
      final result = await ApiService.createClass(
        name: _nameController.text.trim(),
        email: widget.email,
      );
      if (!mounted) return;
      final code = result['code'] as String? ?? '';
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Class Created'),
          content: SelectableText('Join code: $code'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
          ],
        ),
      );
      // After creating a class as instructor, go back to instructor classes
      Navigator.of(context).pushReplacementNamed(
        '/instructor/my-classes',
        arguments: widget.email,
      );
    } catch (e) {
      setState(() { _error = e.toString(); _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Class'), backgroundColor: scheme.inversePrimary),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Class name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
              ],
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting ? const SizedBox(height:16,width:16,child:CircularProgressIndicator(strokeWidth:2)) : const Text('Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


