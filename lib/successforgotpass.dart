import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/forgotpassword.dart';
import 'package:url_launcher/url_launcher.dart';

const primarycolor = Color(0xFF800000);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFFffc803);
const dark = Color(0xFF17110d);
const textdark = Color(0xFF343a40);
const textlight = Color(0xFFFFFFFF);
const lightBackground = Color(0xFFFEFEFE);

class SuccessForgotPassPage extends StatefulWidget {
  final String email;

  const SuccessForgotPassPage({super.key, required this.email});

  @override
  State<SuccessForgotPassPage> createState() => _SuccessForgotPassPageState();
}

class _SuccessForgotPassPageState extends State<SuccessForgotPassPage> {
  String? appName;
  String? tagline;
  String? description;
  String? logoPath;
  String? backgroundImageUrl;
  bool isSettingsLoaded = false;
  bool _isHoveringTryEmail = false;

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
        if (!mounted) return;
        setState(() {
          appName = data['siteName'] ?? "AskPSU MANAGEMENT SYSTEM";
          tagline =
              data['tagline'] ?? "Efficiently manage your AskPSU operations";
          description = data['description'] ??
              "Efficiently manage AskPSU records, users, and services through a centralized and user-friendly system.";
          logoPath =
              data['universityLogoUrl'] ?? 'assets/images/DHVSU-LOGO.png';
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
      // optional: log error
    }
  }

  Future<void> _openEmailApp() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: widget.email,
    );
    if (!await launchUrl(emailLaunchUri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open email app")),
      );
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
                  // SingleChildScrollView + ConstrainedBox technique ensures:
                  // - main content is centered vertically if there's enough height
                  // - content still scrolls on short screens
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.vertical,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          _buildLeftPanel(isMobile: true),
                          // Right panel occupies remaining height; we use Expanded-like behavior
                          Expanded(
                            child: _buildRightPanel(isMobile: true),
                          ),
                        ],
                      ),
                    ),
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
    // Main content (centered horizontally & vertically)
    final mainContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ColorFiltered(
        //   colorFilter: const ColorFilter.matrix([
        //     0.2126, 0.7152, 0.0722, 0, 0, //
        //     0.2126, 0.7152, 0.0722, 0, 0, //
        //     0.2126, 0.7152, 0.0722, 0, 0, //
        //     0, 0, 0, 1, 0,
        //   ]),
        //   child: Image.asset(
        //     'assets/images/pass_reset.png',
        //     width: 150,
        //     height: 150,
        //     fit: BoxFit.contain,
        //   ),
        // ),
        // const SizedBox(height: 18),
        Text(
          'Check Your Email',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: primarycolordark,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'A password reset link has been sent to ',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: textdark,
                  ),
                ),
                TextSpan(
                  text: widget.email,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primarycolordark,
                  ),
                ),
                TextSpan(
                  text: '.\n Please check your inbox or spam folder.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: textdark,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: 230,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primarycolor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              textStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            onPressed: _openEmailApp,
            child: const Text('Open email inbox'),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminLoginPage()),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: primarycolordark,
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
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
        // small gap on mobile after Back to Login
        if (isMobile) const SizedBox(height: 12),
      ],
    );

    final didntReceiveBlock = Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 8.0 : 0.0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: "Didn’t receive an email? ",
              style: GoogleFonts.poppins(
                color: textdark,
                fontSize: 13,
              ),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHoveringTryEmail = true),
                onExit: (_) => setState(() => _isHoveringTryEmail = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                    );
                  },
                  child: Text(
                    "Try another email",
                    style: GoogleFonts.poppins(
                      color: _isHoveringTryEmail ? primarycolordark : primarycolordark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );

    // Container that ensures main content is centered vertically & horizontally,
    // and the 'didn't receive' block stays pinned to the bottom.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: 40),
      child: Column(
        children: [
          // Center the main content in the available space
          Expanded(
            child: Center(child: mainContent),
          ),
          // Bottom pinned 'didn't receive' block
          didntReceiveBlock,
        ],
      ),
    );
  }
}