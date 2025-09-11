import 'dart:convert';
import 'package:basic_flutter/sub_pages/qr_display.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> createQR(BuildContext context, String classCode) async {
  final now = DateTime.now();
  final date = DateFormat('yyyy-MM-dd').format(now);
  final qrId = const Uuid().v4(); // unique QR ID

  final qrData = {'classCode': classCode, 'date': date, 'qrId': qrId};
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
      "createdAt": FieldValue.serverTimestamp(),
      "date": date,
    }, SetOptions(merge: true));

    // Navigate to QR display page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QRDisplayPage(qrData: qrString)),
    );
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Error creating QR: $e")));
  }
}
