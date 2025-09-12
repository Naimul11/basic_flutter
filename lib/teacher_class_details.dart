import 'dart:convert';
import 'package:basic_flutter/sub_pages/qr/qr_display.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class TeacherClassPage extends StatefulWidget {
  final String classCode;
  final String userId;

  const TeacherClassPage({
    super.key,
    required this.classCode,
    required this.userId,
  });

  @override
  State<TeacherClassPage> createState() => _TeacherClassPageState();
}

class _TeacherClassPageState extends State<TeacherClassPage> {
  bool _isLoading = false;
  bool _canCreateQR = true;
  bool _hasQRToday = false;
  Map<String, dynamic>? _classData;
  Map<String, dynamic>? _todaysQRData;

  @override
  void initState() {
    super.initState();
  }

  Future<Map<String, dynamic>?> getClassDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('global')
        .doc('classes')
        .collection('allClasses')
        .doc(widget.classCode)
        .get();

    final data = doc.data();
    _classData = data;
    return data;
  }

  Future<void> _checkTodaysQR() async {
    if (_classData == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final date = DateFormat('yyyy-MM-dd').format(now);
      final section = _classData!['section'];

      final attendanceDoc = await FirebaseFirestore.instance
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(widget.classCode)
          .collection("attendance")
          .doc(date)
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        final qrSection = data['section'] ?? '';

        // QR exists for today
        _hasQRToday = true;
        _todaysQRData = {
          'qrId': data['qrId'],
          'expiresAt': expiresAt,
          'section': qrSection,
          'classCode': widget.classCode,
          'date': date,
        };

        // Check if we can create new QR (if current one expired)
        _canCreateQR = expiresAt.isBefore(now);
      } else {
        _hasQRToday = false;
        _todaysQRData = null;
        _canCreateQR = true;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasQRToday = false;
        _canCreateQR = true;
      });
    }
  }

  Future<void> _createQR() async {
    if (_classData == null) return;

    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(now);
    final qrId = const Uuid().v4();
    final expiresAt = now.add(const Duration(hours: 1));
    final section = _classData!['section'] ?? '';

    final qrData = {
      'classCode': widget.classCode,
      'date': date,
      'section': section,
      'qrId': qrId,
      'createdAt': now.millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    };
    final qrString = jsonEncode(qrData);

    try {
      // Create attendance session in Firestore
      final attendanceRef = FirebaseFirestore.instance
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(widget.classCode)
          .collection("attendance")
          .doc(date);

      await attendanceRef.set({
        "qrId": qrId,
        "section": section,
        "createdAt": FieldValue.serverTimestamp(),
        "expiresAt": Timestamp.fromDate(expiresAt),
        "date": date,
        "isActive": true,
      }, SetOptions(merge: true));

      // Update local state
      _hasQRToday = true;
      _canCreateQR = false;
      _todaysQRData = {
        'qrId': qrId,
        'expiresAt': expiresAt,
        'section': section,
        'classCode': widget.classCode,
        'date': date,
      };

      setState(() {
        _isLoading = false;
      });

      // Navigate to QR display page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QRDisplayPage(
            qrData: qrString,
            expiresAt: expiresAt,
            classCode: widget.classCode,
            section: section,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating QR: $e")),
      );
    }
  }

  void _viewQR() {
    if (_todaysQRData == null || _classData == null) return;

    final qrData = {
      'classCode': widget.classCode,
      'date': _todaysQRData!['date'],
      'section': _classData!['section'] ?? '',
      'qrId': _todaysQRData!['qrId'],
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'expiresAt': (_todaysQRData!['expiresAt'] as DateTime).millisecondsSinceEpoch,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRDisplayPage(
          qrData: jsonEncode(qrData),
          expiresAt: _todaysQRData!['expiresAt'] as DateTime,
          classCode: widget.classCode,
          section: _classData!['section'] ?? '',
        ),
      ),
    );
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

          // Check for today's QR after getting class data
          if (_classData == null) {
            _classData = data;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkTodaysQR();
            });
          }

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
                      const SizedBox(height: 6),
                      Text(
                        "Class Code: ${widget.classCode}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 255, 255, 255),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // QR Management Buttons
                Row(
                  children: [
                    // Create QR Button
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.qr_code,
                        label: "Create QR",
                        color: Colors.orange,
                        onPressed: _canCreateQR && !_isLoading ? _createQR : null,
                        enabled: _canCreateQR && !_isLoading,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // View QR Button
                    Expanded(
                      child: _buildActionButton(
                        context,
                        icon: Icons.qr_code_2,
                        label: "View QR",
                        color: Colors.green,
                        onPressed: _hasQRToday && !_isLoading ? _viewQR : null,
                        enabled: _hasQRToday && !_isLoading,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Other Buttons
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
    required VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return ElevatedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: _isLoading && onPressed != null
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 26),
      label: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : Colors.grey.shade400,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: enabled ? 5 : 0,
        shadowColor: enabled ? color.withValues(alpha: 0.5) : Colors.transparent,
      ),
    );
  }
}