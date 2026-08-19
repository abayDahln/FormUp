import 'package:flutter/material.dart';
import 'form_card.dart';
import 'form_screen.dart';
import 'response_screen.dart';
import 'profile_screen.dart';
import 'auth_widgets.dart';
import 'rich_editor.dart';
import '../app_router.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';

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
  String? _loadError;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    formsVersion.addListener(_onFormsChanged);
    _load(silent: true);
  }

  @override
  void dispose() {
    formsVersion.removeListener(_onFormsChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onFormsChanged() => _load(silent: true);

  /// Load silent (tanpa toast)
  Future<void> _load({bool silent = false}) async {
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
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = AuthService.errorMessage(e);
      if (silent) {
        setState(() => _loadError = message);
      } else {
        showAuthToast(context, message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _start() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      showAuthToast(context, "Masukkan kode form terlebih dahulu", isError: true);
      return;
    }
    AppRouter.of(context).push(AppPage.formRunner, {'code': code});
  }

  void _openResponse(MyResponseItem item) {
    AppRouter.of(context).push(AppPage.formHistoryDetail, {
      'formLink': item.formLink,
      'responseId': item.responseId,
    });
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _load,
      color: kAuthPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildHeader(),
            const SizedBox(height: 20),

            if (_loadError != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC0392B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFC0392B), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _loadError!,
                        style: const TextStyle(
                          color: Color(0xFFC0392B),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            _buildKerjakanCard(),
            const SizedBox(height: 25),

            _buildRecentFormsHeader(),
            const SizedBox(height: 12),

            _buildRecentForms(),
            const SizedBox(height: 25),

            const Text(
              "Aktivitas Respons Terbaru",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            _buildRecentActivity(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: AuthBackground(
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeTab(),
              if (_visitedTabs.contains(1)) const FormScreen() else const SizedBox.shrink(),
              const SizedBox.shrink(),
              if (_visitedTabs.contains(3)) const ResponseScreen() else const SizedBox.shrink(),
              if (_visitedTabs.contains(4))
                ProfileScreen(username: widget.username)
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == _currentIndex) return;
            setState(() {
              _visitedTabs.add(index);
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: kPrimary,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          iconSize: 22,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              activeIcon: Icon(Icons.description),
              label: 'Form',
            ),
            BottomNavigationBarItem(
              icon: SizedBox.shrink(),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Respons',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          AppRouter.of(context).push(AppPage.formMaker);
        },
        backgroundColor: kPrimary,
        elevation: 1,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Halo, ${widget.username.isNotEmpty ? widget.username : 'Pengguna'}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: kFontBold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          "Apa yang ingin Anda lakukan hari ini?",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildKerjakanCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Kerjakan Form",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "Masukkan kode form untuk mulai mengerjakan.",
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            style: const TextStyle(color: Colors.black87),
            cursorColor: kAuthPrimary,
            decoration: InputDecoration(
              hintText: "Kode form",
              hintStyle: const TextStyle(color: kAuthText),
              prefixIcon: const Icon(Icons.link, color: kAuthText),
              filled: true,
              fillColor: const Color(0xFFF0F4F4),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kAuthText),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: kAuthText),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: kAuthPrimary,
                  width: 1.5,
                ),
              ),
            ),
            onSubmitted: (_) => _start(),
          ),
          const SizedBox(height: 12),
          AuthPrimaryButton(
            label: "Mulai",
            showArrow: false,
            onPressed: _start,
          ),
        ],
      ),
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

  Widget _buildRecentForms() {
    if (_loading && _myForms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_myForms.isEmpty) {
      return _emptyCard(
        icon: Icons.description_outlined,
        message: 'Belum ada form. Ketuk + untuk membuat.',
      );
    }
    return Column(
      children: [
        for (final form in _myForms.take(3)) ...[
          _buildFormCard(form),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildFormCard(FormData form) {
    return FormCard(
      form: form,
      onTap: () => AppRouter.of(context).push(AppPage.formDetail, {
        'formId': form.id,
        'form': form,
      }),
      onQuickActions: () => showFormQuickActions(
        context,
        form,
        onChanged: () => _load(silent: true),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_loading && _myResponses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_myResponses.isEmpty) {
      return _emptyCard(
        icon: Icons.history,
        message: 'Belum ada aktivitas respons.',
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _myResponses.take(3).length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Colors.black12),
            _buildActivityItem(_myResponses[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItem(MyResponseItem item) {
    return InkWell(
      onTap: () => _openResponse(item),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F3F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF2A9D8F),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichTextView(
                          text: "Anda mengerjakan '${item.formTitle}'",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(item.submittedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (item.formLink.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Kode: ${item.formLink}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey, size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Baru saja';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    if (diff.inDays < 30) return '${diff.inDays} hari lalu';
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return "${local.day}/${local.month}/${local.year} $hh:$mm";
  }
}
