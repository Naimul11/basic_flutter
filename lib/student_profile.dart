import 'package:basic_flutter/student_class_details.dart';
import 'package:basic_flutter/sub_pages/firebase_options.dart';
import 'package:basic_flutter/sub_pages/menu_button.dart';
import 'package:basic_flutter/sub_pages/profile_card.dart';
import 'package:basic_flutter/sub_pages/qr_scanner/scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentProfile extends StatelessWidget {
  const StudentProfile({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection("users").doc(uid).get();
  }

  /// --- Join a class with code (with section check) ---
  Future<void> _joinClass(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final TextEditingController codeController = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Join Class"),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: "Enter Class Code",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, codeController.text.trim()),
              child: const Text("Join"),
            ),
          ],
        );
      },
    );

    if (code == null || code.isEmpty) return;

    try {
      // Fetch student's section
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userSection = userDoc.data()?['section'] ?? '';

      // Check global collection for class
      final classDoc = await FirebaseFirestore.instance
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(code)
          .get();

      if (!classDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid class code."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final classData = classDoc.data()!;
      final classSection = classData['section'] ?? '';

      // Section validation
      if (userSection != classSection) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Section mismatch."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Add class to student's joinedClasses
      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("joinedClasses")
          .doc(code)
          .set(classData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Class joined successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error joining class: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 161, 115),
        title: const Text('Student Profile'),
        actions: [CustomMenuButton()],
      ),
      body: FutureBuilder(
        future: Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final user = FirebaseAuth.instance.currentUser;

            if (user?.emailVerified ?? false) {
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: getUserData(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text("No user data found"));
                  }

                  final userData = snapshot.data!.data()!;
                  final name = userData['name'] ?? '';
                  final studentId = userData['studentId'] ?? '';
                  final section = userData['section'] ?? '';
                  final verifiedStudent = userData['verified'] ?? false;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Profile Card ---
                        ProfileCard(
                          name: name,
                          id: studentId,
                          secondLine: "Section: $section",
                          verified: verifiedStudent,
                        ),

                        const SizedBox(height: 20),

                        // --- Buttons Row ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _joinClass(context),
                                icon: const Icon(Icons.add),
                                label: const Text("Join Class"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(
                                    255,
                                    0,
                                    161,
                                    115,
                                  ),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const QrScanner(),
                                    ),
                                  );
                                },

                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text("Scan QR"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // --- Joined Classes List ---
                        const Text(
                          "Your Classes",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Fetch joined classes from Firestore
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("users")
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection("joinedClasses")
                              .orderBy('startTime')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const Text("No classes joined yet.");
                            }

                            final docs = snapshot.data!.docs;

                            return Column(
                              children: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final className = data['name'] ?? '';
                                final rawTime = data['startTime'] ?? '';
                                String displayTime = rawTime;

                                // Convert "HH:mm" -> "h:mm a"
                                try {
                                  final time = DateFormat(
                                    "HH:mm",
                                  ).parse(rawTime);
                                  displayTime = DateFormat(
                                    "h:mm a",
                                  ).format(time);
                                } catch (_) {
                                  // fallback if parsing fails
                                }

                                return Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                      color: Color.fromARGB(255, 0, 161, 115),
                                      width: 2,
                                    ),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      className,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    subtitle: Text("Start Time: $displayTime"),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              StudentClassPage(
                                                classCode: data['code'],
                                                userId: FirebaseAuth
                                                    .instance
                                                    .currentUser!
                                                    .uid,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            } else {
              return const Center(child: Text("Please verify your email"));
            }
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
