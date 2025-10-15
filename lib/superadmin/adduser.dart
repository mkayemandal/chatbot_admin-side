import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatbot/superadmin/adminmanagement.dart';
import 'package:chatbot/superadmin/profile.dart';

const primarycolor = Color(0xFFffc803);
const primarycolordark = Color(0xFF550100);
const secondarycolor = Color(0xFF800000);
const dark = Color(0xFF17110d);
const textdark = Color(0xFF343a40);
const lightBackground = Color(0xFFFEFEFE);

String capitalizeEachWord(String text) {
  return text
      .toLowerCase()
      .split(' ')
      .map(
        (word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '',
      )
      .join(' ');
}

class ProfileButton extends StatefulWidget {
  final String imageUrl;
  final String name;
  final String role;
  final VoidCallback onTap;

  const ProfileButton({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.role,
    required this.onTap,
  });

  @override
  State<ProfileButton> createState() => _ProfileButtonState();
}

class _ProfileButtonState extends State<ProfileButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          height: 46,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isHovered
                ? Colors.grey.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: widget.imageUrl.startsWith('http')
                    ? NetworkImage(widget.imageUrl)
                    : AssetImage(widget.imageUrl) as ImageProvider,
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: dark,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Text(
                    widget.role,
                    style: const TextStyle(
                      fontSize: 12,
                      color: dark,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool sendNotification = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hoverAdd = false;
  bool _isSaving = false;

  String firstName = '';
  String lastName = '';
  String profilePictureUrl = "assets/images/defaultDP.jpg";
  String phoneNumber = '';

  bool _adminInfoLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
  }

  Future<int> _getNextStaffID() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('Admin')
        .orderBy('staffIDNumber', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return 1;

    final lastId = snapshot.docs.first.data()['staffIDNumber'];
    return (lastId is int) ? lastId + 1 : 1;
  }

  Future<void> _loadAdminInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('SuperAdmin')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          setState(() {
            firstName = capitalizeEachWord(doc['firstName'] ?? '');
            lastName = capitalizeEachWord(doc['lastName'] ?? '');
            // The following line fetches and updates the profilePictureUrl if it exists
            profilePictureUrl =
                doc['profilePicture'] ?? "assets/images/defaultDP.jpg";
            _adminInfoLoaded = true;
          });
        } else {
          setState(() => _adminInfoLoaded = true);
        }
      } else {
        setState(() => _adminInfoLoaded = true);
      }
    } catch (e) {
      print('Error loading admin info: $e');
      setState(() => _adminInfoLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullName = '$firstName $lastName';

    // Loader screen covers everything until admin info is loaded
    if (!_adminInfoLoaded) {
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

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Poppins'),
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: primarycolor,
          secondary: secondarycolor,
          onPrimary: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: lightBackground,
        appBar: AppBar(
          backgroundColor: lightBackground,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: primarycolordark),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Add Admin",
            style: TextStyle(
              color: primarycolordark,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ProfileButton(
                imageUrl: profilePictureUrl,
                name: fullName.trim().isNotEmpty ? fullName : "Loading...",
                role: "Super Admin",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminProfilePage()),
                  );
                },
              ),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add a new admin",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primarycolordark,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: "First Name",
                            controller: firstNameController,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            label: "Last Name",
                            controller: lastNameController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      label: "Username",
                      controller: usernameController,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      label: "Email Address",
                      controller: emailController,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please enter Email Address';
                        final emailRegex = RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        );
                        if (!emailRegex.hasMatch(value))
                          return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    IntlPhoneField(
                      controller: contactController,
                      initialCountryCode: 'PH',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: dark,
                        fontWeight: FontWeight.w500,
                      ),
                      dropdownTextStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        color: dark,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Contact',
                        hintText: '9123456789',
                        filled: true,
                        fillColor: Colors.white,
                        labelStyle: const TextStyle(
                          color: dark,
                          fontWeight: FontWeight.w500,
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: primarycolordark,
                          fontWeight: FontWeight.bold,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: secondarycolor,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: primarycolordark,
                            width: 1.6,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.6,
                          ),
                        ),
                        errorStyle: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      invalidNumberMessage: 'Invalid Mobile Number',
                      onChanged: (phone) {
                        phoneNumber = phone.completeNumber;
                      },
                      validator: (phone) {
                        if (phone == null || phone.number.length < 10) {
                          return 'Please enter a valid mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildPasswordField(
                      label: "Password",
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      onToggle: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildPasswordField(
                      label: "Confirm Password",
                      controller: confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      onToggle: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        );
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Please confirm your password';
                        if (value != passwordController.text)
                          return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            disabledColor:
                                primarycolor, // Checkbox border and fill when disabled
                            unselectedWidgetColor: primarycolor,
                          ),
                          child: const Checkbox(
                            value: true,
                            onChanged: null, // read-only
                            checkColor: dark, // color of the checkmark
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            "Send a notification to the user for this new role.",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: primarycolordark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    MouseRegion(
                      onEnter: (_) => setState(() => _hoverAdd = true),
                      onExit: (_) => setState(() => _hoverAdd = false),
                      cursor: SystemMouseCursors.click,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _hoverAdd ? secondarycolor : primarycolordark,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _hoverAdd
                              ? [
                                  BoxShadow(
                                    color: primarycolordark.withOpacity(0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                              : [],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              try {
                                final fullName =
                                    "${firstNameController.text.trim()} ${lastNameController.text.trim()}";
                                final email = emailController.text.trim();
                                final password = passwordController.text.trim();

                                setState(() => _isSaving = true);

                                // Check if email already in use
                                final methods = await FirebaseAuth.instance
                                    .fetchSignInMethodsForEmail(email);
                                if (methods.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Email already in use.",
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ),
                                  );
                                  setState(() => _isSaving = false);
                                  return;
                                }

                                // Create user
                                UserCredential userCredential =
                                    await FirebaseAuth.instance
                                        .createUserWithEmailAndPassword(
                                          email: email,
                                          password: password,
                                        );

                                // Send verification email
                                await userCredential.user!
                                    .sendEmailVerification();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Verification email sent. Please make sure the new admin verifies their email before logging in.",
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                      ),
                                    ),
                                    duration: const Duration(seconds: 4),
                                    backgroundColor: primarycolor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );

                                // Register admin in Firestore
                                final uid = userCredential.user!.uid;
                                final nextStaffId = await _getNextStaffID();

                                await FirebaseFirestore.instance
                                    .collection('Admin')
                                    .doc(uid)
                                    .set({
                                      'name': fullName,
                                      'firstName': firstNameController.text
                                          .trim(),
                                      'lastName': lastNameController.text
                                          .trim(),
                                      'username': usernameController.text
                                          .trim(),
                                      'email': email,
                                      'phone': contactController.text.trim(),
                                      'accountType': "Admin",
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'staffIDNumber': nextStaffId,
                                      'staffID':
                                          "STAFF-${nextStaffId.toString().padLeft(3, '0')}",
                                      'isOnline': false,
                                      'status': 'inactive',
                                    });

                                // Proceed to AdminManagementPage
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminManagementPage(),
                                  ),
                                );
                              } on FirebaseAuthException catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Auth Error: ${e.message}"),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Unexpected error: $e"),
                                  ),
                                );
                              } finally {
                                setState(() => _isSaving = false);
                              }
                            }
                          },
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Add New Admin',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    String? hint,
    required TextEditingController controller,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(
        fontFamily: 'Poppins',
        color: dark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: dark, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(
          color: primarycolordark,
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondarycolor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primarycolordark, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),
        errorStyle: const TextStyle(
          fontSize: 12,
          fontFamily: 'Poppins',
          color: Colors.redAccent,
          fontWeight: FontWeight.w500,
        ),
      ),
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter $label';
            }
            if (label == 'Username' && value.contains(' ')) {
              return 'Username should not contain spaces';
            }
            return null;
          },
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(
        fontFamily: 'Poppins',
        color: dark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        labelStyle: const TextStyle(color: dark, fontWeight: FontWeight.w500),
        floatingLabelStyle: const TextStyle(
          color: primarycolordark,
          fontWeight: FontWeight.bold,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondarycolor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primarycolordark, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.6),
        ),
        errorStyle: const TextStyle(
          fontSize: 12,
          fontFamily: 'Poppins',
          color: Colors.redAccent,
          fontWeight: FontWeight.w500,
        ),
      ),
      validator:
          validator ??
          (value) =>
              value == null || value.isEmpty ? 'Please enter $label' : null,
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    contactController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
