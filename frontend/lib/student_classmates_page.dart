import 'package:flutter/material.dart';
import 'services/api_service.dart';

class StudentClassmatesPage extends StatefulWidget {
  const StudentClassmatesPage({super.key, required this.classId});
  final String classId;

  @override
  State<StudentClassmatesPage> createState() => _StudentClassmatesPageState();
}

class _StudentClassmatesPageState extends State<StudentClassmatesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await ApiService.getClassRoster(classId: widget.classId);
    final List<dynamic> items = res['roster'] ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classmates')),
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
            return const Center(child: Text('No classmates yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) {
              final u = items[i];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                title: Text(u['full_name'] ?? 'Unknown'),
                subtitle: Text((u['role'] ?? 'student').toString()),
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


