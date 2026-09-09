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
import 'package:form_up/core/widgets/onboarding_tour.dart';
import 'package:form_up/features/home/widgets/user_guide_sheet.dart';

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

  // Anchor tur panduan (Beranda).
  final _kerjakanKey = GlobalKey();
  final _fabKey = GlobalKey();
  OverlayEntry? _tourOverlay;
  bool _tourAutoChecked = false;

  @override
  void initState() {
    super.initState();
    formsVersion.addListener(_onFormsChanged);
    NetworkStatus.onlineTick.addListener(_onOnline);
    homeTourRequest.addListener(_onHomeTourRequested);
    _load();
  }

  void _onOnline() {
    if (mounted && NetworkStatus.isOnline) _load();
  }

  @override
  void dispose() {
    _tourOverlay?.remove();
    _tourOverlay = null;
    formsVersion.removeListener(_onFormsChanged);
    NetworkStatus.onlineTick.removeListener(_onOnline);
    homeTourRequest.removeListener(_onHomeTourRequested);
    _codeController.dispose();
    super.dispose();
  }

  void _onFormsChanged() => _load();

  // ── Onboarding tur Beranda ──────────────────────────────────────────
  // Otomatis sekali per akun (login pertama); Lewati tersedia kapan saja
  // selama tur berjalan; ulangi via tombol bantuan / Settings > Panduan.

  Future<void> _maybeAutoTour() async {
    if (_tourAutoChecked || _tourOverlay != null || !mounted) return;
    _tourAutoChecked = true;
    if (await OnboardingFlags.isSeen('home', AuthService.email)) return;
    if (!mounted) return;
    // Tunggu frame selesai agar anchor sudah ter-layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showHomeTour());
  }

  void _showHomeTour() {
    if (_tourOverlay != null || !mounted) return;
    _tourOverlay = OverlayEntry(
      builder: (_) => OnboardingTour(
        // Alur singkat: Beranda → Form → AI Chat → Respons → Profil.
        steps: [
          OnboardingStep(
            anchorKey: _kerjakanKey,
            title: '1. Masuk / Kerjakan Form',
            description:
                'Punya kode atau QR form? Masukkan di sini untuk langsung mengerjakan. Mau buat sendiri? Lanjut tur.',
            icon: Icons.qr_code_scanner_outlined,
          ),
          OnboardingStep(
            anchorKey: _fabKey,
            title: '2. Buat Form',
            description:
                'Ketuk + untuk membuat form baru, lalu kelola soal, kunci jawaban, dan pengaturannya.',
            icon: Icons.add_circle_outline,
            onEnter: () => _goTab(1),
            // FAB muncul dengan animasi + setelah pindah tab: kunci posisi
            // setelah layout final agar lubang tidak offsite.
            settleMs: 500,
            spotlightPadding: 10,
          ),
          OnboardingStep(
            anchorKey: AiChatScreen.inputTourKey,
            title: '3. Chat AI',
            description:
                'Ketik di kolom ini — mis. "Buatkan 5 soal tentang fotosintesis". Periksa lalu Terima.',
            icon: Icons.auto_awesome_outlined,
            onEnter: () => _goTab(2),
          ),
          OnboardingStep(
            anchorKey: ResponseScreen.topTourKey,
            title: '4. Respons',
            description:
                'Tab Riwayat untuk form yang kamu isi, tab Responden untuk form milikmu. Pantau nilai di sini.',
            icon: Icons.bar_chart_outlined,
            onEnter: () => _goTab(3),
          ),
          OnboardingStep(
            anchorKey: ProfileScreen.editTourKey,
            extraAnchorKeys: [ProfileScreen.passwordTourKey],
            title: '5. Profil',
            description:
                'Ubah data lewat Edit Profil dan ganti kata sandi lewat Ubah Kata Sandi.',
            icon: Icons.person_outline,
            onEnter: () => _goTab(4),
          ),
        ],
        onComplete: () async {
          _tourOverlay?.remove();
          _tourOverlay = null;
          if (mounted) _goTab(0);
          await OnboardingFlags.markSeen('home', AuthService.email);
        },
      ),
    );
    Overlay.of(context).insert(_tourOverlay!);
  }

  void _goTab(int index) {
    if (!mounted || _currentIndex == index) return;
    setState(() {
      _visitedTabs.add(index);
      _currentIndex = index;
    });
  }

  /// Dipicu menu Panduan di Settings: langsung ke Beranda + mulai tur.
  void _onHomeTourRequested() {
    if (!mounted) return;
    _tourAutoChecked = true;
    _goTab(0);
    // Tunggu pindah tab selesai layout sebelum spotlight dihitung.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showHomeTour());
  }

  void _openGuide() {
    UserGuideSheet.show(
      context,
      onStartTour: () async {
        await OnboardingFlags.reset('home', AuthService.email);
        _tourAutoChecked = true;
        _showHomeTour();
      },
    );
  }

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
      _maybeAutoTour();
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
      indicatorColor: Theme.of(context).colorScheme.primary,
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
              key: _kerjakanKey,
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

             Text(
              "Aktivitas Respon Terbaru",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Theme.of(context).colorScheme.onSurface,
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
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
        decoration:  BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
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
          backgroundColor: cs.surface,
          indicatorColor: kPrimary.withValues(alpha: 0.15),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
           NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: cs.primary),
            label: 'Beranda',
          ),
           NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description, color: cs.primary),
            label: 'Form',
          ),
          NavigationDestination(
            icon:  AiChatIcon(color: cs.onSurfaceVariant, size: 24, filled: false),
            selectedIcon:  AiChatIcon(color: cs.primary, size: 24, filled: true),
            label: 'AI Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: cs.primary),
            label: 'Respon',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: cs.primary),
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
                key: _fabKey,
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
      children:  [
        Text(
          "Form Terbaru",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        IconButton(
          tooltip: 'Panduan aplikasi',
          visualDensity: VisualDensity.compact,
          onPressed: _openGuide,
          icon: Icon(
            Icons.help_outline,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
