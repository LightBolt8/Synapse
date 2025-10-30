import 'package:flutter/material.dart';
import 'services/api_service.dart';

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key, required this.classId});
  final String classId;

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await ApiService.listAssignments(classId: widget.classId);
    final List<dynamic> items = res['assignments'] ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assignments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final titleController = TextEditingController();
          final descController = TextEditingController();
          final dueController = TextEditingController();
          final created = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('New assignment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
                    const SizedBox(height: 8),
                    TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 8),
                    TextField(controller: dueController, decoration: const InputDecoration(labelText: 'Due date (ISO8601)')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
              ],
            ),
          );
          if (created == true) {
            try {
              await ApiService.createAssignment(
                classId: widget.classId,
                title: titleController.text.trim(),
                description: descController.text.trim().isEmpty ? null : descController.text.trim(),
                dueDate: dueController.text.trim().isEmpty ? null : dueController.text.trim(),
              );
              if (!mounted) return;
              setState(() { _future = _load(); });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment created')));
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
            }
          }
        },
        label: const Text('Add Assignment'),
        icon: const Icon(Icons.add),
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
            return const Center(child: Text('No assignments yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final a = items[i];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                title: Text(a['title'] ?? ''),
                subtitle: Text(a['description'] ?? ''),
                onTap: () {
                  // TODO: Navigate to assignment details tab in student's page
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


