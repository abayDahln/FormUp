import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ponytail: isOptional, jalan tanpa .env
  await dotenv.load(fileName: '.env', isOptional: true);
  // Restore sesi login
  final session = await AuthService.restoreSession();
  final isLoggedIn = session != null;

  final delegate = AppRouterDelegate(
    // Admin langsung masuk Admin Panel, user biasa ke Home
    initial: isLoggedIn
        ? (AuthService.role == 'ADMIN' ? AppPage.adminPanel : AppPage.home)
        : AppPage.login,
  );
  if (isLoggedIn) {
    final name = session.fullname.isNotEmpty ? session.fullname : session.username;
    delegate.setUsername(name);
  }

  AuthService.onSessionExpired = () => delegate.resetToLogin();

  runApp(MyApp(delegate: delegate));
}

class MyApp extends StatelessWidget {
  final AppRouterDelegate delegate;

  const MyApp({super.key, required this.delegate});

  @override
  Widget build(BuildContext context) {
    return AppRouter(
      delegate: delegate,
      child: MaterialApp.router(
        title: 'Form Up',
        debugShowCheckedModeBanner: false,
        theme: buildFormUpTheme(),
        routerDelegate: delegate,
        routeInformationParser: AppRouteParser(),
        localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      ),
    );
  }
}


