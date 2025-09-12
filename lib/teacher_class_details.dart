import 'dart:convert';
import 'dart:async';
import 'package:basic_flutter/sub_pages/qr/qr_display.dart';
import 'package:basic_flutter/sub_pages/qr/qr_manager.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  bool _hasCheckedTodaysQR = false;
  Timer? _expirationTimer;

  @override
  void initState() {
    super.initState();
    // Start a timer to check for expired QRs every minute
    _expirationTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_hasQRToday && _todaysQRData != null) {
        _checkIfCurrentQRExpired();
      }
    });
    
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }
  

  Future<void> _checkIfCurrentQRExpired() async {
    if (_todaysQRData == null || _classData == null) return;

    final expiresAt = _todaysQRData!['expiresAt'] as DateTime;

    if (QRManager.isQRExpired(expiresAt)) {
      // QR has expired, delete it and update UI
      final docId = _todaysQRData!['docId'] as String;
      await QRManager.deleteExpiredQR(widget.classCode, docId);

      if (mounted) {
        setState(() {
          _hasQRToday = false;
          _todaysQRData = null;
          _canCreateQR = true;
        });
      }
    }
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

    // Check today's QR immediately after getting class data
    if (!_hasCheckedTodaysQR && data != null) {
      await _checkTodaysQR();
      _hasCheckedTodaysQR = true;
    }

    return data;
  }

  Future<void> _checkTodaysQR() async {
    if (_classData == null) return;

    try {
      final section = _classData!['section'] ?? '';
      final qrData = await QRManager.checkTodaysQR(widget.classCode, section);

      if (qrData != null) {
        // Valid QR exists
        _hasQRToday = true;
        _todaysQRData = qrData;
        _canCreateQR = false;
      } else {
        // No valid QR found (either doesn't exist or was expired and deleted)
        _hasQRToday = false;
        _todaysQRData = null;
        _canCreateQR = true;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // On error, assume no QR exists and allow creation
      _hasQRToday = false;
      _todaysQRData = null;
      _canCreateQR = true;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _createQR() async {
    if (_classData == null) return;

    setState(() {
      _isLoading = true;
    });

    final section = _classData!['section'] ?? '';

    try {
      // First check if there's an expired QR that needs cleanup
      await _checkTodaysQR();

      // Only proceed if we can create a QR
      if (!_canCreateQR) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("A QR code already exists for today."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final qrResult = await QRManager.createQR(
        classCode: widget.classCode,
        section: section,
        expirationDuration: const Duration(minutes: 2),
      );

      if (qrResult != null) {
        // Update local state
        _hasQRToday = true;
        _canCreateQR = false;
        _todaysQRData = qrResult;

        setState(() {
          _isLoading = false;
        });

        // Navigate to QR display page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QRDisplayPage(
              qrData: qrResult['qrString'] as String,
              expiresAt: qrResult['expiresAt'] as DateTime,
              classCode: widget.classCode,
              section: section,
            ),
          ),
        );
      } else {
        throw Exception("Failed to create QR");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error creating QR: $e")));
    }
  }

  void _viewQR() async {
    if (_todaysQRData == null || _classData == null) return;

    // Check if QR is expired before viewing
    final expiresAt = _todaysQRData!['expiresAt'] as DateTime;

    if (QRManager.isQRExpired(expiresAt)) {
      // QR is expired, clean it up
      final docId = _todaysQRData!['docId'] as String;
      await QRManager.deleteExpiredQR(widget.classCode, docId);

      if (mounted) {
        setState(() {
          _hasQRToday = false;
          _todaysQRData = null;
          _canCreateQR = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("QR code has expired. Please create a new one."),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final qrData = QRManager.getQRData(
      classCode: widget.classCode,
      section: _classData!['section'] ?? '',
      qrId: _todaysQRData!['qrId'],
      expiresAt: expiresAt,
      date: _todaysQRData!['date'],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRDisplayPage(
          qrData: jsonEncode(qrData),
          expiresAt: expiresAt,
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
                        onPressed: _canCreateQR && !_isLoading
                            ? _createQR
                            : null,
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
    bool? enabled,
  }) {
    final isEnabled = enabled ?? (onPressed != null);

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: _isLoading && onPressed != null
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 26),
      label: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? color : Colors.grey,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: isEnabled ? 5 : 1,
        shadowColor: isEnabled
            ? color.withValues(alpha: 0.5)
            : Colors.grey.withValues(alpha: 0.3),
      ),
    );
  }
}
