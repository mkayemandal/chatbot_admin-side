import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/successforgotpass.dart';

const primarycolor = Color(0xFF800000);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFFffc803);
const dark = Color(0xFF17110d);
const textdark = Color(0xFF343a40);
const textlight = Color(0xFFFFFFFF);
const lightBackground = Color(0xFFFEFEFE);

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? message;

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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
        // Ensure UI proceeds even if no settings doc exists
        if (!mounted) return;
        setState(() {
          isSettingsLoaded = true;
        });
      }
    } catch (e) {
      // Fallback so UI doesn't hang
      if (!mounted) return;
      setState(() {
        isSettingsLoaded = true;
      });
      // Optionally log the error
      // print('Error loading system settings: $e');
    }
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    // Check if empty
    if (email.isEmpty) {
      setState(() => message = "Please enter your email address.");
      return;
    }

    // Allow only Pampanga State University or Gmail addresses
    final RegExp allowedEmailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@(pampangastateu\.edu\.ph|gmail\.com)$',
    );

    if (!allowedEmailRegex.hasMatch(email)) {
      setState(() => message =
          "Please enter a valid Pampanga State University or Gmail address.");
      return;
    }

    setState(() {
      message = null;
      _isLoading = true;
    });

    try {
      // Check if email exists in Admin or SuperAdmin collections
      final adminQuery = await FirebaseFirestore.instance
          .collection('Admin')
          .where('email', isEqualTo: email)
          .get();

      final superAdminQuery = await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .where('email', isEqualTo: email)
          .get();

      if (adminQuery.docs.isEmpty && superAdminQuery.docs.isEmpty) {
        setState(() {
          message = "No account found with this email.";
          _isLoading = false;
        });
        return;
      }

      // If found, send reset email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SuccessForgotPassPage(email: email),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => message = e.message ?? "Failed to send reset email.");
    } catch (e) {
      setState(() => message = "An error occurred. Please try again later.");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isSettingsLoaded) {
      return const Scaffold(
        backgroundColor: lightBackground,
        body: Center(child: CircularProgressIndicator()),
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
                      _buildRightPanel(isMobile: true),
                    ],
                  ),
                )
              : Row(
                  children: [
                    Expanded(child: _buildLeftPanel()),
                    Expanded(child: _buildRightPanel()),
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
                            logoPath != null && logoPath!.startsWith('http')
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
                logoPath != null && logoPath!.startsWith('http')
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

  Widget _buildRightPanel({bool isMobile = false}) {
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
          // ColorFiltered(
          //   colorFilter: const ColorFilter.matrix([
          //     0.2126, 0.7152, 0.0722, 0, 0,
          //     0.2126, 0.7152, 0.0722, 0, 0,
          //     0.2126, 0.7152, 0.0722, 0, 0,
          //     0, 0, 0, 1, 0,
          //   ]),
          //   child: Image.asset(
          //     'assets/images/pass_reset.png',
          //     width: 150,
          //     height: 150,
          //     fit: BoxFit.contain,
          //   ),
          // ),
          // Container(
          //   width: 140,
          //   height: 140,
          //   decoration: BoxDecoration(
          //     color: const Color.fromARGB(255, 255, 230, 230), 
          //     shape: BoxShape.circle,
          //   ),
          //   child: const Center(
          //     child: Icon(
          //       Icons.password_outlined,
          //       size: 70,
          //       color: primarycolordark,
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 20),
          Text(
            'Forgot Password',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primarycolordark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enter your email so we can send a password reset link.',
            style: GoogleFonts.poppins(fontSize: 14, color: textdark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          TextField(
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
          ),
          const SizedBox(height: 20),
          if (message != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              width: double.infinity,
              color: message!.contains("sent")
                  ? Colors.green[100]
                  : Colors.red[100],
              child: Text(
                message!,
                style: GoogleFonts.poppins(
                  color: message!.contains("sent")
                      ? Colors.green[700]!
                      : Colors.red,
                ),
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
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
                textStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
              onPressed: _isLoading ? null : _sendResetEmail,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Send Email'),
            ),
          ),
          const SizedBox(height: 25),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: primarycolordark,
              textStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginPage()),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_ios,
                  size: 18,
                  color: primarycolordark,
                ),
                const SizedBox(width: 6),
                Text(
                  "Back to Login",
                  style: GoogleFonts.poppins(
                    color: primarycolordark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}