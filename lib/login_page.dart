import 'package:basic_flutter/sub_pages/device_id.dart';
import 'package:basic_flutter/sub_pages/menu_button.dart';
import 'package:basic_flutter/sub_pages/show_pass.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:basic_flutter/sub_pages/errordialog.dart';
import 'package:basic_flutter/sub_pages/routes.dart';
import 'sub_pages/firebase_options.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  late TextEditingController _email;
  late TextEditingController _password;
  late String typeOfUser;
  late String deviceId;
  late String? loginDevice;

  @override
  void initState() {
    _email = TextEditingController();
    _password = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<int> _countAccountsWithDevice(String deviceId) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('DeviceId', isEqualTo: deviceId)
        .get();
    return query.docs.length;
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text.trim();

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null && userCredential.user!.emailVerified) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        typeOfUser = doc['userType'];
        deviceId = doc['DeviceId'];
        loginDevice = await getAndroidDeviceId();

        final count = await _countAccountsWithDevice(loginDevice!);
        if (count > 1) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Device Blocked"),
              content: const Text(
                "This device is linked with multiple accounts",
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil(lostdevice, (route) => false);
                  },
                  child: const Text("Get Help"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
          await FirebaseAuth.instance.signOut();
          return;
        }

        if (loginDevice != deviceId) {
          await FirebaseAuth.instance.signOut();
          await devicelost(context);
          return;
        }

        if (typeOfUser == 'Student') {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(student, (route) => false);
        } else {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(teacher, (route) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'invalid-credential') {
        message = 'Incorrect Username or Password';
      }
      if (!mounted) return;
      await showError(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 161, 115),
        title: const Text('Login'),
        actions: [CustomMenuButton()],
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 200,
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Image.asset(
                          'assets/Logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        enableSuggestions: false,
                        decoration: inputDecoration('Enter your email'),
                      ),
                      const SizedBox(height: 16),
                      passwordField(controller: _password),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            if (_email.text.isNotEmpty) {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(
                                    email: _email.text.trim(),
                                  );
                              if (!mounted) return;
                              await showError(
                                context,
                                "Password reset email sent!",
                              );
                            } else {
                              await showError(
                                context,
                                "Please enter your email first",
                              );
                            }
                          },
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              0,
                              161,
                              115,
                            ),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _login,
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color.fromARGB(255, 0, 161, 115),
                              width: 2,
                            ),
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushNamed(register);
                          },
                          child: const Text(
                            "Create New Account",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
