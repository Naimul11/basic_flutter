import 'dart:convert';
import 'package:basic_flutter/sub_pages/qr/qr_display.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> createQR(BuildContext context, String classCode, String section) async {
  final now = DateTime.now();
  final date = DateFormat('yyyy-MM-dd').format(now);
  final qrId = const Uuid().v4(); // unique QR ID
  final expiresAt = now.add(const Duration(hours: 1)); // QR expires in 1 hour

  final qrData = {
    'classCode': classCode,
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
        .doc(classCode)
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

    // Navigate to QR display page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRDisplayPage(
          qrData: qrString,
          expiresAt: expiresAt,
          classCode: classCode,
          section: section,
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error creating QR: $e")),
    );
  }
}

// Function to check if there's an active QR for today
Future<Map<String, dynamic>?> getActiveQR(String classCode, String section) async {
  final now = DateTime.now();
  final date = DateFormat('yyyy-MM-dd').format(now);

  try {
    final attendanceDoc = await FirebaseFirestore.instance
        .collection("global")
        .doc("classes")
        .collection("allClasses")
        .doc(classCode)
        .collection("attendance")
        .doc(date)
        .get();

    if (attendanceDoc.exists) {
      final data = attendanceDoc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final isActive = data['isActive'] ?? false;
      final qrSection = data['section'] ?? '';

      // Check if QR is still valid and for the same section
      if (isActive && expiresAt.isAfter(now) && qrSection == section) {
        return {
          'qrId': data['qrId'],
          'expiresAt': expiresAt,
          'section': section,
          'classCode': classCode,
          'date': date,
        };
      }
    }
  } catch (e) {
    print("Error checking active QR: $e");
  }
  
  return null;
}

// Function to deactivate expired QR
Future<void> deactivateQR(String classCode, String date) async {
  try {
    await FirebaseFirestore.instance
        .collection("global")
        .doc("classes")
        .collection("allClasses")
        .doc(classCode)
        .collection("attendance")
        .doc(date)
        .update({'isActive': false});
  } catch (e) {
    print("Error deactivating QR: $e");
  }
}