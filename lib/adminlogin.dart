import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/admin/dashboard.dart';
import 'package:chatbot/adminregister.dart';
import 'package:chatbot/forgotpassword.dart';

const primarycolor = Color(0xFF800000);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFFffc803);
const dark = Color(0xFF17110d);
const textdark = Color(0xFF343a40);
const textlight = Color(0xFFFFFFFF);
const lightBackground = Color(0xFFFEFEFE);

const storage = FlutterSecureStorage();

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? errorMessage;

  String? appName;
  String? tagline;
  String? description;
  String? logoPath;
  String? backgroundImageUrl;
  bool isSettingsLoaded = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const List<String> _possibleAesKeyNames = [
    'app_aes_key_v1',
    'app_aes_key_v1_superadmin'
  ];
  encrypt.Key? _cachedKey;

  Future<encrypt.Key> _getOrCreateAesKey() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .get();
      
      if (doc.exists && doc.data()?['key'] != null) {
        final keyBase64 = doc.data()!['key'] as String;
        final keyBytes = base64Decode(keyBase64);
        
        for (final keyName in _possibleAesKeyNames) {
          await storage.write(key: keyName, value: keyBase64);
        }
        
        print('✅ Loaded encryption key from Firestore');
        return encrypt.Key(keyBytes);
      }
    } catch (e) {
      print('⚠️ Error loading key from Firestore: $e');
    }

    for (final keyName in _possibleAesKeyNames) {
      final base64Key = await storage.read(key: keyName);
      if (base64Key != null) {
        final keyBytes = base64Decode(base64Key);
        if (keyBytes.length == 32) {
          print('✅ Loaded encryption key from local storage');
          return encrypt.Key(keyBytes);
        }
      }
    }

    final newKey = encrypt.Key.fromSecureRandom(32);
    final base64Key = base64Encode(newKey.bytes);

    try {
      await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .set({
        'key': base64Key,
        'createdAt': FieldValue.serverTimestamp(),
        'version': 'v1',
      });
      print('✅ Created new encryption key in Firestore');
    } catch (e) {
      print('⚠️ Could not save key to Firestore: $e');
    }

    await storage.write(key: _possibleAesKeyNames.first, value: base64Key);
    print('✅ Created new encryption key locally');

    return newKey;
  }
  
  Future<String?> _encryptValue(String plainText) async {
    if (plainText.isEmpty) return null;

    try {
      final key = await _getOrCreateAesKey();
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      final combinedBytes = iv.bytes + encrypted.bytes;
      return base64Encode(combinedBytes);
    } catch (e) {
      print('❌ Encryption failed: $e');
      return null;
    }
  }

  Future<String?> _decryptValue(String encoded) async {
    if (encoded.isEmpty) return null;
    final key = await _getOrCreateAesKey();
    if (key == null) return null; 
    try {
      final combined = base64Decode(encoded);
      if (combined.length < 17) return null;
      final ivBytes = combined.sublist(0, 16);
      final cipherBytes = combined.sublist(16);
      final iv = encrypt.IV(ivBytes);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final encrypted = encrypt.Encrypted(cipherBytes);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      // decryption failed
      return null;
    }
  }

  Future<Map<String, String>?> _loadLocalEncryptedCredentials() async {
    try {
      final keysToTry = [
        ['superadmin_email_local', 'superadmin_password_local'],
        ['admin_email_local', 'admin_password_local']
      ];

      for (final pair in keysToTry) {
        final encEmail = await _secureStorage.read(key: pair[0]);
        final encPass = await _secureStorage.read(key: pair[1]);
        if (encEmail != null && encPass != null) {
          final decEmail = await _decryptValue(encEmail);
          final decPass = await _decryptValue(encPass);
          if (decEmail != null && decPass != null) {
            return {'email': decEmail, 'password': decPass};
          }
        }
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSystemSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showEmergencyAccessDialog() async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: lightBackground,
          title: Text(
            'Emergency Access Request',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: primarycolordark,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This request is only for verified PSU staff in case all Super Admins are unavailable.',
                  style: GoogleFonts.poppins(fontSize: 13, color: textdark),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Your PSU Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your PSU email';
                    }
                    if (!value.endsWith('@pampangastateu.edu.ph')) {
                      return 'Only PSU staff emails are allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for request',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please provide a reason';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primarycolor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final email = emailController.text.trim();
                final reason = reasonController.text.trim();

                try {
                  final existing = await FirebaseFirestore.instance
                      .collection('EmergencyAccessRequests')
                      .where('email', isEqualTo: email)
                      .where('status', isEqualTo: 'pending')
                      .get();

                  if (existing.docs.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        content: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'You already have a pending emergency request.',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                final encryptedEmail = await _encryptValue(email);

                if (encryptedEmail == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Encryption failed — please try again."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                await FirebaseFirestore.instance.collection('EmergencyAccessRequests').add({
                  'email': encryptedEmail,
                  'reason': reason,
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });

                  if (!mounted) return;
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      content: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: primarycolor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Request sent to PSU IT Security for verification.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      content: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Error sending request. Please try again later.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
              child: Text('Send Request', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSystemSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('global')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        if (!mounted) return;
        setState(() {
          appName = data['siteName'] ?? "AskPSU MANAGEMENT SYSTEM";
          tagline =
              data['tagline'] ?? "Efficiently manage your AskPSU operations";
          description = data['description'] ??
              "Efficiently manage AskPSU records, users, and services through a centralized and user-friendly system.";
          logoPath = data['universityLogoUrl'] ?? 'assets/images/DHVSU-LOGO.png';
          backgroundImageUrl = data['backgroundImageUrl'];
          isSettingsLoaded = true;
        });
      } else {
        if (!mounted) return;
        setState(() {
          isSettingsLoaded = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSettingsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isSettingsLoaded) {
      return Scaffold(
        backgroundColor: lightBackground,
        body: Center(
          child: Lottie.asset(
            'assets/animations/Live chatbot.json',
            width: 200,
            height: 200,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          if (isMobile) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildLeftPanel(isMobile: true),
                    const SizedBox(height: 20),
                    _buildRightForm(isMobile: true),
                  ],
                ),
              ),
            );
          }
          return Row(
            children: [
              Expanded(child: _buildLeftPanel()),
              Expanded(child: _buildRightForm()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeftPanel({bool isMobile = false}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        image: backgroundImageUrl != null && backgroundImageUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(backgroundImageUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.65),
                  BlendMode.darken,
                ),
              )
            : const DecorationImage(
                image: AssetImage('assets/images/maroon.jpg'),
                fit: BoxFit.cover,
              ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Column(
        mainAxisAlignment:
            isMobile ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isMobile) const SizedBox(height: 30),
          if (!isMobile)
          Expanded(
            child: SizedBox.expand(
              child: Center(
                child: isSettingsLoaded
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            // onLongPress: _showEmergencyAccessDialog,
                            child: logoPath != null && logoPath!.startsWith('http')
                                ? Image.network(
                                    logoPath!,
                                    height: 100,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      'assets/images/DHVSU-LOGO.png',
                                      height: 100,
                                    ),
                                  )
                                : Image.asset(
                                    logoPath ?? 'assets/images/DHVSU-LOGO.png',
                                    height: 100,
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            appName ?? "",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tagline ?? "",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
          if (isMobile && isSettingsLoaded)
            Column(
              children: [
                // LONG PRESS (MOBILE)
                GestureDetector(
                  // onLongPress: _showEmergencyAccessDialog,
                  child: logoPath != null && logoPath!.startsWith('http')
                      ? Image.network(
                          logoPath!,
                          height: 100,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/DHVSU-LOGO.png',
                            height: 100,
                          ),
                        )
                      : Image.asset(
                          logoPath ?? 'assets/images/DHVSU-LOGO.png',
                          height: 100,
                        ),
                ),
                const SizedBox(height: 20),
                Text(
                  appName ?? "",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  tagline ?? "",
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
              ],
            ),
          if (isSettingsLoaded)
            Text(
              description ?? "",
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _buildRightForm({bool isMobile = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 40,
        vertical: 40,
      ),
      child: Column(
        mainAxisAlignment:
            isMobile ? MainAxisAlignment.start : MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Login Your Account',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primarycolordark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email and password to sign in.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: textdark,
            ),
          ),
          const SizedBox(height: 30),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  style: GoogleFonts.poppins(color: textdark),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    labelStyle: GoogleFonts.poppins(color: textdark),
                    border: const OutlineInputBorder(),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: primarycolor, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Please enter your email.';
                    final emailRegex = RegExp(
                        r"^[a-zA-Z0-9]+([._%+-]?[a-zA-Z0-9])*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
                    if (!emailRegex.hasMatch(v)) return 'Enter a valid email.';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.poppins(color: textdark),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    labelStyle: GoogleFonts.poppins(color: textdark),
                    border: const OutlineInputBorder(),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: primarycolor, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: textdark,
                      ),
                      onPressed: () {
                        if (!mounted) return;
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                    ),
                  ),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return 'Please enter your password.';
                    if (v.length < 8) {
                      return 'Password must be at least 8 characters.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                );
              },
              child: Text(
                "Forgot Password?",
                style: GoogleFonts.poppins(
                  color: primarycolordark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              width: double.infinity,
              color: Colors.red[100],
              child: Text(
                errorMessage!,
                style: GoogleFonts.poppins(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 10),
          _isLoading
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primarycolor),
                )
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primarycolor,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.1,
                      ),
                    ),
                    onPressed: _login,
                    child: const Text('Sign in'),
                  ),
                ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminRegisterPage()),
              );
            },
            child: Text.rich(
              TextSpan(
                text: "Doesn’t have an account? ",
                style: GoogleFonts.poppins(color: textdark),
                children: [
                  TextSpan(
                    text: 'Sign Up',
                    style: GoogleFonts.poppins(
                      color: primarycolordark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final typedEmail = _emailController.text.trim();
    final typedPassword = _passwordController.text;

    setState(() {
      errorMessage = null;
      _isLoading = true;
    });

    UserCredential? userCredential;

    Future<UserCredential> _attemptSignIn(String email, String password) async {
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    bool usedLocalCredentials = false;

    try {
      userCredential = await _attemptSignIn(typedEmail, typedPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        final local = await _loadLocalEncryptedCredentials();
        if (local != null) {
          try {
            userCredential = await _attemptSignIn(local['email']!, local['password']!);
            usedLocalCredentials = true;
          } on FirebaseAuthException catch (e2) {
            setState(() {
              if (e2.code == 'wrong-password') {
                errorMessage = "Incorrect password.";
              } else if (e2.code == 'user-not-found') {
                errorMessage = "No user found with this email.";
              } else if (e2.code == 'too-many-requests') {
                errorMessage = "Too many attempts. Try again later.";
              } else {
                errorMessage = e2.message ?? "Login failed. Please try again.";
              }
            });
            userCredential = null;
          } catch (e3) {
            setState(() {
              errorMessage = "Unexpected error during auto-login. Please try again.";
            });
            userCredential = null;
          }
        } else {
          setState(() {
            errorMessage = "No account found with this email.";
          });
          userCredential = null;
        }
      } else if (e.code == 'wrong-password') {
        setState(() {
          errorMessage = "Incorrect password.";
        });
      } else if (e.code == 'too-many-requests') {
        setState(() {
          errorMessage = "Too many attempts. Try again later.";
        });
      } else {
        setState(() {
          errorMessage = e.message ?? "Login failed. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Unexpected error. Please try again.";
      });
    }

    if (userCredential == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final user = userCredential.user;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Login failed. Please try again.";
        _isLoading = false;
      });
      return;
    }

    final uid = user.uid;

    try {
      final superAdminDoc = await FirebaseFirestore.instance.collection('SuperAdmin').doc(uid).get();
      if (superAdminDoc.exists) {
        await user.reload();
        final freshUser = FirebaseAuth.instance.currentUser;
        final emailVerified = freshUser?.emailVerified ?? false;
        if (!emailVerified) {
          await _showEmailNotVerifiedDialog(freshUser);
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          setState(() => _isLoading = false);
          return;
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuperAdminDashboardPage()),
        );
        return;
      }

      final adminDoc = await FirebaseFirestore.instance.collection('Admin').doc(uid).get();
      if (!adminDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          errorMessage = "Access denied. You are not authorized as an admin.";
          _isLoading = false;
        });
        return;
      }

      await user.reload();
      final freshUser = FirebaseAuth.instance.currentUser;
      final emailVerified = freshUser?.emailVerified ?? false;
      if (!emailVerified) {
        await _showEmailNotVerifiedDialog(freshUser);
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final adminData = adminDoc.data()!;
      final status = (adminData['status'] ?? '').toString().toLowerCase();

      if (status == 'pending') {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          errorMessage = "Your account is still pending approval.";
          _isLoading = false;
        });
        return;
      } else if (status != 'active') {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          errorMessage = "Your account is currently $status. Contact the administrator.";
          _isLoading = false;
        });
        return;
      }

      await FirebaseFirestore.instance.collection('Admin').doc(uid).update({
        'status': 'active',
        'lastLogin': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    } catch (e) {
      // Any unexpected error after sign-in: sign out to be safe
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        errorMessage = "Unexpected error. Please try again.";
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showEmailNotVerifiedDialog(User? user) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Email not verified', style: GoogleFonts.poppins()),
        content: Text(
          'Your email is not verified. Check your inbox or resend the verification email.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Okay', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (user == null) return;
              try {
                await user.sendEmailVerification();
                setState(() {
                  errorMessage =
                      "Verification email sent. Please check your inbox.";
                });
              } catch (_) {
                setState(() {
                  errorMessage =
                      "Failed to send verification email. Try again later.";
                });
              }
            },
            child: Text('Resend', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}