import 'package:flutter/material.dart';
import 'package:form_up/core/widgets/app_refresh_indicator.dart';
import 'package:form_up/core/utils/action_debouncer.dart';
import 'package:form_up/core/widgets/auth_widgets.dart';
import 'package:form_up/features/home/screens/form_screen.dart';
import 'package:form_up/features/home/screens/response_screen.dart';
import 'package:form_up/features/home/widgets/home_header.dart';
import 'package:form_up/features/home/widgets/home_kerjakan_card.dart';
import 'package:form_up/features/home/widgets/home_recent_activity.dart';
import 'package:form_up/features/home/widgets/home_recent_forms.dart';
import 'package:form_up/features/profile/screens/profile_screen.dart';
import 'package:form_up/features/ai_chat/screens/ai_chat_screen.dart';
import 'package:form_up/core/widgets/ai_chat_icon.dart';
import 'package:form_up/core/router/app_router.dart';
import 'package:form_up/core/services/auth_service.dart';
import 'package:form_up/core/services/form_service.dart';
import 'package:form_up/core/services/network_status.dart';
import 'package:form_up/core/services/public_form_service.dart';

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // ponytail: IndexedStack lazy, state terjaga
  final Set<int> _visitedTabs = {0};

  List<FormData> _myForms = [];
  List<MyResponseItem> _myResponses = [];
  bool _loading = true;
  final _codeController = TextEditingController();
  bool _validatingCode = false;

  @override
  void initState() {
    super.initState();
    formsVersion.addListener(_onFormsChanged);
    NetworkStatus.onlineTick.addListener(_onOnline);
    _load();
  }

  void _onOnline() {
    if (mounted && NetworkStatus.isOnline) _load();
  }

  @override
  void dispose() {
    formsVersion.removeListener(_onFormsChanged);
    NetworkStatus.onlineTick.removeListener(_onOnline);
    _codeController.dispose();
    super.dispose();
  }

  void _onFormsChanged() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        FormService.getMyForms(),
        FormService.getMyResponses(),
      ]);
      if (!mounted) return;
      setState(() {
        _myForms = results[0] as List<FormData>;
        _myResponses = results[1] as List<MyResponseItem>;
      });
    } catch (e) {
      if (!mounted) return;
      // Konsisten: selalu toast float, tidak ada banner inline di dalam view
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _start() async {
    if (!AppDebouncer.tryAcquire('home:start')) return;
    if (_validatingCode) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showAuthToast(context, "Masukkan kode form terlebih dahulu", isError: true);
      return;
    }
    setState(() => _validatingCode = true);
    try {
      final info = await PublicFormService.getFormInfo(code);
      if (!mounted) return;
      if (info.isOwner) {
        showAuthToast(context, "Anda tidak dapat mengisi form yang Anda buat sendiri", isError: true);
        return;
      }
      AppRouter.of(context).push(AppPage.formStart, {'formLink': code});
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _validatingCode = false);
    }
  }

  void _openScanner() {
    AppRouter.of(context).push(AppPage.qrcodeScanner);
  }

  void _openResponse(MyResponseItem item) {
    AppRouter.of(context).push(AppPage.formHistoryDetail, {
      'formLink': item.formLink,
      'responseId': item.responseId,
    });
  }

  Widget _buildHomeTab() {
    return AppRefreshIndicator(
      onRefresh: _load,
      indicatorColor: kAuthPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            HomeHeader(username: widget.username),
            // const SizedBox(height: 12),
            // // AI Chat entry - pindah ke tab tengah, tap switch tab
            // InkWell(
            //   onTap: () => setState(() {
            //     _visitedTabs.add(2);
            //     _currentIndex = 2;
            //   }),
            //   borderRadius: BorderRadius.circular(16),
            //   child: Container(
            //     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            //     decoration: BoxDecoration(
            //       gradient: const LinearGradient(colors: [Color(0xFF018081), Color(0xFF2A9D8F)]),
            //       borderRadius: BorderRadius.circular(16),
            //       boxShadow: softShadow(),
            //     ),
            //     child: Row(children: [
            //       Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)), child: const AiChatIcon(color: Colors.white, size: 20, filled: false)),
            //       const SizedBox(width: 12),
            //       const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            //         Text('AI Chat - Buat Form Otomatis', style: TextStyle(color: Colors.white, fontFamily: kFontBold, fontSize: 13)),
            //         Text('Realtime dengan Gemini', style: TextStyle(color: Colors.white70, fontSize: 11)),
            //       ])),
            //       const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
            //     ]),
            //   ),
            // ),
            const SizedBox(height: 20),

            HomeKerjakanCard(
              codeController: _codeController,
              onStart: _start,
              onOpenScanner: _openScanner,
              loading: _validatingCode,
            ),
            const SizedBox(height: 25),

            _buildRecentFormsHeader(),
            const SizedBox(height: 12),

            HomeRecentForms(
              loading: _loading,
              forms: _myForms,
              onOpenForm: (form) =>
                  AppRouter.of(context).push(AppPage.formDetail, {
                'formId': form.id,
                'form': form,
              }),
            ),
            const SizedBox(height: 25),

            const Text(
              "Aktivitas Respon Terbaru",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            HomeRecentActivity(
              loading: _loading,
              responses: _myResponses,
              onOpenResponse: _openResponse,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppBg,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            if (_visitedTabs.contains(1)) const FormScreen() else const SizedBox.shrink(),
            if (_visitedTabs.contains(2)) const AiChatScreen(embedded: true) else const SizedBox.shrink(),
            if (_visitedTabs.contains(3)) const ResponseScreen() else const SizedBox.shrink(),
            if (_visitedTabs.contains(4))
              ProfileScreen(username: widget.username)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xCCBDC9C8))),
        ),
        child: NavigationBar(
          height: 62,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (index == _currentIndex) return;
            setState(() {
              _visitedTabs.add(index);
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.white,
          indicatorColor: kPrimary.withValues(alpha: 0.15),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: kPrimary),
            label: 'Beranda',
          ),
          const NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description, color: kPrimary),
            label: 'Form',
          ),
          NavigationDestination(
            icon: const AiChatIcon(color: Colors.black54, size: 24, filled: false),
            selectedIcon: const AiChatIcon(color: kPrimary, size: 24, filled: true),
            label: 'AI Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: kPrimary),
            label: 'Respon',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: kPrimary),
            label: 'Profil',
          ),
        ],
        ),
      ),
      // FAB tambah form: hanya tampil di tab Form Saya, melayang kanan bawah
      // (endFloat = punya lapisan klik sendiri, tidak menembus widget di belakang)
      floatingActionButton: _currentIndex == 1
          ? SizedBox(
              width: 68,
              height: 68,
              child: FloatingActionButton(
                onPressed: () {
                  AppRouter.of(context).push(AppPage.formTemplateChooser);
                },
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.add, size: 32),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildRecentFormsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text(
          "Form Terbaru",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
