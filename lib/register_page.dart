import 'package:basic_flutter/email_verify.dart';
import 'package:basic_flutter/errordialog.dart';
import 'package:basic_flutter/firebase_options.dart';
import 'package:basic_flutter/routes.dart';
import 'package:basic_flutter/uni_related.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  List<bool> isSelected = [true, false]; // Default: Student selected
  String userType = "Student";

  late TextEditingController _name;
  late TextEditingController _section;
  late TextEditingController _email;
  late TextEditingController _password;
  late TextEditingController _cpassword;

  bool? _uniVerified = false;
  bool _emailVerified = false;
  String? _studentId;
  String? _uid;

  @override
  void initState() {
    _name = TextEditingController();
    _section = TextEditingController();
    _email = TextEditingController();
    _password = TextEditingController();
    _cpassword = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _name.dispose();
    _section.dispose();
    _email.dispose();
    _password.dispose();
    _cpassword.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 161, 115),
        title: const Text("Register"),
        elevation: 0,
      ),
      body: FutureBuilder(
        future: Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        builder: (context, asyncSnapshot) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Toggle Button for Student/Teacher
                  Center(
                    child: ToggleButtons(
                      borderRadius: BorderRadius.circular(12),
                      isSelected: isSelected,
                      selectedColor: Colors.white,
                      color: Colors.black,
                      fillColor: const Color.fromARGB(255, 0, 161, 115),
                      textStyle: const TextStyle(fontSize: 16),
                      onPressed: (int index) {
                        setState(() {
                          for (int i = 0; i < isSelected.length; i++) {
                            isSelected[i] = i == index;
                          }
                          userType = index == 0 ? "Student" : "Teacher";
                        });
                      },
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            "Student",
                            style: TextStyle(
                              fontSize: isSelected[0] ? 18 : 16,
                              fontWeight: isSelected[0]
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            "Teacher",
                            style: TextStyle(
                              fontSize: isSelected[1] ? 18 : 16,
                              fontWeight: isSelected[1]
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Name
                  TextField(
                    controller: _name,
                    enableSuggestions: true,
                    decoration: inputDecoration('Enter your Name'),
                  ),
                  const SizedBox(height: 16),

                  // Email with Verify Button inside
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    enableSuggestions: false,
                    decoration: inputDecoration('Enter your Email').copyWith(
                      suffixIcon: StatefulBuilder(
                        builder: (context, setStateSB) {
                          return TextButton(
                            onPressed: () async {
                              final result = await Navigator.of(context)
                                  .push<Map<String, dynamic>>(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          VerifyEmail(email: _email.text),
                                    ),
                                  );

                              if (result != null) {
                                setState(() {
                                  _emailVerified = result['verified'];
                                  _uid = result['uid'];
                                });
                                setStateSB(() {}); // update button state
                              }
                            },
                            child: Text(
                              _emailVerified ? 'Verified' : 'Verify',
                              style: TextStyle(
                                color: _emailVerified
                                    ? const Color.fromARGB(
                                        255,
                                        3,
                                        100,
                                        19,
                                      ) // Green tone
                                    : const Color.fromARGB(
                                        255,
                                        160,
                                        0,
                                        0,
                                      ), // Red tone
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextField(
                    controller: _password,
                    obscureText: true,
                    enableSuggestions: false,
                    decoration: inputDecoration(
                      _emailVerified
                          ? 'Enter your Password'
                          : 'Verify your email first',
                    ),
                    enabled: _emailVerified,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  TextField(
                    controller: _cpassword,
                    obscureText: true,
                    enableSuggestions: false,
                    decoration: inputDecoration(
                      _emailVerified
                          ? 'Enter your Password'
                          : 'Verify your email first',
                    ),
                    enabled: _emailVerified,
                  ),
                  const SizedBox(height: 16),

                  // Section / Designation
                  if (userType == "Student")
                    TextField(
                      controller: _section,
                      enableSuggestions: true,
                      decoration: inputDecoration('Enter your Section'),
                    )
                  else
                    TextField(
                      controller: _section,
                      enableSuggestions: true,
                      decoration: inputDecoration('Enter your Designation'),
                    ),
                  const SizedBox(height: 30),

                  // University Verification
                  Text(
                    ' *Are you registering as part of a university program?',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () async {
                        final result = await Navigator.of(context)
                            .push<Map<String, dynamic>>(
                              MaterialPageRoute(
                                builder: (context) => const UniVerify(),
                              ),
                            );
                        if (result != null) {
                          setState(() {
                            _uniVerified = result['verified'];
                            _studentId = result['sid'];
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _uniVerified == true
                            ? const Color.fromARGB(
                                255,
                                0,
                                161,
                                115,
                              ) 
                            : const Color.fromARGB(182, 6, 148, 51),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        minimumSize: const Size(0, 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _uniVerified == true ? 'Verified' : 'Verify Profile',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Register Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color.fromARGB(255, 0, 161, 115),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        if (!_emailVerified) {
                          await showError(
                            context,
                            "Please verify your email before registering",
                          );
                          return;
                        }

                        if (_password.text != _cpassword.text) {
                          await showError(context, 'Passwords do not match');
                          return;
                        }

                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await user.updatePassword(_password.text);
                          }
                          final uid = _uid;
                          if (uid == null) throw Exception('UID missing');

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .set({
                                'name': _name.text,
                                'email': _email.text,
                                'studentId': _studentId,
                                'userType': userType,
                                'section': _section.text,
                                'verified': _uniVerified,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                        } catch (e) {
                          await showError(context, 'Registration Failed');
                          return;
                        }

                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil(login, (route) => false);
                      },
                      child: const Text(
                        'Register',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Login Navigation
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil(login, (route) => false);
                      },
                      child: const Text(
                        'Already registered? Login here!',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
