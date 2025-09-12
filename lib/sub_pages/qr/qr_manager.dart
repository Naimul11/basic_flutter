import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class QRManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String generateDocId(
    String classCode,
    String section, [
    DateTime? date,
  ]) {
    final targetDate = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    return "${dateStr}_${classCode}_$section";
  }

  /// Checks today's QR status
  static Future<Map<String, dynamic>?> checkTodaysQR(
    String classCode,
    String section,
  ) async {
    try {
      final docId = generateDocId(classCode, section);
      final attendanceDoc = await _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .doc(docId)
          .get();

      if (!attendanceDoc.exists) return null;

      final data = attendanceDoc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final isActive = data['isActive'] ?? true;

      if (expiresAt.isBefore(DateTime.now()) || !isActive) {
        await _expireQR(classCode, docId);
        return null;
      }

      return {
        'qrId': data['qrId'],
        'expiresAt': expiresAt,
        'section': section,
        'classCode': classCode,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'docId': docId,
        'isValid': true,
      };
    } catch (e) {
      print("Error checking today's QR: $e");
      return null;
    }
  }

  /// Expires QR by updating isActive to false instead of deleting
  static Future<bool> _expireQR(String classCode, String docId) async {
    try {
      await _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .doc(docId)
          .update({
            'isActive': false,
            'expiresAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Creates or updates QR for attendance
  static Future<Map<String, dynamic>?> createQR({
    required String classCode,
    required String section,
    Duration? expirationDuration,
  }) async {
    try {
      final now = DateTime.now();
      final date = DateFormat('yyyy-MM-dd').format(now);
      final qrId = const Uuid().v4();
      final expiresAt = now.add(
        expirationDuration ?? const Duration(minutes: 2),
      );
      final docId = generateDocId(classCode, section);

      // Check if attendance document exists
      final attendanceRef = _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .doc(docId);

      final existingDoc = await attendanceRef.get();

      if (existingDoc.exists) {
        // Update existing document with new QR
        await attendanceRef.update({
          "qrId": qrId,
          "expiresAt": Timestamp.fromDate(expiresAt),
          "isActive": true,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      } else {
        // Create new attendance document
        await attendanceRef.set({
          "qrId": qrId,
          "section": section,
          "classCode": classCode,
          "createdAt": FieldValue.serverTimestamp(),
          "expiresAt": Timestamp.fromDate(expiresAt),
          "date": date,
          "docId": docId,
          "isActive": true,
        });
      }

      final qrData = {
        'classCode': classCode,
        'date': date,
        'section': section,
        'qrId': qrId,
        'createdAt': now.millisecondsSinceEpoch,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
      };

      return {
        'qrId': qrId,
        'expiresAt': expiresAt,
        'section': section,
        'classCode': classCode,
        'date': date,
        'docId': docId,
        'qrString': jsonEncode(qrData),
      };
    } catch (e) {
      print("Error creating QR: $e");
      return null;
    }
  }

  /// Checks if QR is expired
  static bool isQRExpired(DateTime expiresAt) =>
      expiresAt.isBefore(DateTime.now());

  /// Gets QR data for display/scanning
  static Map<String, dynamic> getQRData({
    required String classCode,
    required String section,
    required String qrId,
    required DateTime expiresAt,
    required String date,
  }) => {
    'classCode': classCode,
    'date': date,
    'section': section,
    'qrId': qrId,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
  };

  /// Validates QR and returns status
  static Future<bool> validateQR(String classCode, String qrId) async {
    try {
      final querySnapshot = await _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .where("qrId", isEqualTo: qrId)
          .where("isActive", isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return false;

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (isQRExpired(expiresAt)) {
        await _expireQR(classCode, doc.id);
        return false;
      }

      return true;
    } catch (e) {
      print("Error validating QR: $e");
      return false;
    }
  }

  /// Gets active QRs for a class
  static Future<List<Map<String, dynamic>>> getActiveQRs(
    String classCode,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .where("isActive", isEqualTo: true)
          .get();

      List<Map<String, dynamic>> activeQRs = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();

        if (expiresAt.isAfter(DateTime.now())) {
          activeQRs.add({...data, 'expiresAt': expiresAt, 'docId': doc.id});
        } else {
          await _expireQR(classCode, doc.id);
        }
      }

      return activeQRs;
    } catch (e) {
      print("Error getting active QRs: $e");
      return [];
    }
  }

  /// Cleanup expired QRs (marks as inactive instead of deleting)
  static Future<int> cleanupExpiredQRs(String classCode) async {
    try {
      final querySnapshot = await _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .where("isActive", isEqualTo: true)
          .get();

      int expiredCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();

        if (expiresAt.isBefore(DateTime.now())) {
          await _expireQR(classCode, doc.id);
          expiredCount++;
        }
      }

      print("Expired $expiredCount QRs for class $classCode");
      return expiredCount;
    } catch (e) {
      print("Error cleaning up expired QRs: $e");
      return 0;
    }
  }

  // Legacy methods for backward compatibility
  static Future<bool> deleteExpiredQR(String classCode, String docId) async {
    return await _expireQR(classCode, docId);
  }

  static Future<int> cleanupAllExpiredQRs(String classCode) async {
    return await cleanupExpiredQRs(classCode);
  }
}
