import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class QrScanner extends StatefulWidget {
  const QrScanner({super.key});

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  final MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _onDetect(BarcodeCapture capture) async {
    if (!isScanning) return;

    final Barcode? barcode = capture.barcodes.firstOrNull;
    final String? rawValue = barcode?.rawValue;

    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => isScanning = false);
    cameraController.stop();

    try {
      // Parse QR data
      Map<String, dynamic> qrData = json.decode(rawValue);
      final String classCode = qrData['classCode'];
      final String docId = qrData['docId'];
      final String section = qrData['section'];

      // Fetch user info
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        _showError('User not logged in');
        return;
      }

      final userSnap = await _firestore.collection('users').doc(uid).get();
      if (!userSnap.exists) {
        _showError('User profile not found');
        return;
      }

      final userData = userSnap.data()!;
      final String userName = userData['name'] ?? 'Unknown';
      final String studentId = userData['studentId'] ?? uid;
      final String userSection = userData['section'] ?? '';

      // Section check
      if (userSection != section) {
        _showError('Section mismatch! Attendance not marked.');
        return;
      }

      // Save attendance
      await _firestore
          .collection('global')
          .doc('classes')
          .collection('allClasses')
          .doc(classCode)
          .collection('attendance')
          .doc(docId)
          .collection('students')
          .doc(studentId)
          .set({
            'studentName': userName,
            'studentId': studentId,
            'section': userSection,
            'scanTime': FieldValue.serverTimestamp(),
            'present': 'yes',
          });

      _showSuccess('Attendance marked successfully ✅');

      // Reset after 2s
      Future.delayed(const Duration(seconds: 2), () {
        setState(() => isScanning = true);
        cameraController.start();
      });
    } catch (e) {
      _showError('Invalid QR / Error: $e');
      setState(() => isScanning = true);
      cameraController.start();
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text("Attendance marked successfully ✅")),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QR Attendance Scanner',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: MobileScanner(
                  controller: cameraController,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          const Expanded(
            flex: 1,
            child: Center(
              child: Text(
                "Scan a QR code to mark attendance",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        child: Icon(isScanning ? Icons.qr_code_scanner : Icons.play_arrow),
        onPressed: () {
          setState(() {
            isScanning = !isScanning;
          });
          if (isScanning) {
            cameraController.start();
          } else {
            cameraController.stop();
          }
        },
      ),
    );
  }
}
