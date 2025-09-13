// contact_us.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUs {
  static Future<void> openEmail(BuildContext context) async {
    final String email = 'naimulislamcse@gmail.com';
    final String subject = 'Contact Us from App';
    final String body =
        'Hello,\n\nI would like to contact support regarding...';

    // Build mailto URI
    final Uri emailUri = Uri.parse(
      'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      // Directly launch the email client without canLaunchUrl check
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Show error if no email app is available
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to open email app. Please make sure Gmail or another email client is installed.\nError: $e',
          ),
        ),
      );
    }
  }
}
