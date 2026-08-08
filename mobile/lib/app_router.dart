import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'views/login_screen.dart';
import 'views/register_screen.dart';
import 'views/forgot_password_screen.dart';
import 'views/otp_screen.dart';
import 'views/reset_password_screen.dart';
import 'views/home_screen.dart';
import 'views/form_maker_screen.dart';
import 'views/form_runner_screen.dart';
import 'views/form_history_detail_screen.dart';
import 'views/change_password_screen.dart';
import 'views/edit_profile_screen.dart';
import 'views/form_preview_screen.dart';
import 'views/analytics_screen.dart';
import 'views/form_responses_screen.dart';

/// Route halaman yang dikelola secara deklaratif (Navigator 2.0 / Navigation 3).
enum AppPage {
  login,
  register,
  forgotPassword,
  otp,
  resetPassword,
  home,
  formMaker,
  formRunner,
  formHistoryDetail,
  changePassword,
  editProfile,
  formPreview,
  formAnalytics,
  formResponses,
}

/// Satu entri stack: halaman + argumen.
class AppRoute {
  final AppPage page;
  final Map<String, dynamic> args;

  const AppRoute(this.page, [this.args = const {}]);
}

/// [Page] kustom tanpa transisi agar berpindah screen instan & hemat resource.
class AppPageBuilder extends Page<void> {
  final AppRoute route;
  final WidgetBuilder builder;

  AppPageBuilder(this.route, this.builder) : super(key: ValueKey(route.page));

  @override
  Route<void> createRoute(BuildContext context) {
    return PageRouteBuilder<void>(
      settings: this,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => builder(context),
    );
  }
}

/// RouterDelegate — jantung Navigation 3. Mengelola stack halaman secara
/// deklaratif dan memberitahu Navigator kapan harus di-rebuild.
class AppRouterDelegate extends RouterDelegate<AppRoute> with ChangeNotifier {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final List<AppRoute> _stack = <AppRoute>[];
  final Map<AppPage, Completer<void>> _popCompleters = {};
  String _username = '';

  AppRouterDelegate({AppPage initial = AppPage.login}) {
    _stack.add(AppRoute(initial));
  }

  /// Nama tampilan user untuk halaman Home.
  String get username => _username;
  void setUsername(String value) => _username = value;

  /// Perbarui nama user + notify rebuild (dipakai setelah edit profil).
  void updateUsername(String value) {
    _username = value;
    notifyListeners();
  }

  List<AppRoute> get stack => List.unmodifiable(_stack);

  List<Page<void>> get _pages =>
      [for (final route in _stack) AppPageBuilder(route, (_) => _build(route))];

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: _pages,
      onDidRemovePage: (page) {
        if (_stack.length > 1) _stack.removeLast();
        if (page is AppPageBuilder) {
          _popCompleters.remove(page.route.page)?.complete();
        }
        notifyListeners();
      },
    );
  }

  @override
  Future<bool> popRoute() async {
    if (_stack.length > 1) {
      final removed = _stack.removeLast();
      _popCompleters.remove(removed.page)?.complete();
      notifyListeners();
      return true;
    }
    // ponytail: halaman root — biarkan sistem (Android) menutup app.
    await SystemNavigator.pop();
    return true;
  }

  @override
  Future<void> setNewRoutePath(AppRoute configuration) async {
    _completeAllPending();
    _stack
      ..clear()
      ..add(configuration);
    notifyListeners();
  }

  /// Masuk ke halaman Home (clear seluruh stack) + simpan nama user.
  void goHome(String displayName) {
    _username = displayName;
    _completeAllPending();
    _stack
      ..clear()
      ..add(const AppRoute(AppPage.home));
    notifyListeners();
  }

  /// Push halaman; Future selesai saat halaman itu di-pop (untuk refresh ulang).
  Future<void> push(AppPage page, [Map<String, dynamic> args = const {}]) {
    final completer = Completer<void>();
    _popCompleters[page] = completer;
    _stack.add(AppRoute(page, args));
    notifyListeners();
    return completer.future;
  }

  void pop([Object? result]) {
    if (_stack.length > 1) {
      final removed = _stack.removeLast();
      _popCompleters.remove(removed.page)?.complete();
      notifyListeners();
    }
  }

  /// Kembali ke Login (logout / back-to-login) — reset seluruh stack.
  void resetToLogin() {
    _completeAllPending();
    _stack
      ..clear()
      ..add(const AppRoute(AppPage.login));
    notifyListeners();
  }

  void _completeAllPending() {
    for (final c in _popCompleters.values) {
      if (!c.isCompleted) c.complete();
    }
    _popCompleters.clear();
  }


  Widget _build(AppRoute route) {
    switch (route.page) {
      case AppPage.login:
        return const LoginScreen();
      case AppPage.register:
        return const RegisterScreen();
      case AppPage.forgotPassword:
        return const ForgotPasswordScreen();
      case AppPage.otp:
        return OtpScreen(
          email: (route.args['email'] as String?) ?? '',
          fullname: route.args['fullname'] as String?,
          password: route.args['password'] as String?,
        );
      case AppPage.resetPassword:
        return ResetPasswordScreen(
          email: (route.args['email'] as String?) ?? '',
          otp: (route.args['otp'] as String?) ?? '',
        );
      case AppPage.home:
        return HomeScreen(username: _username);
      case AppPage.formMaker:
        return FormMakerScreen(formId: route.args['formId'] as int?);
      case AppPage.formRunner:
        return FormRunnerScreen(initialCode: route.args['code'] as String?);
      case AppPage.formHistoryDetail:
        return FormHistoryDetailScreen(
          formLink: route.args['formLink'] as String? ?? '',
          responseId: route.args['responseId'] as int? ?? 0,
        );
      case AppPage.changePassword:
        return const ChangePasswordScreen();
      case AppPage.editProfile:
        return const EditProfileScreen();
      case AppPage.formPreview:
        return FormPreviewScreen(
          formId: route.args['formId'] as int? ?? 0,
        );
      case AppPage.formAnalytics:
        return AnalyticsScreen(
          formId: route.args['formId'] as int? ?? 0,
          title: route.args['title'] as String? ?? '',
        );
      case AppPage.formResponses:
        return FormResponsesScreen(
          formId: route.args['formId'] as int? ?? 0,
          title: route.args['title'] as String? ?? '',
        );
    }
  }
}



