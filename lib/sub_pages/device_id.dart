import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

Future<String> getAndroidDeviceId() async {
  try {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else {
      return '';
    }
  } catch (e) {
    return '';
  }
}
