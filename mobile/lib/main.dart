import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/gemini_service.dart';
import 'package:form_up/core/services/network_status.dart';
import 'package:form_up/core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  await GeminiService.init();
  NetworkStatus.configure(apiBaseUrl);
  await NetworkStatus.refresh();
  NetworkStatus.startMonitoring();
  
  bool isLoggedIn = false;
  AuthResult? session;
  
  try {
    session = await AuthService.restoreSession();
    if (session != null) {
      isLoggedIn = await AuthService.verifyToken();
      if (!isLoggedIn) {
        await AuthService.logout();
        session = null;
      }
    }
  } catch (e) {
    debugPrint('[Auth] restoreSession gagal: $e');
  }

  final initialPage = isLoggedIn
      ? (AuthService.role == 'ADMIN' ? AppPage.adminPanel : AppPage.home)
      : AppPage.login;

  debugPrint('[Auth] isLoggedIn=$isLoggedIn, initialPage=$initialPage');

  final delegate = AppRouterDelegate(initial: initialPage);
  
  if (isLoggedIn && session != null) {
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
    // 🔧 FIX: AppRouter wrapper HARUS tetap ada
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