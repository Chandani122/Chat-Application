import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  String _email = '';
  String _username = '';
  String _password = '';
  bool _isLoading = false;

  Future<void> _signup() async {
    final form = _formKey.currentState;
    if (form != null && form.validate()) {
      form.save();

      setState(() => _isLoading = true);

      try {
        await _authService.signUp(
          email: _email,
          username: _username,
          password: _password,
        );
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/contacts');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("SIGNUP",
                style: GoogleFonts.dmSans(
                    color: Colors.black,
                    fontSize: 32,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 30),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: GoogleFonts.dmSans(
                          fontSize: 22, fontWeight: FontWeight.w300),
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        size: 30,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onSaved: (value) => _email = value!,
                    validator: (value) =>
                        !value!.contains('@') ? 'Invalid email' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: GoogleFonts.dmSans(
                            fontSize: 22, fontWeight: FontWeight.w300),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 30,
                        )),
                    onSaved: (value) => _username = value!,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter username' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: GoogleFonts.dmSans(
                            fontSize: 22, fontWeight: FontWeight.w300),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 30,
                        )),
                    obscureText: true,
                    onSaved: (value) => _password = value!,
                    validator: (value) =>
                        value!.length < 6 ? 'Password too short' : null,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.transparent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            side: const BorderSide(color: Colors.black),
                            borderRadius: BorderRadius.circular(25))),
                    onPressed: _isLoading ? null : _signup,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Sign up',
                              style: GoogleFonts.dmSans(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 22),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: Text('Already an user? Login',
                        style: GoogleFonts.dmSans(
                            color: Colors.black, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
