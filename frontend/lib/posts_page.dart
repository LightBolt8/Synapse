import 'package:flutter/material.dart';
import 'services/api_service.dart';

class PostsPage extends StatefulWidget {
  const PostsPage({super.key, required this.classId, required this.className});
  final String classId;
  final String className;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  late Future<List<Map<String, dynamic>>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _loadPosts();
  }

  Future<List<Map<String, dynamic>>> _loadPosts() async {
    final res = await ApiService.getClassDetails(classId: widget.classId);
    final List<dynamic> items = res['posts'] ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    setState(() {
      _postsFuture = _loadPosts();
    });
  }

  Future<void> _toggleVote(Map<String, dynamic> post, int newValue) async {
    final String postId = (post['post_id'] ?? '').toString();
    if (postId.isEmpty) return;
    final int current = (post['my_vote'] ?? 0) as int;
    final int value = (current == newValue) ? 0 : newValue;
    try {
      final res = await ApiService.votePost(
        classId: widget.classId,
        postId: postId,
        value: value,
      );
      if (!mounted) return;
      setState(() {
        post['my_vote'] = res['my_vote'] ?? value;
        post['score'] = res['score'] ?? post['score'];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vote failed: $e')),
      );
    }
  }

  void _openComments(Map<String, dynamic> post) {
    final String postId = (post['post_id'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CommentsSheet(
        classId: widget.classId,
        postId: postId,
        postTitle: (post['title'] ?? '').toString(),
      ),
    );
  }

  bool _isNotesPost(String content) {
    return content.contains('[Key Concepts]') || content.contains('[Main Points]');
  }

  Map<String, dynamic> _parseNotesContent(String content) {
    final lines = content.split('\n');
    String? keyConcepts;
    String? mainPoints;
    String? studyTips;
    String? questions;
    int conceptCount = 0, pointCount = 0, tipCount = 0, questionCount = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line == '[Key Concepts]') {
        final items = <String>[];
        for (int j = i + 1; j < lines.length && lines[j].trim().startsWith('- '); j++) {
          items.add(lines[j].trim().substring(2));
        }
        conceptCount = items.length;
        if (items.isNotEmpty) keyConcepts = items.first;
      } else if (line == '[Main Points]') {
        final items = <String>[];
        for (int j = i + 1; j < lines.length && lines[j].trim().startsWith('- '); j++) {
          items.add(lines[j].trim().substring(2));
        }
        pointCount = items.length;
        if (items.isNotEmpty) mainPoints = items.first;
      } else if (line == '[Study Tips]') {
        final items = <String>[];
        for (int j = i + 1; j < lines.length && lines[j].trim().startsWith('- '); j++) {
          items.add(lines[j].trim().substring(2));
        }
        tipCount = items.length;
        if (items.isNotEmpty) studyTips = items.first;
      } else if (line == '[Questions for Review]') {
        final items = <String>[];
        for (int j = i + 1; j < lines.length && lines[j].trim().startsWith('- '); j++) {
          items.add(lines[j].trim().substring(2));
        }
        questionCount = items.length;
        if (items.isNotEmpty) questions = items.first;
      }
    }

    return {
      'keyConcepts': keyConcepts,
      'mainPoints': mainPoints,
      'studyTips': studyTips,
      'questions': questions,
      'conceptCount': conceptCount,
      'pointCount': pointCount,
      'tipCount': tipCount,
      'questionCount': questionCount,
    };
  }

  Widget _buildFormattedNotesContent(String content) {
    final lines = content.split('\n');
    final List<Widget> widgets = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line == '[Key Concepts]') {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_buildSectionHeaderForDialog('Key Concepts', Icons.lightbulb_outline));
        // Add bullet points
        for (int j = i + 1; j < lines.length && lines[j].trim().startsWith('- '); j++) {
          widgets.add(_buildBulletPointForDialog(lines[j].trim().substring(2), Colors.blue));
        }
      } else if (line == '[Main Points]') {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_buildSectionHeaderForDialog('Main Points', Icons.check_circle_outline));
        for (int j = i + 1; j < lines.length && lines[j].trim().startsWith('- '); j++) {
          widgets.add(_buildBulletPointForDialog(lines[j].trim().substring(2), Colors.green));
        }
      } else if (line == '[Study Tips]') {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_buildSectionHeaderForDialog('Study Tips', Icons.tips_and_updates_outlined));
        for (int j = i + 1; j < lines.length && lines[j].trim().startsWith('- '); j++) {
          widgets.add(_buildBulletPointForDialog(lines[j].trim().substring(2), Colors.orange));
        }
      } else if (line == '[Questions for Review]') {
        widgets.add(const SizedBox(height: 16));
        widgets.add(_buildSectionHeaderForDialog('Questions for Review', Icons.quiz_outlined));
        for (int j = i + 1; j < lines.length && lines[j].trim().startsWith('- '); j++) {
          widgets.add(_buildBulletPointForDialog(lines[j].trim().substring(2), Colors.purple));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSectionHeaderForDialog(String title, IconData icon) {
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

  Widget _buildBulletPointForDialog(String text, Color color) {
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

  void _showFullNotes(BuildContext context, String title, String content) {
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
                        title,
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
                  child: _buildFormattedNotesContent(content),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesPreview(BuildContext context, String title, String content) {
    final parsed = _parseNotesContent(content);
    final keyConcepts = parsed['keyConcepts'] as String?;
    final mainPoints = parsed['mainPoints'] as String?;
    final conceptCount = parsed['conceptCount'] as int;
    final pointCount = parsed['pointCount'] as int;
    final tipCount = parsed['tipCount'] as int;
    final questionCount = parsed['questionCount'] as int;

    // Build summary line
    final summaryParts = <String>[];
    if (conceptCount > 0) summaryParts.add('$conceptCount Key Concepts');
    if (pointCount > 0) summaryParts.add('$pointCount Main Points');
    if (tipCount > 0) summaryParts.add('$tipCount Study Tips');
    if (questionCount > 0) summaryParts.add('$questionCount Questions');
    final summaryLine = summaryParts.join(' • ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview items
          if (keyConcepts != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    keyConcepts,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (mainPoints != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mainPoints,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          // Summary line
          Text(
            summaryLine,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          // Read More button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showFullNotes(context, title, content),
              icon: const Icon(Icons.article_outlined, size: 16),
              label: const Text('Read Full Notes'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
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
        title: Text('${widget.className} Posts'),
        backgroundColor: scheme.inversePrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _postsFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            final posts = snap.data ?? const [];
            if (posts.isEmpty) {
              return const Center(child: Text('No posts yet.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = posts[index];
                final String title = (p['title'] ?? '').toString();
                final String content = (p['content'] ?? '').toString();
                final String author = (p['author_name'] ?? 'Unknown').toString();
                final int score = (p['score'] ?? 0) as int;
                final int myVote = (p['my_vote'] ?? 0) as int;
                final List<dynamic> files = p['files'] ?? const [];
                final String? imageUrl = files.isNotEmpty ? (files.first as String?) : null;
                final bool isNotes = _isNotesPost(content);

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          ),
                          if (isNotes)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notes, size: 14, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text('Lesson Notes', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('by $author', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                        ),
                      ],
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        if (isNotes) ...[
                          _buildNotesPreview(context, title, content),
                        ] else ...[
                          Text(content),
                        ],
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _toggleVote(p, 1),
                            icon: Icon(Icons.arrow_upward, color: myVote == 1 ? Colors.green : Colors.black),
                            tooltip: 'Upvote',
                          ),
                          Text(score.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                          IconButton(
                            onPressed: () => _toggleVote(p, -1),
                            icon: Icon(Icons.arrow_downward, color: myVote == -1 ? Colors.red : Colors.black),
                            tooltip: 'Downvote',
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _openComments(p),
                            icon: const Icon(Icons.comment_outlined),
                            label: Text('Comments (${p['comment_count'] ?? 0})'),
                          )
                        ],
                      )
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.classId, required this.postId, required this.postTitle});
  final String classId;
  final String postId;
  final String postTitle;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late Future<List<Map<String, dynamic>>> _commentsFuture;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _commentsFuture = ApiService.listComments(classId: widget.classId, postId: widget.postId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _commentsFuture = ApiService.listComments(classId: widget.classId, postId: widget.postId);
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiService.addComment(classId: widget.classId, postId: widget.postId, content: text);
      if (!mounted) return;
      _controller.clear();
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.postTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...'
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Send'),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _commentsFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: ${snap.error}'),
                    );
                  }
                  final comments = snap.data ?? const [];
                  if (comments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No comments yet.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final c = comments[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((c['author_name'] ?? 'Unknown').toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text((c['content'] ?? '').toString()),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}


