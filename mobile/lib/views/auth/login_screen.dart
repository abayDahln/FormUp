import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'home_screen.dart'; // Jangan lupa import halaman home

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controller untuk mengambil data yang diketik di input username
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

          // 2. LINGKARAN / ELLIPSE
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

          // 3. KONTEN UTAMA LOGIN
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Login",
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
                        "Don't have an account? ",
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "sign up",
                          style: TextStyle(
                            color: Color(0xFF2A9D8F),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Input Username (Dipasang controller)
                  _buildInputField("Username", Icons.person_outline, _usernameController),
                  const SizedBox(height: 20),

                  // Input Password (Dipasang controller)
                  _buildInputField("Password", Icons.lock_outline, _passwordController, obscure: true),
                  const SizedBox(height: 30),

                  // Tombol Login (Dipasang navigasi ke HomeScreen)
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Ambil teks dari input username, kalau kosong default-nya 'User'
                        String inputName = _usernameController.text.trim();
                        if (inputName.isEmpty) {
                          inputName = "Ray"; // atau nama default sesuai keinginanmu
                        }

                        // Pindah ke HomeScreen dan kirim nama usernamenya
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreen(username: inputName),
                          ),
                        );
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
                        "Login",
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

  Widget _buildInputField(String hint, IconData icon, TextEditingController controller, {bool obscure = false}) {
    return TextField(
      controller: controller, // Hubungkan controller ke TextField
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