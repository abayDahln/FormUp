import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:form_up/features/auth/screens/login_screen.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/features/auth/screens/register_screen.dart';
import 'package:form_up/features/auth/screens/forgot_password_screen.dart';
import 'package:form_up/features/auth/screens/otp_screen.dart';
import 'package:form_up/features/auth/screens/reset_password_screen.dart';
import 'package:form_up/features/home/screens/home_screen.dart';
import 'package:form_up/features/form/screens/form_maker_screen.dart';
import 'package:form_up/features/form/screens/form_template_chooser_screen.dart';
import 'package:form_up/features/form_runner/screens/form_runner_screen.dart';
import 'package:form_up/features/form/screens/form_history_detail_screen.dart';
import 'package:form_up/features/form/screens/history_form_detail_screen.dart';
import 'package:form_up/features/auth/screens/change_password_screen.dart';
import 'package:form_up/features/profile/screens/edit_profile_screen.dart';
import 'package:form_up/features/form/screens/form_preview_screen.dart';
import 'package:form_up/features/form/screens/analytics_screen.dart';
import 'package:form_up/features/responses/screens/form_respon_screen.dart';
import 'package:form_up/features/responses/screens/respondent_detail_screen.dart';
import 'package:form_up/features/admin/screens/admin_home_screen.dart';
import 'package:form_up/features/admin/screens/admin_user_detail_screen.dart';
import 'package:form_up/features/admin/screens/admin_form_detail_screen.dart';
import 'package:form_up/features/admin/screens/admin_feedback_detail_screen.dart';
import 'package:form_up/core/services/admin_service.dart';
import 'package:form_up/features/settings/settings_screen.dart';
import 'package:form_up/features/form/screens/form_detail_screen.dart';
import 'package:form_up/features/form/screens/exam_monitoring_screen.dart';
import 'package:form_up/features/form/screens/form_questions_screen.dart';
import 'package:form_up/features/form/screens/form_question_edit_screen.dart';
import 'package:form_up/features/form/screens/form_feedbacks_screen.dart';
import 'package:form_up/features/form_runner/screens/form_start_screen.dart';
import 'package:form_up/features/home/screens/qrcode_scanner_screen.dart';
import 'package:form_up/core/models/question_draft.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/features/ai_chat/screens/ai_chat_screen.dart';
import 'package:form_up/features/ai_chat/screens/ai_settings_screen.dart';

/// Route halaman deklaratif (Navigator 2.0)
enum AppPage {
  login,
  register,
  forgotPassword,
  otp,
  resetPassword,
  home,
  formTemplateChooser,
  formMaker,
  formQuestions,
  formQuestionEdit,
  formRunner,
  formStart,
  qrcodeScanner,
  formDetail,
  historyFormDetail,
  formHistoryDetail,
  changePassword,
  editProfile,
  formPreview,
  formAnalytics,
  formRespon,
  formFeedbacks,
  examMonitoring,
  respondentDetail,
  adminPanel,
  adminUserDetail,
  adminFormDetail,
  adminFeedbackDetail,
  settings,
  aiChat,
  aiSettings,
}

class AppRoute {
  final AppPage page;
  final Map<String, dynamic> args;

  const AppRoute(this.page, [this.args = const {}]);
}

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

/// RouterDelegate Navigation 3
class AppRouterDelegate extends RouterDelegate<AppRoute> with ChangeNotifier {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final List<AppRoute> _stack = <AppRoute>[];
  final Map<AppPage, Completer<void>> _popCompleters = {};
  String _username = '';
  bool _initialSet = false;

  /// Stack guard back: screen push/pop guard di init/dispose. popRoute()
  /// meminta izin dari guard paling atas (screen paling atas). false = batalkan.
  final List<Future<bool> Function()> _backGuards = [];

  void pushBackGuard(Future<bool> Function() guard) => _backGuards.add(guard);

  void popBackGuard() {
    if (_backGuards.isNotEmpty) _backGuards.removeLast();
  }

  Future<bool> Function()? get _topBackGuard =>
      _backGuards.isEmpty ? null : _backGuards.last;

  /// Kode form deep link menunggu login
  String? _pendingFormCode;

  /// true bila session dimulai dari deep link (stack root bukan login/home).
  /// Back di root fallback ke beranda, bukan menutup app.
  bool _viaDeepLink = false;

  AppRouterDelegate({AppPage initial = AppPage.login}) {
    _stack.add(AppRoute(initial));
    _initialSet = true;
    debugPrint('[Router] Initial stack: $_stack');
  }

  /// Nama tampilan di Home
  String get username => _username;
  void setUsername(String value) => _username = value;

  /// Update nama user + notify
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

  /// Halaman root sesuai role: admin masuk ke Admin Panel, user biasa ke Home
  AppPage get _rootPage => AuthService.role == 'ADMIN'
      ? AppPage.adminPanel
      : AppPage.home;

