import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFE2F3F2),
      body: Stack(
        children: [
          // 1. Background utama
          Container(
            width: size.width,
            height: size.height,
            color: const Color(0xFFE2F3F2),
          ),

          // 2. LINGKARAN / ELLIPSE (Sama persis dengan Login)
          Positioned(
            top: -150,
            left: -130,
            child: Container(
              width: size.width * 1.2,
              height: size.width * 1.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF018081).withOpacity(0.4),
                    const Color(0xFFD9D9D9).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // 3. KONTEN UTAMA REGISTER
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Register",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Text(
                        "Already have an account? ",
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Kembali ke halaman Login
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "sign in",
                          style: TextStyle(
                            color: Color(0xFF2A9D8F),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Input Email
                  _buildInputField("Email", Icons.email_outlined),
                  const SizedBox(height: 15),

                  // Input Username
                  _buildInputField("Username", Icons.person_outline),
                  const SizedBox(height: 15),

                  // Input Password
                  _buildInputField("Password", Icons.lock_outline, obscure: true),
                  const SizedBox(height: 25),

                  // Tombol Sign up (Dipasang Navigator.pop supaya balik ke Login pas diklik)
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Aksi setelah daftar berhasil / langsung kembali ke halaman login
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A9D8F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 3,
                      ),
                      icon: const Text(
                        "Sign up",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      label: const Icon(Icons.arrow_forward_rounded, size: 18),
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

  Widget _buildInputField(String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.white),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFF2A9D8F), width: 2),
        ),
      ),
    );
  }
}