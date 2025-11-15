import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

const primarycolor = Color(0xFF800000);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFFffc803);
const dark = Color(0xFF17110d);
const textdark = Color(0xFF343a40);
const textlight = Color(0xFFFFFFFF);
const lightBackground = Color(0xFFFEFEFE);

class SuperAdminRegisterPage extends StatefulWidget {
  const SuperAdminRegisterPage({super.key});

  @override
  State<SuperAdminRegisterPage> createState() => _SuperAdminRegisterPageState();
}

class _SuperAdminRegisterPageState extends State<SuperAdminRegisterPage> {
  String? accessKey;
  bool isAuthorized = false;
  
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? errorMessage;
  bool canResend = true;
  int resendCooldown = 60;
  Timer? cooldownTimer;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  String? appName;
  String? tagline;
  String? description;
  String? logoPath;
  String? backgroundImageUrl;
  bool isSettingsLoaded = false;

  Timer? _verificationTimer;
  bool _isCheckingVerification = false;

  // Secure storage and encryption setup
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _aesKeyStorageKey = 'app_aes_key_v1';
  encrypt.Key? _cachedKey;

  // ✅ Navigate to main URL
  void _navigateToMainUrl() {
    if (mounted) {
      // Change browser URL to root
      html.window.history.pushState(null, '', '/');
      // Navigate in Flutter
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<encrypt.Key> _getOrCreateAesKey() async {
    if (_cachedKey != null) return _cachedKey!;
    
    // 1. Try loading from Firestore first (shared key)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .get();
      
      if (doc.exists && doc.data()?['key'] != null) {
        final keyBase64 = doc.data()!['key'] as String;
        final keyBytes = base64Decode(keyBase64);
        
        // Save locally for faster access next time
        await _secureStorage.write(
          key: _aesKeyStorageKey,
          value: keyBase64,
          aOptions: const AndroidOptions(encryptedSharedPreferences: true),
          iOptions: const IOSOptions(),
        );
        
        _cachedKey = encrypt.Key(keyBytes);
        print('✅ SuperAdmin: Loaded encryption key from Firestore');
        return _cachedKey!;
      }
    } catch (e) {
      print('⚠️ SuperAdmin: Error loading key from Firestore: $e');
    }
    
    // 2. Try reading from local storage
    final existing = await _secureStorage.read(key: _aesKeyStorageKey);
    if (existing != null) {
      final bytes = base64Decode(existing);
      _cachedKey = encrypt.Key(bytes);
      print('✅ SuperAdmin: Loaded encryption key from local storage');
      return _cachedKey!;
    }
    
    // 3. Create new key and save to both Firestore and local storage
    final generated = encrypt.Key.fromSecureRandom(32);
    final keyBase64 = base64Encode(generated.bytes);
    
    // Save to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('encryption_key')
          .set({
        'key': keyBase64,
        'createdAt': FieldValue.serverTimestamp(),
        'version': 'v1',
      });
      print('✅ SuperAdmin: Created new encryption key in Firestore');
    } catch (e) {
      print('⚠️ SuperAdmin: Could not save key to Firestore: $e');
    }
    
    // Save locally
    await _secureStorage.write(
      key: _aesKeyStorageKey,
      value: keyBase64,
      aOptions: const AndroidOptions(encryptedSharedPreferences: true),
      iOptions: const IOSOptions(),
    );
    
    _cachedKey = generated;
    print('✅ SuperAdmin: Created new encryption key locally');
    return _cachedKey!;
  }

  // Encrypts value, returns base64(iv + ciphertext)
  Future<String> _encryptValue(String plain) async {
    final key = await _getOrCreateAesKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    final combined = <int>[]..addAll(iv.bytes)..addAll(encrypted.bytes);
    return base64Encode(combined);
  }

  // Decrypt helper if needed
  Future<String> _decryptValue(String encoded) async {
    final key = await _getOrCreateAesKey();
    final combined = base64Decode(encoded);
    if (combined.length < 17) return '';
    final ivBytes = combined.sublist(0, 16);
    final cipherBytes = combined.sublist(16);
    final iv = encrypt.IV(ivBytes);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypt.Encrypted(cipherBytes);
    return encrypter.decrypt(encrypted, iv: iv);
  }

