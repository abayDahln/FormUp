import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_router.dart';
import 'services/auth_service.dart';
import 'views/auth_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ponytail: isOptional agar app tetap jalan saat .env tidak ada (fresh clone)
  await dotenv.load(fileName: '.env', isOptional: true);
  // Restore sesi agar user tidak login ulang tiap buka app (JWT berlaku 7 hari).
  final session = await AuthService.restoreSession();
  final isLoggedIn = session != null;

  final delegate = AppRouterDelegate(
    initial: isLoggedIn ? AppPage.home : AppPage.login,
  );
  if (isLoggedIn) {
    final name = session.fullname.isNotEmpty ? session.fullname : session.username;
    delegate.setUsername(name);
  }

  runApp(MyApp(delegate: delegate));
}

class MyApp extends StatelessWidget {
  final AppRouterDelegate delegate;

  const MyApp({super.key, required this.delegate});

  @override
  Widget build(BuildContext context) {
    // AppRouter (inherited) membungkus MaterialApp agar semua screen bisa
    // mengakses RouterDelegate via AppRouter.of(context) (Navigation 3).
    return AppRouter(
      delegate: delegate,
      child: MaterialApp.router(
        title: 'Form Up',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
          useMaterial3: true,
          fontFamily: 'Inter',
        ),
        routerDelegate: delegate,
        routeInformationParser: AppRouteParser(),
      ),
    );
  }
}