  @override
  Future<bool> popRoute() async {
    // Guard selalu diperiksa (termasuk di root, mis. deep link form).
    final guard = _topBackGuard;
    if (guard != null) {
      final allow = await guard();
      if (!allow) return true;
    }
    if (_stack.length > 1) {
      final removed = _stack.removeLast();
      _popCompleters.remove(removed.page)?.complete();
      notifyListeners();
      return true;
    }
    // Root tanpa history: fallback ke halaman root bila masuk via deep link.
    if (_viaDeepLink) {
      _viaDeepLink = false;
      _stack
        ..clear()
        ..add(AppRoute(_rootPage));
      notifyListeners();
      return true;
    }
    // ponytail: root normal, sistem menutup app
    await SystemNavigator.pop();
    return true;
  }

  @override
  Future<void> setNewRoutePath(AppRoute configuration) async {
    _completeAllPending();
    
    // 🔧 FIX: Jika initial sudah di-set dan user sudah login, jangan override ke login
    if (_initialSet && 
        configuration.page == AppPage.login && 
        _stack.isNotEmpty &&
        _stack.first.page != AppPage.login &&
        AuthService.token != null) {
      debugPrint('[Router] Ignoring login override, user already logged in');
      return;
    }
    
    // Deep link form butuh login
    if (configuration.page == AppPage.formRunner &&
        configuration.args['code'] is String &&
        AuthService.token == null) {
      _pendingFormCode = configuration.args['code'] as String;
      _stack
        ..clear()
        ..add(const AppRoute(AppPage.login));
      notifyListeners();
      return;
    }
    
    _viaDeepLink = configuration.page != AppPage.login && configuration.page != AppPage.home;
    _stack
      ..clear()
      ..add(configuration);
    notifyListeners();
  }

  /// Masuk halaman root sesuai role (Admin Panel untuk admin, Home untuk user)
  void goHome(String displayName) {
    _username = displayName;
    _completeAllPending();
    _viaDeepLink = false;
    _stack
      ..clear()
      ..add(AppRoute(_rootPage));
    notifyListeners();
    // Push form deep link tertunda
    final pending = _pendingFormCode;
    if (pending != null && pending.isNotEmpty) {
      _pendingFormCode = null;
      push(AppPage.formRunner, {'code': pending});
    }
  }

  /// Push halaman, selesai saat di-pop
  Future<void> push(AppPage page, [Map<String, dynamic> args = const {}]) {
    final completer = Completer<void>();
    _popCompleters[page] = completer;
    _stack.add(AppRoute(page, args));
    notifyListeners();
    return completer.future;
  }

  /// Ganti halaman paling atas tanpa mempertahankan route sebelumnya.
  void replaceTop(AppPage page, [Map<String, dynamic> args = const {}]) {
    if (_stack.isNotEmpty) {
      final removed = _stack.removeLast();
      _popCompleters.remove(removed.page)?.complete();
    }
    _stack.add(AppRoute(page, args));
    notifyListeners();
  }

  void pop([Object? result]) {
    if (_stack.length > 1) {
      final removed = _stack.removeLast();
      _popCompleters.remove(removed.page)?.complete();
      notifyListeners();
    } else if (_viaDeepLink) {
      // Root dari deep link → fallback ke halaman root sesuai role
      _viaDeepLink = false;
      _stack
        ..clear()
        ..add(AppRoute(_rootPage));
      notifyListeners();
    }
  }

  /// Reset ke Login
  void resetToLogin() {
    _completeAllPending();
    _viaDeepLink = false;
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
      case AppPage.formTemplateChooser:
        return const FormTemplateChooserScreen();
      case AppPage.formMaker:
        return FormMakerScreen(formId: route.args['formId'] as int?);
      case AppPage.formQuestions:
        return FormQuestionsScreen(
          formId: route.args['formId'] as int?,
          isNew: route.args['isNew'] == true,
        );
      case AppPage.formQuestionEdit:
        return FormQuestionEditScreen(
          formId: route.args['formId'] as int?,
          draft: route.args['draft'] as QuestionDraft,
        );
      case AppPage.formRunner:
        return FormRunnerScreen(
          initialCode: route.args['code'] as String?,
          initialToken: route.args['token'] as String?,
        );
      case AppPage.formStart:
        return FormStartScreen(formLink: route.args['formLink'] as String? ?? '');
      case AppPage.qrcodeScanner:
        return const QrcodeScannerScreen();
      case AppPage.formDetail:
        return FormDetailScreen(
          formId: route.args['formId'] as int? ?? 0,
          initial: route.args['form'] as FormData?,
        );
      case AppPage.historyFormDetail:
        return HistoryFormDetailScreen(
          formLink: route.args['formLink'] as String? ?? '',
          formTitle: route.args['formTitle'] as String? ?? '',
        );
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
      case AppPage.formRespon:
        return FormResponScreen(
          formId: route.args['formId'] as int? ?? 0,
          title: route.args['title'] as String? ?? '',
        );
      case AppPage.formFeedbacks:
        return FormFeedbacksScreen(
          formId: route.args['formId'] as int,
          formTitle: route.args['formTitle'] as String,
        );
      case AppPage.examMonitoring:
        return ExamMonitoringScreen(
          formId: route.args['formId'] as int? ?? 0,
          title: route.args['title'] as String? ?? '',
        );
      case AppPage.respondentDetail:
        return RespondentDetailScreen(
          formId: route.args['formId'] as int? ?? 0,
          title: route.args['title'] as String? ?? '',
          responseId: route.args['responseId'] as int? ?? 0,
          respondentName: route.args['respondentName'] as String? ?? '',
        );
      case AppPage.adminPanel:
        return const AdminHomeScreen();
      case AppPage.adminUserDetail:
        return AdminUserDetailScreen(
          userId: route.args['userId'] as int? ?? 0,
        );
      case AppPage.adminFormDetail:
        return AdminFormDetailScreen(
          formId: route.args['formId'] as int? ?? 0,
        );
      case AppPage.adminFeedbackDetail:
        return AdminFeedbackDetailScreen(
          feedback: route.args['feedback'] as AdminFeedbackItem,
        );
      case AppPage.settings:
        return const SettingsScreen();
      case AppPage.aiChat:
        return AiChatScreen(
          initialFormId: route.args['formId'] as int?,
          initialPrompt: route.args['initialPrompt'] as String?,
        );
      case AppPage.aiSettings:
        return const AiSettingsScreen();
    }
  }
}



