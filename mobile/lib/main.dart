import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth_service.dart';
import 'views/auth/home_screen.dart';
import 'views/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ponytail: isOptional agar app tetap jalan saat .env tidak ada (fresh clone)
  await dotenv.load(fileName: '.env', isOptional: true);
  // Restore sesi agar user tidak login ulang tiap buka app (JWT berlaku 7 hari).
  final session = await AuthService.restoreSession();
  runApp(MyApp(initialUser: session));
}

class MyApp extends StatelessWidget {
  final AuthResult? initialUser;

  const MyApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    final displayName = initialUser != null && initialUser!.fullname.isNotEmpty
        ? initialUser!.fullname
        : initialUser?.username;
    return MaterialApp(
      title: 'Form Up',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2A9D8F)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: initialUser == null
          ? const LoginScreen()
          : HomeScreen(username: displayName ?? ''),
    );
  }
}
