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
import 'package:form_up/core/services/user_service.dart';
import 'package:form_up/core/widgets/cached_remote_image.dart';
import 'package:form_up/core/widgets/onboarding_tour.dart';
import 'package:form_up/core/widgets/responsive.dart';
import 'package:form_up/core/widgets/empty_state.dart';
import 'package:form_up/core/widgets/loading_skeleton.dart';
import 'package:form_up/core/widgets/form_card.dart';
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
  String? _avatarPath;
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
            extraAnchorKeys: [FormScreen.createTourKey],
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
            // Profil first-install masih loading network (cache kosong) saat
            // tab dibuka — beri jeda kunci ulang lebih lama agar lubang
            // tidak terkunci prematur sebelum menu ter-layout.
            settleMs: 600,
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
        // Foto profil untuk tombol akun sidebar (best-effort).
        UserService.getProfile()
            .then((p) => p.profileImage ?? '')
            .catchError((_) => ''),
      ]);
      if (!mounted) return;
      setState(() {
        _myForms = results[0] as List<FormData>;
        _myResponses = results[1] as List<MyResponseItem>;
        _avatarPath = results[2] as String;
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

  /// A6: normalisasi kode form — tempelan URL penuh
  /// (mis. https://.../f/ABC123?x=1) diekstrak menjadi kode murni agar
  /// tidak menjadi `GET /public/forms/https://...` → 404.
  static String _extractFormLink(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return input;
    final uri = Uri.tryParse(input);
    final segs = uri?.pathSegments
            .where((s) => s.trim().isNotEmpty)
            .toList() ??
        const [];
    if (segs.isNotEmpty) return segs.last.trim();
    final slash = input.lastIndexOf('/');
    if (slash >= 0 && slash < input.length - 1) {
      return input.substring(slash + 1).split('?').first.trim();
    }
    return input.split('?').first.trim();
  }

  void _start() async {
    // Debounce 3 detik: tombol selalu fetch API (refresh:true), tapi tidak
    // boleh di-spam — jendela lebih panjang dari default 300ms karena setiap
    // tekan memicu request info form ke server.
    if (!AppDebouncer.tryAcquire('home:start', window: const Duration(seconds: 3))) {
      return;
    }
    if (_validatingCode) return;
    final code = _extractFormLink(_codeController.text);
    if (code.isEmpty) {
      showAuthToast(context, "Masukkan kode form terlebih dahulu", isError: true);
      return;
    }
    setState(() => _validatingCode = true);
    try {
      // Selalu fetch info form (refresh:true) supaya kegagalan (404 / link
      // berubah) langsung terlihat, lalu SELALU masuk ke info form screen —
      // status terkunci (owner / jadwal / login / one-response sudah diisi)
      // ditampilkan di sana dengan tombol disabled + pesan jelas.
      await PublicFormService.getFormInfo(code, refresh: true);
      if (!mounted) return;
      AppRouter.of(context).push(AppPage.formStart, {'formLink': code});
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.formLookupErrorMessage(e),
          isError: true);
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

  Widget _driveSectionTitle(String title, {VoidCallback? onSeeAll}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: cs.onSurface,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('Lihat semua'),
          ),
      ],
    );
  }

  /// Beranda gaya Drive (desktop ≥1200 saja): Masuk Form paling atas, grid
  /// Form Terbaru (2→4, 3→6, 4→8 item), lalu Aktivitas clear tanpa card.
  /// Tablet/phone memakai _buildHomeTab dan tidak tersentuh.
  Widget _buildDriveHomeTab() {
    final cs = Theme.of(context).colorScheme;
    return AppRefreshIndicator(
      onRefresh: _load,
      indicatorColor: cs.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Satu ambang dengan Beranda/Form Saya: grid Terbaru = kolom × 2
                // (4/6/8), aktivitas secukupnya mengikuti kolom (2/3/4).
                final w = constraints.maxWidth;
                final cols = formGridColumns(w);
                final formCount = cols * 2;
                final activityCount = cols;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Halo, ${widget.username}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Apa yang ingin Anda lakukan hari ini?',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        // Tanpa judul section (label sudah ada di dalam card).
                        child: HomeKerjakanCard(
                          key: _kerjakanKey,
                          codeController: _codeController,
                          onStart: _start,
                          onOpenScanner: _openScanner,
                          loading: _validatingCode,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _driveSectionTitle(
                      'Form Terbaru',
                      onSeeAll: () => _selectTab(1),
                    ),
                    const SizedBox(height: 12),
                    if (_loading && _myForms.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: SkeletonList.cards(itemCount: formCount),
                      )
                    else if (_myForms.isEmpty)
                      const EmptyState(
                        icon: Icons.description_outlined,
                        title: 'Belum ada form',
                        message: 'Tekan + Baru untuk membuat form pertama Anda.',
                        bare: true,
                      )
                    else
                      ResponsiveGrid(
                        children: [
                          for (final form in _myForms.take(formCount))
                            FormCard(
                              form: form,
                              onTap: () => AppRouter.of(context)
                                  .push(AppPage.formDetail, {
                                'formId': form.id,
                                'form': form,
                              }),
                            ),
                        ],
                      ),
                    const SizedBox(height: 28),
                    _driveSectionTitle('Aktivitas Respon Terbaru'),
                    const SizedBox(height: 12),
                    HomeRecentActivity(
                      loading: _loading,
                      responses: _myResponses,
                      onOpenResponse: _openResponse,
                      limit: activityCount,
                      bare: true,
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    // Phone identik (base); tablet/desktop konten boleh melebar hingga 960
    // agar grid Form Terbaru mencapai 3 kolom seperti Form Saya.
    return AppRefreshIndicator(
      onRefresh: _load,
      indicatorColor: Theme.of(context).colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: centerPad(context, base: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0), maxWidth: 960),
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

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _visitedTabs.add(index);
      _currentIndex = index;
    });
  }

  IndexedStack _buildTabs({bool drive = false}) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        drive ? _buildDriveHomeTab() : _buildHomeTab(),
        if (_visitedTabs.contains(1)) const FormScreen() else const SizedBox.shrink(),
        if (_visitedTabs.contains(2)) const AiChatScreen(embedded: true) else const SizedBox.shrink(),
        if (_visitedTabs.contains(3)) const ResponseScreen() else const SizedBox.shrink(),
        if (_visitedTabs.contains(4))
          ProfileScreen(username: widget.username)
        else
          const SizedBox.shrink(),
      ],
    );
  }

  List<NavigationDestination> _barDestinations(ColorScheme cs) => [
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
          icon: AiChatIcon(color: cs.onSurfaceVariant, size: 24, filled: false),
          selectedIcon: AiChatIcon(color: cs.primary, size: 24, filled: true),
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
      ];

  List<NavigationRailDestination> _railDestinations(ColorScheme cs) => [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: cs.primary),
          label: Text('Beranda'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.description_outlined),
          selectedIcon: Icon(Icons.description, color: cs.primary),
          label: Text('Form'),
        ),
        NavigationRailDestination(
          icon: AiChatIcon(color: cs.onSurfaceVariant, size: 24, filled: false),
          selectedIcon: AiChatIcon(color: cs.primary, size: 24, filled: true),
          label: Text('AI Chat'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart, color: cs.primary),
          label: Text('Respon'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: cs.primary),
          label: Text('Profil'),
        ),
      ];

  /// Sidebar ala Drive (M3 NavigationDrawer): logo + nav; tombol profil
  /// berfoto di-pin paling bawah (tanpa tab Profil & tanpa tombol Baru —
  /// buat form lewat header tab Form Saya).
  Widget _buildDriveSidebar(ColorScheme cs) {
    // Card navigasi: drawer transparan di dalam container tonal, footer
    // profil di-pin paling bawah di dalam card yang sama.
    return Container(
      width: 320,
      margin: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Expanded(
            child: NavigationDrawer(
              // Drawer hanya berisi 4 destinasi (tanpa Profil).
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedIndex: _currentIndex <= 3 ? _currentIndex : null,
              onDestinationSelected: _selectTab,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.description_outlined,
                            color: cs.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'FormUp',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ..._drawerDestinations(cs),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            // Material sendiri agar ink splash ListTile tidak tertutup
            // DecoratedBox card sidebar.
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
              leading: CachedRemoteCircleAvatar(
                url: (_avatarPath ?? '').isEmpty
                    ? null
                    : profileImageUrl(_avatarPath),
                radius: 20,
                backgroundColor: cs.primaryContainer,
                fallback: Text(
                  widget.username.trim().isNotEmpty
                      ? widget.username.trim()[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                      color: cs.primary, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                widget.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                'Lihat profil',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.grey, size: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onTap: () => _selectTab(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<NavigationDrawerDestination> _drawerDestinations(ColorScheme cs) => [
        NavigationDrawerDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: cs.primary),
          label: Text('Beranda'),
        ),
        NavigationDrawerDestination(
          icon: Icon(Icons.description_outlined),
          selectedIcon: Icon(Icons.description, color: cs.primary),
          label: Text('Form'),
        ),
        NavigationDrawerDestination(
          icon: AiChatIcon(color: cs.onSurfaceVariant, size: 24, filled: false),
          selectedIcon: AiChatIcon(color: cs.primary, size: 24, filled: true),
          label: Text('AI Chat'),
        ),
        NavigationDrawerDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart, color: cs.primary),
          label: Text('Respon'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Sidebar panel HANYA untuk OS desktop asli (Windows/macOS/Linux) yang
    // lebar (≥1200). Tablet Android/iOS — walau landscape 1280 — tetap
    // memakai NavigationRail di bawah; baru phone (<840) bottom bar.
    // Cabang tablet/phone di bawah tidak berubah.
    if (isDesktopPlatform && isDesktopWidth(context)) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _buildDriveSidebar(cs),
              Expanded(child: _buildTabs(drive: true)),
            ],
          ),
        ),
      );
    }
    // Tablet (semua orientasi, termasuk portrait <840) + layar lebar (≥840)
    // memakai NavigationRail kiri seperti screenshot acuan; phone bottom bar.
    if (useNavRail(context)) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _selectTab,
                // Rail ikon saja tanpa label di semua layout (tidak ada
                // varian rail + label / extended).
                extended: false,
                labelType: NavigationRailLabelType.none,
                backgroundColor: cs.surface,
                indicatorColor: kPrimary.withValues(alpha: 0.15),
                selectedIconTheme: IconThemeData(color: cs.primary),
                destinations: _railDestinations(cs),
              ),
              VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
              Expanded(child: _buildTabs()),
            ],
          ),
        ),
        floatingActionButton: _railFab(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: _buildTabs(),
      ),
      bottomNavigationBar: Container(
        decoration:  BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: NavigationBar(
          height: 62,
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
          backgroundColor: cs.surface,
          indicatorColor: kPrimary.withValues(alpha: 0.15),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _barDestinations(cs),
        ),
      ),
      // FAB tambah form: hanya tampil di tab Form Saya, melayang kanan bawah
      // (endFloat = punya lapisan klik sendiri, tidak menembus widget di belakang)
      floatingActionButton: _railFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// FAB tambah form — dipakai phone maupun rail agar satu definisi.
  /// Desktop (≥1200): disembunyikan karena tombol ada di header Form Saya.
  Widget? _railFab() {
    if (_currentIndex != 1) return null;
    if (isDesktopWidth(context)) return null;
    return SizedBox(
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
