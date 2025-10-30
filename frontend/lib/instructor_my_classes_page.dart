import 'package:flutter/material.dart';
import 'instructor_bottom_nav.dart';
import 'in_class_page.dart';
import 'create_class_page.dart';
import 'services/api_service.dart';
import 'app_theme.dart';

class InstructorMyClassesPage extends StatelessWidget {
  const InstructorMyClassesPage({super.key, required this.email});

  final String email;

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await ApiService.getUserClasses(email: email);
    final List<dynamic> items = res['classes'] ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    const double tileHeight = 140;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classes'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing8,
              ),
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateClassPage(email: email),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Create Class'),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _load(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: AppTheme.errorRed.withOpacity(0.5),
                            ),
                            const SizedBox(height: AppTheme.spacing16),
                            Text(
                              'Something went wrong',
                              style: AppTheme.headline.copyWith(
                                color: AppTheme.primaryLabel,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacing8),
                            Text(
                              '${snap.error}',
                              style: AppTheme.callout.copyWith(
                                color: AppTheme.secondaryLabel,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final classes = snap.data ?? const [];
                  if (classes.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.class_outlined,
                              size: 80,
                              color: AppTheme.systemGray3,
                            ),
                            const SizedBox(height: AppTheme.spacing24),
                            Text(
                              'No Classes Yet',
                              style: AppTheme.title2.copyWith(
                                color: AppTheme.primaryLabel,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacing8),
                            Text(
                              'Tap "Create Class" to get started',
                              style: AppTheme.callout.copyWith(
                                color: AppTheme.secondaryLabel,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    itemCount: classes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacing12),
                    itemBuilder: (context, index) {
                      final item = classes[index];
                      final String name = (item['name'] ?? 'Class') as String;
                      final String classId = (item['class_id'] ?? '') as String;
                      final String code = (item['code'] ?? '') as String;

                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                        height: tileHeight,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => InClassPage(
                                  classId: classId,
                                  className: name,
                                  isInstructor: true,
                                ),
                              ),
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            child: Stack(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(AppTheme.spacing20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        name,
                                        style: AppTheme.title3.copyWith(
                                          color: AppTheme.primaryLabel,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (code.isNotEmpty) ...[
                                        const SizedBox(height: AppTheme.spacing8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppTheme.spacing12,
                                            vertical: AppTheme.spacing4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.systemGray6,
                                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.key,
                                                size: 14,
                                                color: AppTheme.systemGray,
                                              ),
                                              const SizedBox(width: AppTheme.spacing4),
                                              Text(
                                                'Code: $code',
                                                style: AppTheme.caption1.copyWith(
                                                  color: AppTheme.secondaryLabel,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: AppTheme.spacing8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.chevron_right,
                                            size: 20,
                                            color: AppTheme.systemGray,
                                          ),
                                          const SizedBox(width: AppTheme.spacing4),
                                          Text(
                                            'Manage class',
                                            style: AppTheme.callout.copyWith(
                                              color: AppTheme.iosBlue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: AppTheme.spacing8,
                                  right: AppTheme.spacing8,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppTheme.errorRed,
                                      size: 22,
                                    ),
                                    tooltip: 'Delete class',
                                    onPressed: () => _deleteClass(context, classId, name),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const InstructorBottomNav(currentIndex: 0),
    );
  }

  Future<void> _deleteClass(BuildContext context, String classId, String className) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class?'),
        content: Text(
          'Are you sure you want to delete "$className"? This action cannot be undone.',
          style: AppTheme.callout,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteClass(classId: classId, email: email);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$className deleted'),
              backgroundColor: AppTheme.primaryLabel.withOpacity(0.9),
            ),
          );
          // Trigger rebuild
          (context as Element).markNeedsBuild();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${e.toString()}'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }
}


