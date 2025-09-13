import 'package:basic_flutter/sub_pages/contact_us.dart';
import 'package:basic_flutter/sub_pages/routes.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomMenuButton extends StatelessWidget {
  const CustomMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'refresh') {
          Navigator.pushReplacementNamed(
            context,
            ModalRoute.of(context)!.settings.name!,
          );
        } else if (value == 'contact us') {
          ContactUs.openEmail(context);
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem(value: 'refresh', child: Text('Refresh')),
          PopupMenuItem(value: 'contact us', child: Text('Contact us')),
        ];
      },
    );
  }
}

Future<bool> devicelost(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Notice'),
        content: const Text('Please login from your own device'),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(lostdevice, (route) => false);
            },
            child: const Text('Get Help'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('Ok'),
          ),
        ],
      );
    },
  ).then((value) => value ?? false);
}
