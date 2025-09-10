import 'dart:convert';
import 'package:basic_flutter/sub_pages/qr_display.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

void createQR(BuildContext context, String classCode) {
  final now = DateTime.now();
  final date = DateFormat('yyyy-MM-dd').format(now);
  final qrId = const Uuid().v4(); // unique ID

  final qrData = {'classCode': classCode, 'date': date, 'qrId': qrId};

  final qrString = jsonEncode(qrData);

  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => QRDisplayPage(qrData: qrString)),
  );
}
