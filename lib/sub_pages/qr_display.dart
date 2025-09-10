import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRDisplayPage extends StatelessWidget {
  final String qrData;

  const QRDisplayPage({super.key, required this.qrData});

  @override
  Widget build(BuildContext context) {
    final bool isValidData = qrData.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance QR"),
        backgroundColor: const Color.fromARGB(255, 0, 161, 115),
        centerTitle: true,
        elevation: 2,
      ),
      body: Center(
        child: isValidData
            ? QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
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
