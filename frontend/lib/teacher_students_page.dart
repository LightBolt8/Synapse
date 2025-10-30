import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'teacher_create_assignment_page.dart';

class TeacherStudentsPage extends StatefulWidget {
  const TeacherStudentsPage({super.key, required this.classId});
  final String classId;

  @override
  State<TeacherStudentsPage> createState() => _TeacherStudentsPageState();
}

class _TeacherStudentsPageState extends State<TeacherStudentsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await ApiService.getClassRoster(classId: widget.classId);
    final List<dynamic> items = res['roster'] ?? [];
    // Only students for teacher view
    final students = items.where((e) => (e['role'] ?? 'student') == 'student').toList();
    return students.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            onPressed: () async {
              final created = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TeacherCreateAssignmentPage(classId: widget.classId),
                ),
              );
              if (created == true) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment created')));
              }
            },
            tooltip: 'Create assignment',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No students yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final u = items[i];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                title: Text(u['full_name'] ?? 'Unknown'),
                subtitle: const Text('Tap to view grades'),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove_outlined),
                  tooltip: 'Remove from class',
                  onPressed: () async {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove student?'),
                        content: Text('Remove ${u['full_name'] ?? 'this student'} from the class?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await ApiService.removeStudent(classId: widget.classId, studentId: (u['user_id'] ?? '').toString());
                        if (!mounted) return;
                        setState(() { _future = _load(); });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed')));
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
                      }
                    }
                  },
                ),
                onTap: () {
                  // TODO: navigate to per-student grades for assignments
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}


