import 'package:flutter/material.dart';
import 'form_screen.dart';
import 'response_screen.dart';
import 'profile_screen.dart';
import 'auth_widgets.dart';
import '../app_router.dart';

class HomeScreen extends StatefulWidget {
  final String username; // Menerima data nama dari inputan login/register

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Untuk navigasi bawah

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      // BODY BISA DI-SCROLL KE BAWAH
      body: AuthBackground(
        child: SafeArea(
          child: KeyedSubtree(
            key: ValueKey(_currentIndex),
            child: switch (_currentIndex) {
                1 => const FormScreen(),
                3 => const ResponseScreen(),
                4 => ProfileScreen(username: widget.username),
                _ => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 15.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. HEADER (Sapaan & Ikon)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Selamat Pagi, ${widget.username.isNotEmpty ? widget.username : 'Pengguna'}",
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
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
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
                                    setState(() => _currentIndex = 4);
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
                      ),
                      const SizedBox(height: 20),

                      // 2. SEARCH BAR — ketuk untuk kerjakan form via kode
                      Container(
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
                      ),
                      const SizedBox(height: 20),

                      // 3. KOTAK STATISTIK (3 Kolom)
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              "Total Form",
                              "24",
                              Icons.description_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStatCard(
                              "Total Respons",
                              "1.2k",
                              Icons.people_outline,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStatCard(
                              "Terbit",
                              "88%",
                              Icons.star_border,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // 4. RECENT FORMS HEADER
                      Row(
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
                          Text(
                            "Lihat semua",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: kFontBold,
                              color: Color(0xFF2A9D8F),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // KARTU FORM 1
                      _buildFormCard(
                        title: "Survey Kepuasan Pelanggan 2024",
                        status: "TERBIT",
                        statusColor: const Color(0xFF2A9D8F),
                        statusBg: const Color(0xFFE2F3F2),
                        responses: "142 respons",
                        time: "2 hari lalu",
                      ),
                      const SizedBox(height: 12),

                      // KARTU FORM 2
                      _buildFormCard(
                        title: "Pendaftaran Acara - Workshop Q4",
                        status: "DRAF",
                        statusColor: Colors.grey,
                        statusBg: Colors.grey.shade200,
                        responses: "0 respons",
                        time: "5 jam lalu",
                      ),
                      const SizedBox(height: 25),

                      // 5. RECENT RESPONSE ACTIVITY
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

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildActivityItem(
                              "Sarah J. mengirim 'Survey Kepuasan'",
                              "\"Menyukai proses checkout yang cepat!\"",
                              "12 menit lalu",
                              const Color(0xFFE2F3F2),
                              const Color(0xFF2A9D8F),
                              Icons.person,
                            ),
                            const Divider(height: 1, color: Colors.black12),
                            _buildActivityItem(
                              "Mark T. mendaftar 'Workshop Q4'",
                              "Tiket Masuk Standar",
                              "1 jam lalu",
                              const Color(0xFFE2F3F2),
                              const Color(0xFF2A9D8F),
                              Icons.person_add_outlined,
                            ),
                            const Divider(height: 1, color: Colors.black12),
                            _buildActivityItem(
                              "Alex W. mengirim 'Survey Kepuasan'",
                              "",
                              "3 jam lalu",
                              Colors.orange.shade50,
                              Colors.orange,
                              Icons.person_outline,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 30,
                      ), // Spasi bawah agar tidak tertutup nav bar
                    ],
                  ),
                ),
              },
            ),
          ),
      ),

      // BOTTOM NAVIGATION BAR (Tetap Stay / Tidak Ikut Scroll)
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
              label: 'Form Saya',
            ),
            BottomNavigationBarItem(
              icon:
                  SizedBox.shrink(), // Dikosongkan karena tengah ada tombol plus
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

      // TOMBOL PLUS (FLOATING ACTION BUTTON) DI TENGAH NAVIGATION BAR
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

  // Widget Kotak Statistik
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

  // Widget Kartu Form
  Widget _buildFormCard({
    required String title,
    required String status,
    required Color statusColor,
    required Color statusBg,
    required String responses,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadius),
        boxShadow: softShadow(),
      ),
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
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: kFontBold,
                        color: statusColor,
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
          Text(
            title,
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
                responses,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 15),
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: Color(0xFF2A9D8F),
                  ),
                  label: const Text(
                    "Edit Desain",
                    style: TextStyle(fontSize: 12, color: Color(0xFF2A9D8F)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2A9D8F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.show_chart,
                    size: 14,
                    color: Color(0xFF2A9D8F),
                  ),
                  label: const Text(
                    "Analitik",
                    style: TextStyle(fontSize: 12, color: Color(0xFF2A9D8F)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2A9D8F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget Item Aktivitas
  Widget _buildActivityItem(
    String title,
    String subtitle,
    String time,
    Color iconBg,
    Color iconColor,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
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
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: kFontBold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
