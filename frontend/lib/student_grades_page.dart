import 'package:flutter/material.dart';
import 'services/api_service.dart';

class StudentGradesPage extends StatefulWidget {
  const StudentGradesPage({super.key, required this.classId, required this.studentId});
  final String classId;
  final String studentId;

  @override
  State<StudentGradesPage> createState() => _StudentGradesPageState();
}

class _StudentGradesPageState extends State<StudentGradesPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getClassGradesForStudent(
      classId: widget.classId,
      studentId: widget.studentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Grades')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final data = snap.data ?? const {};
          final List<dynamic> grades = data['grades'] ?? [];
          final dynamic finalGrade = data['final_grade'];
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (finalGrade != null)
                  Text('Final grade: ${finalGrade.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemBuilder: (context, i) {
                      final g = grades[i] as Map<String, dynamic>;
                      return ListTile(
                        title: Text('Assignment ${g['assignment_id'] ?? ''}'),
                        trailing: Text((g['grade'] ?? '').toString()),
                        subtitle: Text('Updated: ${g['updated_at'] ?? ''}'),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: grades.length,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


