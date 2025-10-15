import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chatbot/superadmin/dashboard.dart';

class AdminRegisterPage extends StatefulWidget {
  const AdminRegisterPage({super.key});

  @override
  State<AdminRegisterPage> createState() => _AdminRegisterPageState();
}

class _AdminRegisterPageState extends State<AdminRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController birthdayController = TextEditingController();

  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Super Admin Registration")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(label: "Email", controller: emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildTextField(label: "First Name", controller: firstNameController),
              const SizedBox(height: 12),
              _buildTextField(label: "Last Name", controller: lastNameController),
              const SizedBox(height: 12),
              _buildTextField(label: "Username", controller: usernameController),
              const SizedBox(height: 12),
              _buildTextField(label: "Contact Number", controller: contactController, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildTextField(label: "Birthday", controller: birthdayController, keyboardType: TextInputType.datetime),
              const SizedBox(height: 12),
              _buildTextField(
                label: "Password",
                controller: passwordController,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                label: "Confirm Password",
                controller: confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _registerSuperAdmin,
                child: const Text("Register Super Admin"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: suffixIcon,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        if (label == "Email" && !value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Future<void> _registerSuperAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Check if email already exists
      final existing = await FirebaseFirestore.instance
          .collection('SuperAdmin')
          .where('email', isEqualTo: emailController.text.trim())
          .get();
      if (existing.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email already registered")),
        );
        setState(() => _isSaving = false);
        return;
      }

      // Get current count to generate staffID
      final adminSnapshot = await FirebaseFirestore.instance.collection('SuperAdmin').get();
      final staffID = 'ADM${(adminSnapshot.docs.length + 1).toString().padLeft(3, '0')}';

      // Create account in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user!;
      final uid = user.uid;
      final fullName = "${firstNameController.text.trim()} ${lastNameController.text.trim()}";

      // Save user details in Firestore under 'SuperAdmin'
      await FirebaseFirestore.instance.collection('SuperAdmin').doc(uid).set({
        'staffID': staffID,
        'name': fullName,
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'username': usernameController.text.trim(),
        'email': emailController.text.trim().toLowerCase(),
        'phone': contactController.text.trim(),
        'birthday': birthdayController.text.trim(),
        'accountType': 'Super Admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Super Admin registered successfully')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SuperAdminDashboardPage()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Unexpected error: $e")));
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
