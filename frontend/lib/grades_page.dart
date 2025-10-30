import 'package:flutter/material.dart';
import 'app_bottom_nav.dart';
import 'instructor_bottom_nav.dart';

class GradesPage extends StatelessWidget {
  const GradesPage({super.key, this.isInstructor = false});
  final bool isInstructor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Grades')),
      body: const Center(child: Text('Grades Page')),
      bottomNavigationBar: isInstructor
          ? const InstructorBottomNav(currentIndex: 2)
          : const AppBottomNav(currentIndex: 2),
    );
  }
}


