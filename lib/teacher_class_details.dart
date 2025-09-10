import 'package:basic_flutter/sub_pages/qr_display.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TeacherClassPage extends StatelessWidget {
  final String classCode;
  final String userId;

  const TeacherClassPage({
    super.key,
    required this.classCode,
    required this.userId,
  });

  Future<Map<String, dynamic>?> getClassDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('global')
        .doc('classes')
        .collection('allClasses')
        .doc(classCode)
        .get();

    return doc.data();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 161, 115),
        title: const Text("Class Details"),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: getClassDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Class not found"));
          }

          final data = snapshot.data!;
          final name = data['name'] ?? 'Unknown';
          final section = data['section'] ?? '';
          final time = data['startTime'] ?? '';
          String formattedTime = time;
          try {
            final parsedTime = DateFormat("HH:mm").parse(time);
            formattedTime = DateFormat.jm().format(parsedTime);
          } catch (_) {}

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Class Info Card
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromARGB(255, 0, 161, 115),
                        Color.fromARGB(255, 0, 190, 140),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .15),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 250, 250, 250),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Section: $section",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Start Time: $formattedTime",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Buttons
                _buildActionButton(
                  context,
                  icon: Icons.qr_code,
                  color: Colors.orange,
                  label: "Create QR",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QRDisplayPage(
                          qrData: classCode, // just use classCode
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  context,
                  icon: Icons.timer,
                  label: "Take Attendance",
                  color: const Color.fromARGB(255, 0, 161, 115),

                  onPressed: () {
                    // TODO: Start Attendance
                  },
                ),
                const SizedBox(height: 20),
                _buildActionButton(
                  context,
                  icon: Icons.list_alt,
                  label: "Show Attendance",
                  color: Colors.blue,
                  onPressed: () {
                    // TODO: Show Attendance
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 26),
      label: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 5,
        shadowColor: color.withValues(alpha: 0.5),
      ),
    );
  }
}
