import 'package:basic_flutter/teacher_class_details.dart';
import 'package:basic_flutter/sub_pages/firebase_options.dart';
import 'package:basic_flutter/sub_pages/menu_button.dart';
import 'package:basic_flutter/sub_pages/profile_card.dart';
import 'package:basic_flutter/sub_pages/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TeacherProfile extends StatelessWidget {
  const TeacherProfile({super.key});

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection("users").doc(uid).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getClassesStream(String uid) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("classes")
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 245),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 161, 115),
        title: const Text('Teacher Profile'),
        actions: [CustomMenuButton()],
      ),
      body: FutureBuilder(
        future: Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: getUserData(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return const Center(child: Text("No user data found"));
              }

              final userData = userSnapshot.data!.data()!;
              final name = userData['name'] ?? '';
              final userId = FirebaseAuth.instance.currentUser!.uid;
              final teacherId = userData['studentId'] ?? 'Not updated';
              final designation = userData['section'] ?? '';
              final verifiedTeacher = userData['verified'] ?? false;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ProfileCard(
                      name: name,
                      id: teacherId,
                      secondLine: "Designation: $designation",
                      verified: verifiedTeacher,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(createclass);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text("Create Class"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 161, 115),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Your Classes",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🔥 Class List from nested collection
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: getClassesStream(userId),
                      builder: (context, classSnapshot) {
                        if (classSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final classes = classSnapshot.data?.docs ?? [];
                        if (classes.isEmpty) {
                          return const Center(
                            child: Text(
                              "No classes created yet",
                              style: TextStyle(
                                color: Color.fromARGB(255, 80, 80, 80),
                              ),
                            ),
                          );
                        }

                        // 🔽 Sort classes by startTime (ascending)
                        classes.sort((a, b) {
                          final aTime = a['startTime'] ?? '';
                          final bTime = b['startTime'] ?? '';
                          try {
                            final aParsed = DateFormat(
                              "HH:mm",
                            ).parse(aTime.toString());
                            final bParsed = DateFormat(
                              "HH:mm",
                            ).parse(bTime.toString());
                            return aParsed.compareTo(bParsed);
                          } catch (_) {
                            return 0;
                          }
                        });

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: classes.length,
                          itemBuilder: (context, index) {
                            final classData = classes[index].data();

                            // Format time
                            String formattedTime = '';
                            if (classData['startTime'] != null) {
                              try {
                                final parsedTime = DateFormat(
                                  "HH:mm",
                                ).parse(classData['startTime']);
                                formattedTime = DateFormat.jm().format(
                                  parsedTime,
                                );
                              } catch (_) {
                                formattedTime = classData['startTime'];
                              }
                            }

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(
                                  color: Color.fromARGB(255, 0, 161, 115),
                                  width: 2,
                                ),
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => TeacherClassPage(
                                        classCode:
                                            classData['code'], // code stored in Firestore
                                        userId: userId, // current teacher uid
                                      ),
                                    ),
                                  );
                                },

                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            classData['name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Chip(
                                                label: Text(
                                                  'Section: ${classData['section'] ?? ''}',
                                                ),
                                                backgroundColor:
                                                    Colors.green.shade50,
                                                labelStyle: const TextStyle(
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Chip(
                                                label: Text(
                                                  'Code: ${classData['code'] ?? ''}',
                                                ),
                                                backgroundColor:
                                                    Colors.blue.shade50,
                                                labelStyle: const TextStyle(
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (formattedTime.isNotEmpty)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Text(
                                            formattedTime,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color.fromARGB(
                                                226,
                                                188,
                                                3,
                                                3,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
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
              );
            },
          );
        },
      ),
    );
  }
}
