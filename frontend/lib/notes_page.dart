import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/api_service.dart';
import 'app_bottom_nav.dart';
import 'instructor_bottom_nav.dart';
import 'app_theme.dart';

class LessonNotesPage extends StatefulWidget {
  const LessonNotesPage({super.key, required this.classId});
  final String classId;

  @override
  State<LessonNotesPage> createState() => _LessonNotesPageState();
}

class _LessonNotesPageState extends State<LessonNotesPage> {
  final TextEditingController _title = TextEditingController();
  bool _submitting = false;
  Map<String, dynamic>? _summary; // store last summary

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickAndAnalyze() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt']);
    if (result == null || result.files.isEmpty) return;
    setState(() { _submitting = true; _summary = null; });
    try {
      final files = <http.MultipartFile>[];
      for (final f in result.files) {
        final path = f.path;
        if (path == null) continue;
        final file = File(path);
        final stream = http.ByteStream(file.openRead());
        final length = await file.length();
        final filename = f.name;
        final multipart = http.MultipartFile('files', stream, length, filename: filename);
        files.add(multipart);
      }
      final res = await ApiService.analyzeNotes(
        files: files,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        classId: widget.classId,
      );
      if (!mounted) return;
      setState(() {
        _summary = res['summary'] as Map<String, dynamic>?;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Analyze failed: $e')));
    } finally {
      if (mounted) setState(() { _submitting = false; });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lesson Notes')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Optional Title',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _pickAndAnalyze,
                    child: const Text('Upload files and Summarize'),
                  ),
                ),
                const SizedBox(height: 16),
                if (_summary != null) ...[
                  const Text('Summary Generated', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const Text('Your lesson notes have been saved!', style: TextStyle(color: Colors.green, fontSize: 14)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildFormattedSummary(),
                    ),
                  ),
                ]
              ],
            ),
          ),
          if (_submitting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Analyzing your notes...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This may take a moment',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormattedSummary() {
    final title = _summary!['title']?.toString() ?? 'Untitled';
    final keyConcepts = (_summary!['key_concepts'] as List?)?.cast<String>() ?? [];
    final mainPoints = (_summary!['main_points'] as List?)?.cast<String>() ?? [];
    final studyTips = (_summary!['study_tips'] as List?)?.cast<String>() ?? [];
    final questions = (_summary!['questions_for_review'] as List?)?.cast<String>() ?? [];
    final difficulty = _summary!['difficulty_level']?.toString() ?? 'intermediate';
    final time = _summary!['estimated_study_time']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),

        // Metadata row
        Row(
          children: [
            _buildMetadataChip(Icons.signal_cellular_alt, difficulty),
            const SizedBox(width: 8),
            _buildMetadataChip(Icons.access_time, time),
          ],
        ),
        const SizedBox(height: 20),

        // Key Concepts
        if (keyConcepts.isNotEmpty) ...[
          _buildSectionHeader('Key Concepts', Icons.lightbulb_outline),
          ...keyConcepts.map((concept) => _buildBulletPoint(concept)),
          const SizedBox(height: 16),
        ],

        // Main Points
        if (mainPoints.isNotEmpty) ...[
          _buildSectionHeader('Main Points', Icons.list_alt),
          ...mainPoints.map((point) => _buildBulletPoint(point)),
          const SizedBox(height: 16),
        ],

        // Study Tips
        if (studyTips.isNotEmpty) ...[
          _buildSectionHeader('Study Tips', Icons.tips_and_updates_outlined),
          ...studyTips.map((tip) => _buildBulletPoint(tip, color: Colors.green)),
          const SizedBox(height: 16),
        ],

        // Questions for Review
        if (questions.isNotEmpty) ...[
          _buildSectionHeader('Questions for Review', Icons.quiz_outlined),
          ...questions.map((q) => _buildBulletPoint(q, color: Colors.orange)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, {Color color = Colors.blue}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.5),
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
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, this.isInstructor = false});
  final bool isInstructor;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _text = TextEditingController();
  List<String> _images = [];
  List<Map<String, dynamic>> _savedNotes = [];
  bool _loading = true;
  bool _showComposer = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await ApiService.listNotes();
      if (!mounted) return;
      setState(() {
        _savedNotes = notes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load notes: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          if (_showComposer)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: () {
                setState(() {
                  _showComposer = false;
                  _title.clear();
                  _text.clear();
                  _images.clear();
                });
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _showComposer
              ? _buildComposer()
              : _buildNotesList(),
      floatingActionButton: _showComposer
          ? null
          : FloatingActionButton(
              onPressed: () {
                setState(() => _showComposer = true);
              },
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: widget.isInstructor
          ? const InstructorBottomNav(currentIndex: 3)
          : const AppBottomNav(currentIndex: 3),
    );
  }

  Widget _buildNotesList() {
    if (_savedNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No notes yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            const Text('Tap + to create your first note'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: _savedNotes.length,
      itemBuilder: (context, index) {
        final note = _savedNotes[index];
        final title = note['title']?.toString() ?? 'Untitled';
        final content = note['content']?.toString() ?? '';
        final preview = content.length > 100 ? '${content.substring(0, 100)}...' : content;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.note)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteNote(note['note_id']?.toString() ?? ''),
            ),
            onTap: () => _viewNote(note),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Expanded(
            child: TextField(
              controller: _text,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: 'Write your notes here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
              ),
            ),
          ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < _images.length; i++)
                    Stack(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.systemGray6,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.image, size: 28, color: AppTheme.systemGray),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() { _images.removeAt(i); });
                            },
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppTheme.errorRed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.spacing16),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final title = _title.text.trim();
                  final content = _text.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Title is required'))
                    );
                    return;
                  }

                  if (content.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Content is required'))
                    );
                    return;
                  }

                  try {
                    await ApiService.createNote(
                      title: title,
                      content: content,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Note saved successfully!'))
                    );
                    // Clear the form and reload notes
                    _title.clear();
                    _text.clear();
                    setState(() => _showComposer = false);
                    await _loadNotes();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save note: $e'))
                    );
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: Text('Save note', style: AppTheme.headline.copyWith(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.iosBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
  }

  Future<void> _viewNote(Map<String, dynamic> note) async {
    final title = note['title']?.toString() ?? '';
    final content = note['content']?.toString() ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNote(String noteId) async {
    if (noteId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteNote(noteId: noteId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note deleted')),
      );
      await _loadNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }
}