/// Terjemahkan URL jadi AppRoute
class AppRouteParser extends RouteInformationParser<AppRoute> {
  @override
  Future<AppRoute> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final segments = routeInformation.uri.pathSegments;
    final first = segments.isEmpty ? '' : segments.first;
    // Deep link form publik /f /q
    if ((first == 'f' || first == 'q') && segments.length >= 2) {
      return AppRoute(AppPage.formRunner, {'code': segments[1]});
    }
    return switch (first) {
      'home' => const AppRoute(AppPage.home),
      'register' => const AppRoute(AppPage.register),
      'forgot-password' => const AppRoute(AppPage.forgotPassword),
      'otp' => const AppRoute(AppPage.otp),
      'reset-password' => const AppRoute(AppPage.resetPassword),
      'form-maker' => const AppRoute(AppPage.formMaker),
      'form-template-chooser' => const AppRoute(AppPage.formTemplateChooser),
      'form-questions' => const AppRoute(AppPage.formQuestions),
      'form-question-edit' => const AppRoute(AppPage.formQuestionEdit),
      'form-runner' => const AppRoute(AppPage.formRunner),
      'form-start' => AppRoute(AppPage.formStart, {'formLink': segments.length >= 3 ? segments[2] : ''}),
      'scan-qrcode' => const AppRoute(AppPage.qrcodeScanner),
      'form-detail' => const AppRoute(AppPage.formDetail),
      'form-history' => const AppRoute(AppPage.formHistoryDetail),
      'history-form' => const AppRoute(AppPage.historyFormDetail),
      'change-password' => const AppRoute(AppPage.changePassword),
      'edit-profile' => const AppRoute(AppPage.editProfile),
      'form-preview' => const AppRoute(AppPage.formPreview),
      'form-analytics' => const AppRoute(AppPage.formAnalytics),
      'form-respon' => const AppRoute(AppPage.formRespon),
      'form-feedbacks' => const AppRoute(AppPage.formFeedbacks),
      'exam-monitoring' => const AppRoute(AppPage.examMonitoring),
      'settings' => const AppRoute(AppPage.settings),
      'ai-chat' => const AppRoute(AppPage.aiChat),
      'ai-settings' => const AppRoute(AppPage.aiSettings),
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
      AppPage.formTemplateChooser => 'form-template-chooser',
      AppPage.formMaker => 'form-maker',
      AppPage.formQuestions => 'form-questions',
      AppPage.formQuestionEdit => 'form-question-edit',
      AppPage.formRunner => 'form-runner',
      AppPage.formStart => 'form-start',
      AppPage.qrcodeScanner => 'scan-qrcode',
      AppPage.formDetail => 'form-detail',
      AppPage.historyFormDetail => 'history-form',
      AppPage.formHistoryDetail => 'form-history',
      AppPage.changePassword => 'change-password',
      AppPage.editProfile => 'edit-profile',
      AppPage.formPreview => 'form-preview',
      AppPage.formAnalytics => 'form-analytics',
      AppPage.formRespon => 'form-respon',
      AppPage.formFeedbacks => 'form-feedbacks',
      AppPage.examMonitoring => 'exam-monitoring',
      AppPage.respondentDetail => 'respondent-detail',
      AppPage.adminPanel => 'admin-panel',
      AppPage.adminUserDetail => 'admin-user',
      AppPage.adminFormDetail => 'admin-form',
      AppPage.adminFeedbackDetail => 'admin-feedback',
      AppPage.settings => 'settings',
      AppPage.aiChat => 'ai-chat',
      AppPage.aiSettings => 'ai-settings',
    };
    return RouteInformation(uri: Uri.parse('/$name'));
  }
}

/// Akses AppRouterDelegate via inherited widget
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









