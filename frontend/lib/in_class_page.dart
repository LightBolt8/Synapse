import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_bottom_nav.dart';
import 'instructor_bottom_nav.dart';
import 'student_classmates_page.dart';
import 'teacher_students_page.dart';
import 'student_grades_page.dart';
import 'student_assignments_page.dart';
import 'services/api_service.dart';
import 'notes_page.dart';
import 'class_notes_page.dart';
import 'posts_page.dart';
import 'app_theme.dart';

class InClassPage extends StatefulWidget {
  const InClassPage({super.key, required this.classId, required this.className, this.isInstructor = false});

  final String classId;
  final String className;
  final bool isInstructor;

  @override
  State<InClassPage> createState() => _InClassPageState();
}

class _InClassPageState extends State<InClassPage> {
  bool _showComposer = false;
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _postTitleController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  Map<String, dynamic>? _classDetails; // includes join_code for instructors
  bool _loadingDetails = true;

  @override
  void dispose() {
    _postController.dispose();
    _postTitleController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final details = await ApiService.getClassDetails(classId: widget.classId);
      if (!mounted) return;
      setState(() {
        _classDetails = details;
        _loadingDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingDetails = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        backgroundColor: scheme.inversePrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loadingDetails)
                const LinearProgressIndicator(minHeight: 2),
              if (!_loadingDetails && (_classDetails?['join_code'] != null)) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Join code: ${_classDetails!['join_code']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy',
                        onPressed: () {
                          final code = (_classDetails!['join_code'] ?? '').toString();
                          if (code.isEmpty) return;
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied join code')));
                        },
                        icon: const Icon(Icons.copy_all_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.iosBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    setState(() {
                      _showComposer = true;
                    });
                  },
                  child: Text('New Post', style: AppTheme.headline),
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.iosBlue),
                    foregroundColor: AppTheme.iosBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostsPage(
                          classId: widget.classId,
                          className: widget.className,
                        ),
                      ),
                    );
                  },
                  child: Text('See Posts', style: AppTheme.headline),
                ),
              ),
              const SizedBox(height: 12),
              if (_showComposer) ...[
                TextField(
                  controller: _postTitleController,
                  decoration: InputDecoration(
                    hintText: 'Title (required)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _postController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: 'Write your post here...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _imageUrlController,
                  decoration: InputDecoration(
                    hintText: 'Optional image URL (png/jpg)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final title = _postTitleController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Title is required')),
                            );
                            return;
                          }
                          final content = _postController.text.trim();
                          final imageUrl = _imageUrlController.text.trim();
                          try {
                            await ApiService.createPost(
                              classId: widget.classId,
                              title: title,
                              content: content.isEmpty ? null : content,
                              imageUrl: imageUrl.isEmpty ? null : imageUrl,
                            );
                            if (!mounted) return;
                            FocusScope.of(context).unfocus();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post submitted')),
                            );
                            setState(() {
                              _showComposer = false;
                              _postTitleController.clear();
                              _postController.clear();
                              _imageUrlController.clear();
                            });
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to submit: $e')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Submit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _showComposer = false;
                            _postTitleController.clear();
                            _postController.clear();
                            _imageUrlController.clear();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppTheme.spacing24),
              SizedBox(
                height: 50,
                child: !widget.isInstructor
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryLabel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(AppTheme.systemGray6),
                        side: WidgetStateProperty.all(const BorderSide(color: AppTheme.systemGray4)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StudentClassmatesPage(classId: widget.classId),
                          ),
                        );
                      },
                      child: Text('Classmates', style: AppTheme.headline),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryLabel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(AppTheme.systemGray6),
                        side: WidgetStateProperty.all(const BorderSide(color: AppTheme.systemGray4)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TeacherStudentsPage(classId: widget.classId),
                          ),
                        );
                      },
                      child: Text('My Students', style: AppTheme.headline),
                    ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              // All buttons with consistent 56px height
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryLabel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(AppTheme.systemGray6),
                    side: WidgetStateProperty.all(const BorderSide(color: AppTheme.systemGray4)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClassNotesPage(classId: widget.classId, className: widget.className),
                      ),
                    );
                  },
                  child: Text('Lesson Notes', style: AppTheme.headline),
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryLabel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ).copyWith(
                    overlayColor: WidgetStateProperty.all(AppTheme.systemGray6),
                    side: WidgetStateProperty.all(const BorderSide(color: AppTheme.systemGray4)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AssignmentsPage(classId: widget.classId),
                      ),
                    );
                  },
                  child: Text('Assignments', style: AppTheme.headline),
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
              // Bottom Grades button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.iosBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final profile = await ApiService.getProfile();
                    final String studentId = (profile['user_id'] ?? '').toString();
                    if (!mounted || studentId.isEmpty) return;
                    navigator.push(
                      MaterialPageRoute(
                        builder: (_) => StudentGradesPage(
                          classId: widget.classId,
                          studentId: studentId,
                        ),
                      ),
                    );
                  },
                  child: Text('Grades', style: AppTheme.headline.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.isInstructor ? const InstructorBottomNav(currentIndex: 0) : const AppBottomNav(currentIndex: 0),
    );
  }
}


