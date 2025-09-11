import 'package:basic_flutter/create_class.dart';
import 'package:basic_flutter/login_page.dart';
import 'package:basic_flutter/register_page.dart';
import 'package:basic_flutter/sub_pages/firebase_options.dart';
import 'package:basic_flutter/sub_pages/lost_device.dart';
import 'package:basic_flutter/sub_pages/routes.dart';
import 'package:basic_flutter/student_profile.dart';
import 'package:basic_flutter/teacher_profile.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Cache userType in SharedPreferences
  Future<void> _cacheUserType(String uid, String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userType_$uid', type);
  }

  Future<String?> _getCachedUserType(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userType_$uid');
  }

  // Determine start page
  Future<Widget> _getStartPage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Login();

    // Check cache first
    final cachedType = await _getCachedUserType(user.uid);
    if (cachedType != null) {
      if (cachedType.toLowerCase() == 'student') return const StudentProfile();
      if (cachedType.toLowerCase() == 'teacher') return const TeacherProfile();
    }

    // Fetch from Firestore if not cached
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userType = doc['userType'] as String?;
    if (userType != null) await _cacheUserType(user.uid, userType);

    if (userType?.toLowerCase() == 'student') return const StudentProfile();
    if (userType?.toLowerCase() == 'teacher') return const TeacherProfile();

    return const Login();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qr Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 19, 2, 99),
        ),
      ),
      routes: {
        login: (context) => const Login(),
        register: (context) => const Register(),
        student: (context) => const StudentProfile(),
        teacher: (context) => const TeacherProfile(),
        lostdevice: (context) => const LostDevice(),
        createclass: (context) => const CreateClassPage(),
      },

      // Home page decides based on auth & cached userType
      home: FutureBuilder<Widget>(
        future: _getStartPage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) return snapshot.data!;
          return const Login();
        },
      ),
    );
  }
}
