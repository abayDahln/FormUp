import 'package:flutter/material.dart';
import 'form_screen.dart';
import 'response_screen.dart';
import 'profile_screen.dart';
import 'auth_widgets.dart';
import 'rich_editor.dart';
import '../app_router.dart';
import '../services/auth_service.dart';
import '../services/form_service.dart';
import '../services/user_service.dart';

class _StatusStyle {
  final String label;
  final Color fg;
  final Color bg;
  const _StatusStyle(this.label, this.fg, this.bg);
}

_StatusStyle _statusStyle(String status) {
  switch (status) {
    case 'published':
      return const _StatusStyle('Terbit', Color(0xFF2E7D32), Color(0xFFE3F4E8));
    case 'draft':
      return const _StatusStyle('Draf', Color(0xFFB26A00), Color(0xFFFFF3DE));
    default:
      return const _StatusStyle('Ditutup', Color(0xFFC0392B), Color(0xFFFDE8E6));
  }
}

class HomeScreen extends StatefulWidget {
  final String username; // Menerima data nama dari inputan login/register

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Untuk navigasi bawah

  // ponytail: tab yang pernah dibuka. IndexedStack lazy — Form/Respons/Profil
  // hanya di-build saat pertama dikunjungi lalu state-nya dipertahankan,
  // jadi pindah tab tidak memicu fetch ulang dari nol.
  final Set<int> _visitedTabs = {0};

  UserStats? _stats;
  List<FormData> _myForms = [];
  List<MyResponseItem> _myResponses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        UserService.getStats(),
        FormService.getMyForms(),
        FormService.getMyResponses(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as UserStats;
        _myForms = results[1] as List<FormData>;
        _myResponses = results[2] as List<MyResponseItem>;
      });
    } catch (e) {
      if (!mounted) return;
      showAuthToast(context, AuthService.errorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _publishedPercent {
    final forms = _myForms;
    if (forms.isEmpty) return '0%';
    final published = forms.where((f) => f.status == 'published').length;
    return '${(published / forms.length * 100).round()}%';
  }

  void _openPreview(FormData form) {
    AppRouter.of(context).push(AppPage.formPreview, {'formId': form.id});
  }

  void _openResponse(MyResponseItem item) {
    AppRouter.of(context).push(AppPage.formHistoryDetail, {
      'formLink': item.formLink,
      'responseId': item.responseId,
    });
  }

  /// Tab Beranda: statistik + form terbaru + aktivitas respons.
  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _load,
      color: kAuthPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),

            _buildSearchBar(),
            const SizedBox(height: 20),

            _buildStatsRow(),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              label: 'Form',
            ),
            BottomNavigationBarItem(
              icon: SizedBox.shrink(),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Respons',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
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
        elevation: 2,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Halo, ${widget.username.isNotEmpty ? widget.username : 'Pengguna'}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: kFontBold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              "Inilah performa form Anda hari ini.",
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Color(0xFF2A9D8F),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFB8E2DE),
                shape: BoxShape.circle,
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _visitedTabs.add(4);
                    _currentIndex = 4;
                  });
                },
                customBorder: const CircleBorder(),
                child: Center(
                  child: Text(
                    widget.username.isNotEmpty
                        ? widget.username[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: kFontBold,
                      color: Color(0xFF2A9D8F),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: softShadow(),
      ),
      child: TextField(
        readOnly: true,
        onTap: () {
          AppRouter.of(context).push(AppPage.formRunner);
        },
        decoration: const InputDecoration(
          icon: Icon(Icons.search, color: Colors.grey),
          hintText: "Masukkan kode form untuk mengerjakan...",
          hintStyle: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = _stats;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Total Form",
            stats == null ? '…' : '${stats.totalForms}',
            Icons.description_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            "Total Respons",
            stats == null ? '…' : '${stats.totalResponses}',
            Icons.people_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            "Terbit",
            stats == null ? '…' : _publishedPercent,
            Icons.star_border,
          ),
        ),
      ],
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
    final style = _statusStyle(form.status);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(kRadius),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: () => _openPreview(form),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F3F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Color(0xFF2A9D8F),
                      size: 20,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: style.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          style.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            color: style.fg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RichTextView(
                text: form.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: kFontBold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${form.responseCount} respons',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 15),
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(form.updatedAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2A9D8F), size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: kFontBold,
              color: Colors.black87,
            ),
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
