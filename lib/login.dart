import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sakumlapa.dart'; // Contains HomePage definition

// Custom clipper for a curved header.
class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 15);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 15,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers for user input.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  // Separate error messages for each field.
  String _emailError = '';
  String _passwordError = '';

  // Validate fields locally before attempting Firebase login.
  bool _validateFields() {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    // Clear previous errors.
    setState(() {
      _emailError = '';
      _passwordError = '';
    });

    bool valid = true;

    if (email.isEmpty) {
      setState(() {
        _emailError = 'Lūdzu, ievadiet e-pastu.';
      });
      valid = false;
    } else {
      // Basic email regex check.
      final RegExp emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(email)) {
        setState(() {
          _emailError = 'Lūdzu, ievadiet derīgu e-pasta adresi.';
        });
        valid = false;
      }
    }
    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Lūdzu, ievadiet paroli.';
      });
      valid = false;
    }
    return valid;
  }

  // Fire base pieslēgšanās funkcija.
  Future<void> _login() async {
    if (!_validateFields()) return;

    setState(() {
      _isLoading = true;
      // Clear any previous errors.
      _emailError = '';
      _passwordError = '';
    });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      final String uid = userCredential.user!.uid;

      // Fetch the user's document from Firestore.
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      // Check if the account is frozen.
      if (userDoc.exists && userDoc.get('accountFrozen') == true) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _emailError =
              'Šis konts ir atslēgts. Lūdzu, sazinieties ar administratoru.';
        });
        return;
      }

      // Fetch the user's role from Firestore.
      String role = 'normal';
      if (userDoc.exists && userDoc.get('role') != null) {
        role = userDoc.get('role');
      }

      // Navigate to HomePage, passing the user role.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage(userRole: role)),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        setState(() {
          _emailError = 'Konts ar šo e-pastu nav reģistrēts.';
        });
      } else if (e.code == 'wrong-password') {
        setState(() {
          _passwordError = 'Nepareiza parole. Lūdzu, mēģiniet vēlreiz.';
        });
      } else if (e.code == 'invalid-email') {
        setState(() {
          _emailError = 'Ievadītais e-pasts nav derīgs.';
        });
      } else if (e.code == 'user-disabled') {
        setState(() {
          _emailError = 'Šis konts ir atspējots.';
        });
      } else if (e.code == 'too-many-requests') {
        setState(() {
          _emailError = 'Pārāk daudz mēģinājumu. Lūdzu, mēģiniet vēlāk.';
        });
      } else if (e.code == 'invalid-credential') {
        setState(() {
          _emailError = 'E-pasts vai parole ir nepareiza!';
        });
      } else {
        setState(() {
          _emailError =
              'Pieslēgšanās neizdevās. Lūdzu, pārbaudiet savus akreditācijas datus.';
        });
      }
    } catch (e) {
      setState(() {
        _emailError = 'Radās kļūda. Lūdzu, mēģiniet vēlreiz.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 192, 192, 192),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Custom header with curved bottom.
            ClipPath(
              clipper: BottomCurveClipper(),
              child: Container(
                width: double.infinity,
                height: screenWidth * 0.4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF24562B), Color(0xFF1C4F21)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Darba Stundu Uzskaitītājs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.07,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Login form in a Card.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 10,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Email field with errorText.
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText:
                              _emailError.isNotEmpty ? _emailError : null,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      // Password field with errorText.
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Parole',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorText:
                              _passwordError.isNotEmpty ? _passwordError : null,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 80,
                                vertical: 15,
                              ),
                              backgroundColor: const Color(0xFF24562B),
                            ),
                            child: const Text(
                              'Pieslēgties',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
