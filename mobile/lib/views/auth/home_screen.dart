import 'package:flutter/material.dart';
import '../form_maker_screen.dart';
import 'profile_screen.dart';
import 'widgets/auth_widgets.dart';

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
      backgroundColor: const Color(0xFFE2F3F2),
      // BODY BISA DI-SCROLL KE BAWAH
      body: SafeArea(
        child: _currentIndex == 4
            ? ProfileScreen(username: widget.username)
            : SingleChildScrollView(
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
                              "Good Morning, ${widget.username.isNotEmpty ? widget.username : 'User'}",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: kFontBold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Here's how your forms perform today.",
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
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileScreen(
                                        username: widget.username,
                                      ),
                                    ),
                                  );
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

                    // 2. SEARCH BAR
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          icon: Icon(Icons.search, color: Colors.grey),
                          hintText: "Search forms, responses...",
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
                            "Total Forms",
                            "24",
                            Icons.description_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            "Total Responses",
                            "1.2k",
                            Icons.people_outline,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            "Published",
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
                          "Recent Forms",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: kFontBold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          "View all",
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
                      title: "Customer Feedback Survey 2024",
                      status: "PUBLISHED",
                      statusColor: const Color(0xFF2A9D8F),
                      statusBg: const Color(0xFFE2F3F2),
                      responses: "142 responses",
                      time: "2d ago",
                    ),
                    const SizedBox(height: 12),

                    // KARTU FORM 2
                    _buildFormCard(
                      title: "Event Registration - Q4 Workshop",
                      status: "DRAFT",
                      statusColor: Colors.grey,
                      statusBg: Colors.grey.shade200,
                      responses: "0 responses",
                      time: "5h ago",
                    ),
                    const SizedBox(height: 25),

                    // 5. RECENT RESPONSE ACTIVITY
                    const Text(
                      "Recent Response Activity",
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
                            "Sarah J. submitted 'Feedback Survey'",
                            "\"Loved the quick checkout process!\"",
                            "12m ago",
                            const Color(0xFFE2F3F2),
                            const Color(0xFF2A9D8F),
                            Icons.person,
                          ),
                          const Divider(height: 1, color: Colors.black12),
                          _buildActivityItem(
                            "Mark T. registered for 'Q4 Workshop'",
                            "Standard Entry Ticket",
                            "1h ago",
                            const Color(0xFFE2F3F2),
                            const Color(0xFF2A9D8F),
                            Icons.person_add_outlined,
                          ),
                          const Divider(height: 1, color: Colors.black12),
                          _buildActivityItem(
                            "Alex W. submitted 'Feedback Survey'",
                            "",
                            "3h ago",
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
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2A9D8F),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description_outlined),
              label: 'My Forms',
            ),
            BottomNavigationBarItem(
              icon:
                  SizedBox.shrink(), // Dikosongkan karena tengah ada tombol plus
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'Responses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),

      // TOMBOL PLUS (FLOATING ACTION BUTTON) DI TENGAH NAVIGATION BAR
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FormMakerScreen()),
          );
        },
        backgroundColor: const Color(0xFF2A9D8F),
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
        borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
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
                    "Edit Design",
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
                    "Analytics",
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
