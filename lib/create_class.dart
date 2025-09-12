import 'package:basic_flutter/sub_pages/firebase_options.dart';
import 'package:basic_flutter/sub_pages/random_number.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sub_pages/routes.dart';

class CreateClassPage extends StatefulWidget {
  const CreateClassPage({super.key});

  @override
  State<CreateClassPage> createState() => _CreateClassPageState();
}

class _CreateClassPageState extends State<CreateClassPage> {
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();
  TimeOfDay? _classStartTime;
  bool _isLoading = false;

  Future<void> _createClass() async {
    final className = _classNameController.text.trim();
    final section = _sectionController.text.trim();

    if (className.isEmpty || section.isEmpty || _classStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      String classCode = await generateUniqueClassCode();

      // firebase data write
      final userClasses = FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("classes");

      final globalClasses = FirebaseFirestore.instance
          .collection("global")
          .doc("classes")
          .collection("allClasses");

      // Check uniqueness in user collection
      final snapshotUser = await userClasses.doc(classCode).get();
      // Check uniqueness in global collection
      final snapshotGlobal = await globalClasses.doc(classCode).get();

      if (snapshotUser.exists || snapshotGlobal.exists) {
        classCode = await generateUniqueClassCode();
      }

      final classData = {
        "name": className,
        "section": section,
        "startTime": "${_classStartTime!.hour}:${_classStartTime!.minute}",
        "code": classCode,
        "ownerUid": user.uid,
      };

      // Save under teacher's profile
      await userClasses.doc(classCode).set(classData);

      // Save globally
      await globalClasses.doc(classCode).set(classData);
      final initialAttendance = {
        "initializedAt": FieldValue.serverTimestamp(),
        "note": "Attendance subcollection created",
      };

      globalClasses.doc(classCode).collection("attendance").doc("init").set(initialAttendance);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Class created successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pushNamedAndRemoveUntil(teacher, (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error creating class: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      setState(() {
        _classStartTime = time;
      });
    }
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: const Color.fromARGB(255, 0, 161, 115),
            title: const Text("Create Class"),
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _classNameController,
                      decoration: const InputDecoration(
                        labelText: "Class Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _sectionController,
                      decoration: const InputDecoration(
                        labelText: "Section",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickStartTime,
                            child: Text(
                              _classStartTime == null
                                  ? "Pick Class Start Time"
                                  : "Start Time: ${_classStartTime!.format(context)}",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createClass,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            0,
                            161,
                            115,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Create Class",
                                style: TextStyle(fontSize: 18),
                              ),
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
  }
}