  void _startResendCooldown() {
    setState(() {
      canResend = false;
      resendCooldown = 60;
    });

    cooldownTimer?.cancel();
    cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (resendCooldown > 1) {
        setState(() {
          resendCooldown--;
        });
      } else {
        timer.cancel();
        setState(() {
          canResend = true;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _checkAccessKey();
    _loadSystemSettings();
  }

  void _checkAccessKey() {
    final uri = Uri.base;
    final key = uri.queryParameters['key'];
    const validKey = 'PSU-IT60-2025';
    
    // Debug prints
    debugPrint('🔍 SuperAdmin Page - Checking access key');
    debugPrint('🔍 Full URI: ${uri.toString()}');
    debugPrint('🔍 Path: ${uri.path}');
    debugPrint('🔍 Query Key: $key');
    debugPrint('🔍 Valid Key: $validKey');
    debugPrint('🔍 Is Authorized: ${key == validKey}');
    
    setState(() {
      accessKey = key;
      isAuthorized = (key == validKey);
    });
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    cooldownTimer?.cancel();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    contactController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _showFloatingSnackBar(String message, {Color color = primarycolor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: color,
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _loadSystemSettings() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('SystemSettings').doc('global').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          appName = data['siteName'] ?? "AskPSU MANAGEMENT SYSTEM";
          tagline = data['tagline'] ?? "Efficiently manage your AskPSU operations";
          description = data['description'] ??
              "Efficiently manage AskPSU records, users, and services through a centralized and user-friendly system.";
          logoPath = data['universityLogoUrl'] ?? 'assets/images/DHVSU-LOGO.png';
          backgroundImageUrl = data['backgroundImageUrl'];
          isSettingsLoaded = true;
        });
      } else {
        setState(() {
          isSettingsLoaded = true;
        });
      }
    } catch (e) {
      // silent fail but set loaded so UI shows
      setState(() {
        isSettingsLoaded = true;
      });
      print('Error loading system settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isAuthorized) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey[700]),
              const SizedBox(height: 20),
              Text(
                "Access Denied",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "You are not authorized to view this page.",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 30),
              // ✅ Add button to go back to main page
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primarycolor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                onPressed: _navigateToMainUrl,
                child: Text(
                  'Go to Login',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

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

          return isMobile
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildLeftPanel(isMobile: true),
                      _buildRightForm(isMobile: true),
                    ],
                  ),
                )
              : Row(
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
        mainAxisAlignment: isMobile ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isMobile) const SizedBox(height: 30),
          if (!isMobile)
            Expanded(
              child: Center(
                child: isSettingsLoaded
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          logoPath != null && logoPath!.startsWith('http')
                              ? Image.network(
                                  logoPath!,
                                  height: 100,
                                  errorBuilder: (_, __, ___) =>
                                      Image.asset('assets/images/DHVSU-LOGO.png', height: 100),
                                )
                              : Image.asset(logoPath ?? 'assets/images/DHVSU-LOGO.png', height: 100),
                          const SizedBox(height: 20),
                          Text(appName ?? "",
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text(tagline ?? "",
                              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          if (isMobile && isSettingsLoaded)
            Column(
              children: [
                logoPath != null && logoPath!.startsWith('http')
                    ? Image.network(logoPath!, height: 100)
                    : Image.asset(logoPath ?? 'assets/images/DHVSU-LOGO.png', height: 100),
                const SizedBox(height: 20),
                Text(appName ?? "",
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(tagline ?? "",
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 30),
              ],
            ),
          if (isSettingsLoaded)
            Text(description ?? "",
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildRightForm({bool isMobile = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: 40),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: isMobile ? MainAxisAlignment.start : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Create your account',
                style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.bold, color: primarycolordark)),
            const SizedBox(height: 8),
            Text('Fill in the details below to register as Super Admin.',
                style: GoogleFonts.poppins(fontSize: 14, color: textdark)),
            const SizedBox(height: 30),

            // --- First Name + Last Name Row ---
            if (isMobile) ...[
              _buildTextField(firstNameController, 'First Name'),
              const SizedBox(height: 20),
              _buildTextField(lastNameController, 'Last Name'),
              const SizedBox(height: 20),
            ] else ...[
              Row(
                children: [
                  Expanded(child: _buildTextField(firstNameController, 'First Name')),
                  const SizedBox(width: 20),
                  Expanded(child: _buildTextField(lastNameController, 'Last Name')),
                ],
              ),
              const SizedBox(height: 20),
            ],

            _buildTextField(emailController, 'Email'),
            const SizedBox(height: 20),

            TextFormField(
              controller: contactController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: 'Contact Number',
                labelStyle: GoogleFonts.poppins(color: textdark),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: primarycolor, width: 2)),
                prefixText: '+63 ',
                hintText: '9123456789',
              ),
              style: GoogleFonts.poppins(color: textdark),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter contact number';
                }
                if (value.length != 10) {
                  return 'Contact number must be exactly 10 digits (no leading 0)';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            _buildTextField(passwordController, 'Password', isPassword: true),
            const SizedBox(height: 20),
            _buildTextField(confirmPasswordController, 'Confirm Password', isPassword: true, isConfirm: true),

            const SizedBox(height: 20),
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

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primarycolor,
                  foregroundColor: Colors.white,
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: _isSaving ? null : _registerAdmin,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('Sign Up'),
              ),
            ),

            const SizedBox(height: 20),
            // ✅ Updated to use _navigateToMainUrl
            GestureDetector(
              onTap: _navigateToMainUrl,
              child: Text.rich(
                TextSpan(
                  text: "Already have an account? ",
                  style: GoogleFonts.poppins(color: textdark),
                  children: [
                    TextSpan(
                      text: 'Sign In',
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
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isPassword = false, bool isConfirm = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? (isConfirm ? _obscureConfirmPassword : _obscurePassword) : false,
      style: GoogleFonts.poppins(color: textdark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: textdark),
        border: const OutlineInputBorder(),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: primarycolor, width: 2)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  (isConfirm ? _obscureConfirmPassword : _obscurePassword) ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    if (isConfirm) {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    } else {
                      _obscurePassword = !_obscurePassword;
                    }
                  });
                },
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $label';

        // --- Email validation ---
        if (label == 'Email') {
          final trimmed = value.trim();
          if (!trimmed.contains('@') || !trimmed.endsWith('@pampangastateu.edu.ph')) {
            return 'Email must be in format @pampangastateu.edu.ph';
          }
          if (trimmed.startsWith('@')) {
            return 'Invalid email format';
          }
        }

        // --- Password validation ---
        if (label == 'Password' || label == 'Confirm Password') {
          final pwd = passwordController.text.trim();
          final confirmPwd = confirmPasswordController.text.trim();

          // Password strength check (only for Password field)
          if (label == 'Password') {
            bool hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
            bool hasLower = RegExp(r'[a-z]').hasMatch(pwd);
            bool hasDigit = RegExp(r'\d').hasMatch(pwd);
            bool minLength = pwd.length >= 8;

            if (!(hasUpper && hasLower && hasDigit && minLength)) {
              return 'Password must be at least 8 characters\nand include uppercase, lowercase, and number';
            }
          }

          // Password match check (for both fields)
          if (pwd.isNotEmpty && confirmPwd.isNotEmpty && pwd != confirmPwd) {
            return 'Passwords do not match';
          }

          // If password is incomplete, confirm password should show error too
          if (isConfirm && pwd.isNotEmpty) {
            bool hasUpper = RegExp(r'[A-Z]').hasMatch(pwd);
            bool hasLower = RegExp(r'[a-z]').hasMatch(pwd);
            bool hasDigit = RegExp(r'\d').hasMatch(pwd);
            bool minLength = pwd.length >= 8;

            if (!(hasUpper && hasLower && hasDigit && minLength)) {
              return 'Password is invalid';
            }
          }
        }

        return null;
      },
    );
  }

  Future<void> _registerAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      errorMessage = null;
    });

    try {
      final email = emailController.text.trim().toLowerCase();
      final password = passwordController.text.trim();

      // Check for existing email
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        setState(() {
          errorMessage = "Email is already registered.";
          _isSaving = false;
        });
        return;
      }

      // Compute staffID with SA prefix
      final adminSnapshot = await FirebaseFirestore.instance.collection('SuperAdmin').get();
      final staffID = 'SA${(adminSnapshot.docs.length + 1).toString().padLeft(3, '0')}';

      // ✅ Get encryption key (will load from Firestore or create new one)
      final key = await _getOrCreateAesKey();
      print('✅ Using encryption key for SuperAdmin registration');

      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      await user.sendEmailVerification();
      _startResendCooldown();

      final phoneToSave = '+63${contactController.text.trim()}';

      // ✅ Encrypt email/password before saving to Firestore
      final encryptedEmail = await _encryptValue(email);
      final encryptedPassword = await _encryptValue(password);

      print('✅ Encrypted SuperAdmin email and password');

      await FirebaseFirestore.instance.collection('SuperAdmin').doc(user.uid).set({
        'staffID': staffID,
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': encryptedEmail,
        'password': encryptedPassword,
        'phone': phoneToSave,
        'status': 'unverified',
        'accountType': 'SuperAdmin',
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
        'isOnline': false,
      });

      print('✅ SuperAdmin data saved to Firestore');

      // ✅ Store encrypted credentials locally for auto-login
      await _secureStorage.write(
        key: 'superadmin_email_local',
        value: encryptedEmail,
        aOptions: const AndroidOptions(encryptedSharedPreferences: true),
        iOptions: const IOSOptions(),
      );
      await _secureStorage.write(
        key: 'superadmin_password_local',
        value: encryptedPassword,
        aOptions: const AndroidOptions(encryptedSharedPreferences: true),
        iOptions: const IOSOptions(),
      );

      print('✅ SuperAdmin credentials cached locally');

      await _showEmailVerificationDialog(user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? "Registration failed. Please try again.";
      });
    } catch (e) {
      print('❌ SuperAdmin registration error: $e');
      setState(() {
        errorMessage = "Unexpected error: $e";
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _showEmailVerificationDialog(User createdUser) async {
    if (_isCheckingVerification) return;
    _isCheckingVerification = true;

    const pollInterval = Duration(seconds: 3);

    _verificationTimer = Timer.periodic(pollInterval, (timer) async {
      await createdUser.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        timer.cancel();
        if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
      }
    });

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        int countdown = 60;
        bool canResendLocal = false;
        bool hasStarted = false;
        Timer? countdownTimer;

        return StatefulBuilder(
          builder: (context, setState) {
            void startCountdown() {
              countdownTimer?.cancel();
              countdown = 60;
              canResendLocal = false;
              setState(() {});
              countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (!context.mounted) {
                  timer.cancel();
                  return;
                }
                if (countdown > 1) {
                  countdown--;
                  setState(() {});
                } else {
                  timer.cancel();
                  countdown = 0;
                  canResendLocal = true;
                  setState(() {});
                }
              });
            }

            if (!hasStarted) {
              hasStarted = true;
              startCountdown();
            }

            return WillPopScope(
              onWillPop: () async {
                countdownTimer?.cancel();
                return true;
              },
              child: AlertDialog(
                backgroundColor: lightBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 25),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 550),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email_outlined, size: 70, color: primarycolor),
                      const SizedBox(height: 12),
                      Text(
                        'Verify Your Email',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: primarycolordark,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                          children: [
                            const TextSpan(text: 'A verification link has been sent to '),
                            TextSpan(
                              text: createdUser.email ?? '',
                              style: GoogleFonts.poppins(color: primarycolordark, fontWeight: FontWeight.w600),
                            ),
                            const TextSpan(text: '. Please check your inbox or spam folder.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      const CircularProgressIndicator(color: primarycolor, strokeWidth: 3),
                      const SizedBox(height: 10),
                      Text('Waiting for verification...',
                          style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54), textAlign: TextAlign.center),
                      const SizedBox(height: 25),
                      if (!canResendLocal)
                        Text(
                          "Didn't receive the email? You can resend in $countdown seconds",
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        )
                      else
                        GestureDetector(
                          onTap: () async {
                            try {
                              final currentUser = FirebaseAuth.instance.currentUser;
                              if (currentUser != null && !currentUser.emailVerified) {
                                await currentUser.sendEmailVerification();
                                _showFloatingSnackBar('Verification email resent!', color: primarycolor);
                                startCountdown();
                              }
                            } on FirebaseAuthException catch (e) {
                              if (e.code == 'too-many-requests') {
                                _showFloatingSnackBar(
                                  'Too many resend attempts. Please wait before trying again.',
                                  color: Colors.red,
                                );
                              } else {
                                _showFloatingSnackBar('Failed to resend: ${e.message}', color: Colors.red);
                              }
                            } catch (e) {
                              _showFloatingSnackBar('Unexpected error: $e', color: Colors.red);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              "Didn't receive the email? Tap here to resend.",
                              style: GoogleFonts.poppins(color: primarycolordark, fontSize: 14, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    _verificationTimer?.cancel();
    _isCheckingVerification = false;

    if (result == true) {
      // ✅ Successful verification
      await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .doc(createdUser.uid)
          .update({'emailVerified': true, 'status': 'active'});

      _showFloatingSnackBar(
        'Email verified! Your Super Admin account is now active.',
        color: secondarycolor,
      );
      await FirebaseAuth.instance.signOut();
      
      if (mounted) {
        _navigateToMainUrl(); // ✅ Navigate to main URL
      }
    } else {
      // ✅ Cancelled or closed dialog
      await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .doc(createdUser.uid)
          .delete();
          
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.uid == createdUser.uid) {
          await user.delete();
        }
      } catch (e) {
        print('Failed to delete Firebase Auth user: $e');
      }
      
      _showFloatingSnackBar('Registration cancelled.', color: Colors.red);
      
      if (mounted) {
        _navigateToMainUrl(); // ✅ Navigate to main URL
      }
    }
  }
}