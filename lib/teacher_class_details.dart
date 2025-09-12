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
  bool _isLoading = true;
  bool _isCreatingQR = false;
  bool _canCreateQR = true;
  bool _hasQRToday = false;
  Map<String, dynamic>? _classData;
  Map<String, dynamic>? _todaysQRData;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _refreshData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('global')
          .doc('classes')
          .collection('allClasses')
          .doc(widget.classCode)
          .get();

      _classData = doc.data();
      if (_classData != null) await _checkTodaysQR();
    } catch (e) {
      if (mounted) _showError("Error loading class: $e");
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    if (_classData != null) {
      await _checkTodaysQR();
      if (mounted) setState(() {});
    }
  }

  Future<void> _checkTodaysQR() async {
    if (_classData == null) return;

    try {
      final qrData = await QRManager.checkTodaysQR(
        widget.classCode,
        _classData!['section'] ?? '',
      );
      _hasQRToday = qrData != null;
      _todaysQRData = qrData;
      _canCreateQR = !_hasQRToday;
    } catch (e) {
      _hasQRToday = false;
      _todaysQRData = null;
      _canCreateQR = true;
    }
  }

  Future<void> _createQR() async {
    if (_classData == null) return;

    setState(() => _isCreatingQR = true);

    try {
      final qrResult = await QRManager.createQR(
        classCode: widget.classCode,
        section: _classData!['section'] ?? '',
        expirationDuration: const Duration(minutes: 2),
      );

      if (qrResult != null) {
        setState(() {
          _hasQRToday = true;
          _canCreateQR = false;
          _todaysQRData = qrResult;
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QRDisplayPage(
              qrData: qrResult['qrString'],
              expiresAt: qrResult['expiresAt'],
              classCode: widget.classCode,
              section: _classData!['section'] ?? '',
            ),
          ),
        );
      } else {
        throw Exception("Failed to create QR");
      }
    } catch (e) {
      _showError("Error creating QR: $e");
    }

    setState(() => _isCreatingQR = false);
  }

  Future<void> _viewQR() async {
    if (_todaysQRData == null || _classData == null) return;

    final expiresAt = _todaysQRData!['expiresAt'] as DateTime;

    if (QRManager.isQRExpired(expiresAt)) {
      await _refreshData(); 
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

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshData(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classData == null
          ? const Center(child: Text("Class not found"))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final data = _classData!;
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
          _buildClassInfoCard(name, section, formattedTime),
          const SizedBox(height: 30),

          // QR Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _hasQRToday
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasQRToday ? Colors.green : Colors.orange,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _hasQRToday ? Icons.check_circle : Icons.info,
                  color: _hasQRToday ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  _hasQRToday ? "QR Active" : "No Active QR",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _hasQRToday
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.qr_code,
                  label: "Create QR",
                  color: Colors.orange,
                  onPressed: _canCreateQR && !_isCreatingQR ? _createQR : null,
                  isLoading: _isCreatingQR,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.qr_code_2,
                  label: "View QR",
                  color: Colors.green,
                  onPressed: _hasQRToday ? _viewQR : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            icon: Icons.list_alt,
            label: "Show Attendance",
            color: Colors.blue,
            onPressed: () {
              // TODO: show attendance 
            },
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            icon: Icons.timer,
            label: "Attendance History",
            color: const Color.fromARGB(255, 0, 161, 115),
            onPressed: () {
              // TODO: Show attendance history
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClassInfoCard(
    String name,
    String section,
    String formattedTime,
  ) {
    return Container(
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
          ...[
            "Section: $section",
            "Start Time: $formattedTime",
            "Class Code: ${widget.classCode}",
          ].map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final isEnabled = onPressed != null;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading
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