/// Menerjemahkan URL (mis. `/login`, `/home`) menjadi [AppRoute] (dan kembali).
class AppRouteParser extends RouteInformationParser<AppRoute> {
  @override
  Future<AppRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final segments = routeInformation.uri.pathSegments;
    final first = segments.isEmpty ? '' : segments.first;
    return switch (first) {
      'home' => const AppRoute(AppPage.home),
      'register' => const AppRoute(AppPage.register),
      'forgot-password' => const AppRoute(AppPage.forgotPassword),
      'otp' => const AppRoute(AppPage.otp),
      'reset-password' => const AppRoute(AppPage.resetPassword),
      'form-maker' => const AppRoute(AppPage.formMaker),
      'form-runner' => const AppRoute(AppPage.formRunner),
      'form-history' => const AppRoute(AppPage.formHistoryDetail),
      'change-password' => const AppRoute(AppPage.changePassword),
      'edit-profile' => const AppRoute(AppPage.editProfile),
      'form-preview' => const AppRoute(AppPage.formPreview),
      'form-analytics' => const AppRoute(AppPage.formAnalytics),
      'form-responses' => const AppRoute(AppPage.formResponses),
      _ => const AppRoute(AppPage.login),
    };
  }

  @override
  RouteInformation restoreRouteInformation(AppRoute configuration) {
    final name = switch (configuration.page) {
      AppPage.login => 'login',
      AppPage.register => 'register',
      AppPage.forgotPassword => 'forgot-password',
      AppPage.otp => 'otp',
      AppPage.resetPassword => 'reset-password',
      AppPage.home => 'home',
      AppPage.formMaker => 'form-maker',
      AppPage.formRunner => 'form-runner',
      AppPage.formHistoryDetail => 'form-history',
      AppPage.changePassword => 'change-password',
      AppPage.editProfile => 'edit-profile',
      AppPage.formPreview => 'form-preview',
      AppPage.formAnalytics => 'form-analytics',
      AppPage.formResponses => 'form-responses',
    };
    return RouteInformation(uri: Uri.parse('/$name'));
  }
}

/// Akses mudah ke [AppRouterDelegate] dari mana saja via inherited widget.
class AppRouter extends InheritedWidget {
  final AppRouterDelegate delegate;

  const AppRouter({
    super.key,
    required this.delegate,
    required super.child,
  });

  static AppRouterDelegate of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppRouter>();
    assert(scope != null, 'AppRouter tidak ditemukan di atas context.');
    return scope!.delegate;
  }

  @override
  bool updateShouldNotify(AppRouter oldWidget) => delegate != oldWidget.delegate;
}

