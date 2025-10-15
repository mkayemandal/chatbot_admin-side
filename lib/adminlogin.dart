import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatbot/superadmin/dashboard.dart';
import 'package:chatbot/admin/dashboard.dart';
import 'package:chatbot/adminregister.dart';

const primarycolor = Color(0xFF800000);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFFffc803);
const dark = Color(0xFF17110d);
const textdark = Color(0xFF343a40);
const textlight = Color(0xFFFFFFFF);
const lightBackground = Color(0xFFFEFEFE);

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
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

  @override
  void initState() {
    super.initState();
    _loadSystemSettings();
  }

  Future<void> _loadSystemSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('SystemSettings')
          .doc('global')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          appName = data['siteName'] ?? "DHVBot MANAGEMENT SYSTEM";
          tagline =
              data['tagline'] ?? "Efficiently manage your DHVBot operations";
          description =
              data['description'] ??
              "Efficiently manage DHVBot records, users, and services through a centralized and user-friendly system.";
          logoPath =
              data['universityLogoUrl'] ?? 'assets/images/DHVSU-LOGO.png';
          backgroundImageUrl = data['backgroundImageUrl'];
          isSettingsLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading system settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show full-screen loading animation until settings are loaded
    if (!isSettingsLoaded) {
      return Scaffold(
        backgroundColor: lightBackground,
        body: Center(
          child: Lottie.asset(
            'assets/animations/Live chatbot.json',
            // 'assets/animations/Loading Dots Blue.json',
            // 'assets/animations/Loading Lottie animation.json',
            // 'assets/animations/Loading Spinner (Dots).json',
            width: 200,
            height: 200,
          ),
        ),
      );
    }

    // When settings are ready, show the actual login page
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
      // Use network image if uploaded, else fallback to AssetImage
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
        mainAxisAlignment: isMobile
            ? MainAxisAlignment.start
            : MainAxisAlignment.spaceBetween,
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
                            logoPath != null && logoPath!.startsWith('http')
                                ? Image.network(
                                    logoPath!,
                                    height: 100,
                                    errorBuilder: (_, _, _) => Image.asset(
                                      'assets/images/DHVSU-LOGO.png',
                                      height: 100,
                                    ),
                                  )
                                : Image.asset(
                                    logoPath ?? 'assets/images/DHVSU-LOGO.png',
                                    height: 100,
                                  ),
                            const SizedBox(height: 20),
                            Text(
                              appName ?? "",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              tagline ?? "",
                              style: const TextStyle(
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
                logoPath != null && logoPath!.startsWith('http')
                    ? Image.network(
                        logoPath!,
                        height: 100,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/images/DHVSU-LOGO.png',
                          height: 100,
                        ),
                      )
                    : Image.asset(
                        logoPath ?? 'assets/images/DHVSU-LOGO.png',
                        height: 100,
                      ),
                const SizedBox(height: 20),
                Text(
                  appName ?? "",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  tagline ?? "",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
              ],
            ),
          if (isSettingsLoaded)
            Text(
              description ?? "",
              style: const TextStyle(color: Colors.white54, fontSize: 12),
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
        mainAxisAlignment: isMobile
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Welcome back!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primarycolordark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your email and password to sign in.',
            style: TextStyle(fontSize: 14, color: textdark),
          ),
          const SizedBox(height: 30),
          TextField(
            controller: _emailController,
            style: const TextStyle(color: textdark),
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              labelStyle: const TextStyle(color: textdark),
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: primarycolor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: textdark),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              labelStyle: const TextStyle(color: textdark),
              border: const OutlineInputBorder(),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: primarycolor, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: textdark,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
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
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 15),
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
                      textStyle: const TextStyle(
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
          // GestureDetector(
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => const AdminRegisterPage()),
          //     );
          //   },
          //   child: Text.rich(
          //     TextSpan(
          //       text: "Doesn’t have an account? ",
          //       style: TextStyle(color: textdark),
          //       children: [
          //         TextSpan(
          //           text: 'Create an account',
          //           style: TextStyle(
          //             color: primarycolordark,
          //             decoration: TextDecoration.underline,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        errorMessage = "Please enter both email and password.";
      });
      return;
    }

    setState(() {
      errorMessage = null;
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user!;
      final uid = user.uid;

      // SUPER ADMIN CHECK
      final superAdminDoc = await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .doc(uid)
          .get();

      if (superAdminDoc.exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuperAdminDashboardPage()),
        );
        return;
      }

      // ADMIN CHECK
      final adminDoc = await FirebaseFirestore.instance
          .collection('Admin')
          .doc(uid)
          .get();

      if (!adminDoc.exists) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          errorMessage = "Access denied. You are not authorized.";
        });
        return;
      }

      // Check if email is verified
      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          errorMessage = "Please verify your email address before logging in.";
        });
        return;
      }

      // If verified but status is inactive, update it to active
      final adminData = adminDoc.data()!;
      final status = (adminData['status'] ?? 'inactive')
          .toString()
          .toLowerCase();

      if (status != 'active') {
        await FirebaseFirestore.instance.collection('Admin').doc(uid).update({
          'status': 'active',
        });
      }

      // Proceed to admin dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message ?? "Login failed. Please try again.";
      });
    } catch (e) {
      setState(() {
        errorMessage = "An unexpected error occurred. Please try again.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}