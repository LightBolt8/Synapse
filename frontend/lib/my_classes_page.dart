import 'package:flutter/material.dart';
import 'app_bottom_nav.dart';
import 'in_class_page.dart';
import 'services/api_service.dart';
import 'app_theme.dart';

class MyClassesPage extends StatelessWidget {
  const MyClassesPage({super.key});

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await ApiService.getUserClasses();
    final List<dynamic> items = res['classes'] ?? [];
    return items.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    const double tileHeight = 120;

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
                  onPressed: () => Navigator.of(context).pushNamed('/class-search'),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Join Class'),
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
                              Icons.school_outlined,
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
                              'Tap "Join Class" to get started',
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
                                  builder: (_) => InClassPage(classId: classId, className: name),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                              child: Padding(
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
                                          'View class',
                                          style: AppTheme.callout.copyWith(
                                            color: AppTheme.iosBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}


