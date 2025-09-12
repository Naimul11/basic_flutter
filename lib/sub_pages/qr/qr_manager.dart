import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class QRManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates a unique document ID for QR attendance
  static String generateDocId(
    String classCode,
    String section, [
    DateTime? date,
  ]) {
    final targetDate = date ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    return "${dateStr}_${classCode}_$section";
  }

  /// Checks if there's a valid QR for today
  /// Checks if there's a valid QR for today
  static Future<Map<String, dynamic>?> checkTodaysQR(
    String classCode,
    String section,
  ) async {
    try {
      final now = DateTime.now();
      final docId = generateDocId(classCode, section);

      final attendanceDoc = await _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .doc(docId)
          .get();

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        final isActive = data['isActive'] ?? true;

        // Check if QR is expired
        if (expiresAt.isBefore(now) || !isActive) {
          // QR is expired or inactive, delete it
          await deleteExpiredQR(classCode, docId);
          return null; // No valid QR
        } else {
          // QR exists and is still valid
          return {
            'qrId': data['qrId'],
            'expiresAt': expiresAt,
            'section': data['section'] ?? section,
            'classCode': classCode,
            'date': DateFormat('yyyy-MM-dd').format(now),
            'docId': docId,
            'isValid': true,
          };
        }
      }
      return null; // No QR found
    } catch (e) {
      print("Error checking today's QR: $e");
      return null;
    }
  }

  /// Deletes an expired QR document
  static Future<bool> deleteExpiredQR(String classCode, String docId) async {
    try {
      await _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .doc(docId)
          .delete();

      print("Successfully deleted expired QR with docId: $docId");
      return true;
    } catch (e) {
      print("Error deleting expired QR: $e");
      return false;
    }
  }

  /// Cleans up any expired QRs before creating a new one
  static Future<bool> cleanupExpiredQRs(
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

      if (attendanceDoc.exists) {
        final data = attendanceDoc.data()!;
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        final now = DateTime.now();

        if (expiresAt.isBefore(now)) {
          await deleteExpiredQR(classCode, docId);
          return true; // Cleanup was performed
        }
      }
      return false; // No cleanup needed
    } catch (e) {
      print("Error cleaning up expired QRs: $e");
      return false;
    }
  }

  /// Creates a new QR code for attendance
  static Future<Map<String, dynamic>?> createQR({
    required String classCode,
    required String section,
    Duration? expirationDuration,
  }) async {
    try {
      // Clean up any existing expired QRs first
      await cleanupExpiredQRs(classCode, section);

      // Double-check if there's still a valid QR after cleanup
      final existingQR = await checkTodaysQR(classCode, section);
      if (existingQR != null && existingQR['isValid'] == true) {
        print("Valid QR already exists for today");
        return null; // Don't create duplicate QR
      }

      final now = DateTime.now();
      final date = DateFormat('yyyy-MM-dd').format(now);
      final qrId = const Uuid().v4();
      final expiresAt = now.add(expirationDuration ?? const Duration(minutes: 2));
      final docId = generateDocId(classCode, section);

      // Create QR data for encoding
      final qrData = {
        'classCode': classCode,
        'date': date,
        'section': section,
        'qrId': qrId,
        'createdAt': now.millisecondsSinceEpoch,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
      };

      // Save to Firestore
      final attendanceRef = _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .doc(docId);

      await attendanceRef.set({
        "qrId": qrId,
        "section": section,
        "classCode": classCode,
        "createdAt": FieldValue.serverTimestamp(),
        "expiresAt": Timestamp.fromDate(expiresAt),
        "date": date,
        "docId": docId,
        "isActive": true,
      }, SetOptions(merge: true));

      // Return the created QR data
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

  /// Checks if a specific QR is expired
  static bool isQRExpired(DateTime expiresAt) {
    return expiresAt.isBefore(DateTime.now());
  }

  /// Gets QR data for display/scanning
  static Map<String, dynamic> getQRData({
    required String classCode,
    required String section,
    required String qrId,
    required DateTime expiresAt,
    required String date,
  }) {
    return {
      'classCode': classCode,
      'date': date,
      'section': section,
      'qrId': qrId,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    };
  }

  /// Validates if a QR is still active and not expired
  static Future<bool> validateQR(String classCode, String qrId) async {
    try {
      // Query all attendance documents to find the one with matching qrId
      final querySnapshot = await _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .where("qrId", isEqualTo: qrId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return false; // QR not found
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();

      if (isQRExpired(expiresAt)) {
        // QR is expired, delete it
        await deleteExpiredQR(classCode, doc.id);
        return false;
      }

      return true; // QR is valid and active
    } catch (e) {
      print("Error validating QR: $e");
      return false;
    }
  }

  /// Get all active QRs for a class (for debugging/admin purposes)
  static Future<List<Map<String, dynamic>>> getActiveQRs(
    String classCode,
  ) async {
    try {
      final now = DateTime.now();
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

        if (expiresAt.isAfter(now)) {
          activeQRs.add({...data, 'expiresAt': expiresAt, 'docId': doc.id});
        } else {
          // Clean up expired QR
          await deleteExpiredQR(classCode, doc.id);
        }
      }

      return activeQRs;
    } catch (e) {
      print("Error getting active QRs: $e");
      return [];
    }
  }

  /// Clean up all expired QRs for a class
  static Future<int> cleanupAllExpiredQRs(String classCode) async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection("global")
          .doc("classes")
          .collection("allClasses")
          .doc(classCode)
          .collection("attendance")
          .get();

      int deletedCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();

        if (expiresAt.isBefore(now)) {
          await deleteExpiredQR(classCode, doc.id);
          deletedCount++;
        }
      }

      print("Cleaned up $deletedCount expired QRs for class $classCode");
      return deletedCount;
    } catch (e) {
      print("Error cleaning up all expired QRs: $e");
      return 0;
    }
  }
}
