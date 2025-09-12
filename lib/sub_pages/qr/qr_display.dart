import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class QRDisplayPage extends StatefulWidget {
  final String qrData;
  final DateTime? expiresAt;
  final String? classCode;
  final String? section;

  const QRDisplayPage({
    super.key,
    required this.qrData,
    this.expiresAt,
    this.classCode,
    this.section,
  });

  @override
  State<QRDisplayPage> createState() => _QRDisplayPageState();
}

class _QRDisplayPageState extends State<QRDisplayPage> {
  bool _isExpired = false;
  Map<String, dynamic>? _classData;
  String? _classCodeFromQR;
  String? _dateFromQR;

  @override
  void initState() {
    super.initState();
    _checkIfExpired();
    _parseQRData();
    _fetchClassInfo();
  }

  void _checkIfExpired() {
    if (widget.expiresAt != null) {
      final now = DateTime.now();
      _isExpired = widget.expiresAt!.isBefore(now);

      if (_isExpired) {
        _deactivateQR();
      }
    }
  }

  void _parseQRData() {
    try {
      final qrDataMap = jsonDecode(widget.qrData);
      _classCodeFromQR = qrDataMap['classCode'];
      _dateFromQR = qrDataMap['date'];
    } catch (e) {
      // fallback: treat as simple string QR
      _classCodeFromQR = widget.qrData;
      _dateFromQR = DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  Future<void> _fetchClassInfo() async {
    if (_classCodeFromQR == null || _classCodeFromQR!.isEmpty) return;

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(_classCodeFromQR!)
          .get();

      if (docSnap.exists) {
        setState(() {
          _classData = docSnap.data();
        });
      }
    } catch (e) {
      print("Error fetching class info: $e");
    }
  }

  Future<void> _deactivateQR() async {
    if (_classCodeFromQR == null || widget.expiresAt == null) return;

    try {
      final date = DateFormat('yyyy-MM-dd').format(widget.expiresAt!);
      final section = widget.section ?? '';
      final docId = "${date}_${_classCodeFromQR}_$section";

      await FirebaseFirestore.instance
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(_classCodeFromQR!)
          .collection("attendance")
          .doc(docId)
          .update({'isActive': false});
    } catch (e) {
      print("Error deactivating QR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isValidData = widget.qrData.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance QR"),
        backgroundColor: const Color.fromARGB(255, 0, 161, 115),
        centerTitle: true,
        elevation: 2,
      ),
      body: Center(
        child: isValidData
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Class: ${_classData?['name'] ?? 'Loading...'}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Section: ${_classData?['section'] ?? 'Loading...'}",
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Date: ${_dateFromQR ?? 'Loading...'}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    //  Status Card
                    Card(
                      elevation: 4,
                      color: _isExpired
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isExpired ? Icons.timer_off : Icons.check_circle,
                              color: _isExpired ? Colors.red : Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isExpired ? "QR CODE EXPIRED" : "QR CODE ACTIVE",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isExpired ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // QR Code
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _isExpired
                            ? Column(
                                children: const [
                                  Icon(
                                    Icons.qr_code_scanner,
                                    size: 100,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    "QR Code Expired",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Please generate a new QR code",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              )
                            : QrImageView(
                                data: widget.qrData,
                                version: QrVersions.auto,
                                size: 250,
                                backgroundColor: Colors.white,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    //  Instructions
                    if (!_isExpired)
                      const Card(
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 24,
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Students can scan this QR code to mark their attendance",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  SizedBox(height: 12),
                  Text(
                    "No data available to generate QR",
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }
}
