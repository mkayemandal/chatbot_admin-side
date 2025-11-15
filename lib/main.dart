import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;
import 'firebase_options.dart';
import 'package:chatbot/pagenotfound.dart';
import 'package:chatbot/adminlogin.dart';
import 'package:chatbot/superadregister.dart';
import 'package:chatbot/admin/dashboard.dart';
import 'package:chatbot/superadmin/dashboard.dart';

const primarycolor = Color(0xFF800000);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFFffc803);
const dark = Color(0xFF17110d);
const textdark = Color(0xFF343a40);
const textlight = Color(0xFFFFFFFF);
const lightBackground = Color(0xFFFEFEFE);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const LoadingApp());
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

    runApp(const ChatBotApp());
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }
}

class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: lightBackground,
        body: Center(
          child: Lottie.asset(
            'assets/animations/Live chatbot.json',
            width: 200,
            height: 200,
          ),
        ),
      ),
    );
  }
}

class ChatBotApp extends StatelessWidget {
  const ChatBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AskPSU Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primarycolor),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const URLChecker(),
    );
  }
}

/// URLChecker: Analyzes the current URL and decides which page to show
class URLChecker extends StatefulWidget {
  const URLChecker({super.key});

  @override
  State<URLChecker> createState() => _URLCheckerState();
}

class _URLCheckerState extends State<URLChecker> {
  Widget? _targetPage;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _analyzeURL();
  }

  void _analyzeURL() {
    // Get current browser URL using dart:html
    final currentUrl = html.window.location.href;
    final uri = Uri.parse(currentUrl);

    debugPrint('═══════════════════════════════════════');
    debugPrint('🔍 URL ANALYSIS');
    debugPrint('═══════════════════════════════════════');
    debugPrint('🌐 Full URL: $currentUrl');
    debugPrint('📍 Host: ${uri.host}');
    debugPrint('📂 Path: ${uri.path}');
    debugPrint('🔗 Fragment: ${uri.fragment}');
    debugPrint('❓ Query: ${uri.query}');
    debugPrint('📋 Query Params: ${uri.queryParameters}');
    debugPrint('═══════════════════════════════════════');

    String? accessKey;
    bool isCreateAccountRoute = false;

    // Method 1: Check if URL contains "createaccount" anywhere
    if (currentUrl.contains('createaccount')) {
      debugPrint('✅ Found "createaccount" in URL');
      isCreateAccountRoute = true;

      // Try to find key in multiple places
      
      // Check query parameters
      if (uri.queryParameters.containsKey('key')) {
        accessKey = uri.queryParameters['key'];
        debugPrint('✅ Found key in query params: $accessKey');
      }
      
      // Check fragment if it has query parameters
      if (accessKey == null && uri.fragment.contains('key=')) {
        final fragmentMatch = RegExp(r'key=([^&]*)').firstMatch(uri.fragment);
        if (fragmentMatch != null) {
          accessKey = fragmentMatch.group(1);
          debugPrint('✅ Found key in fragment: $accessKey');
        }
      }

      // Check if key is in the main query string
      if (accessKey == null && uri.query.contains('key=')) {
        final queryMatch = RegExp(r'key=([^&]*)').firstMatch(uri.query);
        if (queryMatch != null) {
          accessKey = queryMatch.group(1);
          debugPrint('✅ Found key in query string: $accessKey');
        }
      }
    }

    debugPrint('═══════════════════════════════════════');
    debugPrint('🎯 ROUTING DECISION');
    debugPrint('═══════════════════════════════════════');
    debugPrint('Is Create Account Route: $isCreateAccountRoute');
    debugPrint('Access Key: $accessKey');
    debugPrint('Valid Key (PSU-IT60-2025): ${accessKey == 'PSU-IT60-2025'}');
    debugPrint('═══════════════════════════════════════');

    setState(() {
      if (isCreateAccountRoute) {
        if (accessKey == 'PSU-IT60-2025') {
          debugPrint('✅ SHOWING: SuperAdminRegisterPage');
          _targetPage = const SuperAdminRegisterPage();
        } else {
          debugPrint('❌ SHOWING: PageNotFound (invalid/missing key)');
          _targetPage = const PageNotFound();
        }
      } else {
        debugPrint('✅ SHOWING: AuthGate (default)');
        _targetPage = const AuthGate();
      }
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
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

    return _targetPage ?? const AuthGate();
  }
}

/// AuthGate: Determines which dashboard to show based on Firebase Auth and Firestore role.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Stream<User?> _authStream;
  late StreamSubscription<html.StorageEvent> _storageSub;

  @override
  void initState() {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();

    // 👇 Listen for logout/login in other browser tabs
    _storageSub = html.window.onStorage.listen((event) {
      // Firebase stores user info in localStorage, and clears it on logout
      if (event.key != null &&
          event.key!.contains('firebase:authUser') &&
          event.newValue == null) {
        debugPrint('🚪 Detected logout from another tab');
        if (mounted) {
          // Automatically redirect to login page
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AdminLoginPage()),
            (_) => false,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _storageSub.cancel();
    super.dispose();
  }

  /// 🔹 Fetch user role from Firestore
  Future<String?> _getUserRole(String uid) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc = await firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('role')) {
        return userDoc['role'];
      }

      final superAdminDoc =
          await firestore.collection('SuperAdmin').doc(uid).get();
      if (superAdminDoc.exists) return 'superadmin';

      final adminDoc = await firestore.collection('Admin').doc(uid).get();
      if (adminDoc.exists) return 'admin';
    } catch (e) {
      debugPrint('⚠️ Error fetching user role: $e');
    }
    return null;
  }

  /// 🔹 Update real-time online/offline status
  Future<void> _updateLoginStatus(String uid, bool isOnline) async {
    final firestore = FirebaseFirestore.instance;
    try {
      final userDoc = await firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        await firestore.collection('users').doc(uid).update({'isOnline': isOnline});
      } else {
        await firestore.collection('Admin').doc(uid).update({'isOnline': isOnline}).catchError((_) {});
        await firestore.collection('SuperAdmin').doc(uid).update({'isOnline': isOnline}).catchError((_) {});
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update online status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
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

        final user = authSnapshot.data;

        // 🔒 If user is logged out, go to login page immediately
        if (user == null) {
          return const AdminLoginPage();
        }

        // ✅ Logged in user — update online status
        _updateLoginStatus(user.uid, true);
        html.window.onBeforeUnload.listen((_) {
          _updateLoginStatus(user.uid, false);
        });

        // 🔹 Determine user role
        return FutureBuilder<String?>(
          future: _getUserRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
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

            final role = roleSnapshot.data;

            if (role == 'superadmin') {
              return const SuperAdminDashboardPage();
            } else if (role == 'admin') {
              return const AdminDashboardPage();
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await FirebaseAuth.instance.signOut();
              });
              return const AdminLoginPage();
            }
          },
        );
      },
    );
  }
}
