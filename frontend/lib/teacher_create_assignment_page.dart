import 'package:flutter/material.dart';
import 'services/api_service.dart';

class TeacherCreateAssignmentPage extends StatefulWidget {
  const TeacherCreateAssignmentPage({super.key, required this.classId});
  final String classId;

  @override
  State<TeacherCreateAssignmentPage> createState() => _TeacherCreateAssignmentPageState();
}

class _TeacherCreateAssignmentPageState extends State<TeacherCreateAssignmentPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    setState(() { _submitting = true; });
    try {
      await ApiService.createAssignment(
        classId: widget.classId,
        title: _title.text.trim(),
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() { _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Assignment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting ? const CircularProgressIndicator() : const Text('Create'),
              ),
            )
          ],
        ),
      ),
    );
  }
}


