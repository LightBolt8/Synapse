import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'notes_page.dart';

class ClassNotesPage extends StatefulWidget {
  const ClassNotesPage({super.key, required this.classId, required this.className});
  final String classId;
  final String className;

  @override
  State<ClassNotesPage> createState() => _ClassNotesPageState();
}

class _ClassNotesPageState extends State<ClassNotesPage> {
  late Future<List<Map<String, dynamic>>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _notesFuture = _loadNotes();
  }

  Future<List<Map<String, dynamic>>> _loadNotes() async {
    return await ApiService.listClassNoteSummaries(classId: widget.classId);
  }

  Future<void> _refresh() async {
    setState(() {
      _notesFuture = _loadNotes();
    });
  }

  void _viewNoteDetails(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notes, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        note['title'] ?? 'Untitled',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildFormattedNoteContent(note),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedNoteContent(Map<String, dynamic> note) {
    final List<Widget> widgets = [];

    final keyConcepts = (note['key_concepts'] as List?)?.cast<String>() ?? [];
    final mainPoints = (note['main_points'] as List?)?.cast<String>() ?? [];
    final studyTips = (note['study_tips'] as List?)?.cast<String>() ?? [];
    final questions = (note['questions_for_review'] as List?)?.cast<String>() ?? [];
    final difficulty = note['difficulty_level']?.toString() ?? 'intermediate';
    final time = note['estimated_study_time']?.toString() ?? '';

    // Metadata chips
    if (difficulty.isNotEmpty || time.isNotEmpty) {
      widgets.add(Row(
        children: [
          if (difficulty.isNotEmpty) _buildMetadataChip(Icons.signal_cellular_alt, difficulty),
          if (difficulty.isNotEmpty && time.isNotEmpty) const SizedBox(width: 8),
          if (time.isNotEmpty) _buildMetadataChip(Icons.access_time, time),
        ],
      ));
      widgets.add(const SizedBox(height: 20));
    }

    // Key Concepts
    if (keyConcepts.isNotEmpty) {
      widgets.add(_buildSectionHeader('Key Concepts', Icons.lightbulb_outline));
      for (final concept in keyConcepts) {
        widgets.add(_buildBulletPoint(concept, Colors.blue));
      }
      widgets.add(const SizedBox(height: 16));
    }

    // Main Points
    if (mainPoints.isNotEmpty) {
      widgets.add(_buildSectionHeader('Main Points', Icons.check_circle_outline));
      for (final point in mainPoints) {
        widgets.add(_buildBulletPoint(point, Colors.green));
      }
      widgets.add(const SizedBox(height: 16));
    }

    // Study Tips
    if (studyTips.isNotEmpty) {
      widgets.add(_buildSectionHeader('Study Tips', Icons.tips_and_updates_outlined));
      for (final tip in studyTips) {
        widgets.add(_buildBulletPoint(tip, Colors.orange));
      }
      widgets.add(const SizedBox(height: 16));
    }

    // Questions for Review
    if (questions.isNotEmpty) {
      widgets.add(_buildSectionHeader('Questions for Review', Icons.quiz_outlined));
      for (final question in questions) {
        widgets.add(_buildBulletPoint(question, Colors.purple));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.blue),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} - Lesson Notes'),
        backgroundColor: scheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LessonNotesPage(classId: widget.classId),
            ),
          );
          // Refresh notes list after returning from upload page
          _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('Upload Notes'),
        backgroundColor: Colors.blue,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _notesFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final notes = snap.data ?? const [];
            if (notes.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notes_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No lesson notes yet.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final note = notes[index];
                final title = (note['title'] ?? 'Untitled').toString();
                final difficulty = (note['difficulty_level'] ?? 'intermediate').toString();
                final time = (note['estimated_study_time'] ?? '').toString();
                final createdAt = note['created_at'] ?? '';

                return InkWell(
                  onTap: () => _viewNoteDetails(note),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notes, size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildMetadataChip(Icons.signal_cellular_alt, difficulty),
                            const SizedBox(width: 8),
                            if (time.isNotEmpty) _buildMetadataChip(Icons.access_time, time),
                          ],
                        ),
                        if (createdAt.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Created: ${_formatDate(createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is String) {
        final dt = DateTime.parse(date);
        return '${dt.month}/${dt.day}/${dt.year}';
      }
      return '';
    } catch (e) {
      return '';
    }
  }
}
