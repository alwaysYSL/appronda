import 'package:flutter/material.dart';
import 'package:appronda/services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        title: const Row(
          children: [
            Icon(Icons.nights_stay_rounded, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text(
              'JamMalam',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () async {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text('Keluar Akun', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    'Apakah Anda yakin ingin keluar dari aplikasi?',
                    style: TextStyle(color: Colors.slate),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Batal', style: TextStyle(color: Colors.slate)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      child: const Text('Keluar', style: TextStyle(color: Colors.white)),
                      onPressed: () async {
                        Navigator.pop(context);
                        await authService.signOut();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        elevation: 2,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User info card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.slate[800]!),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.cyanAccent.withOpacity(0.1),
                      child: const Icon(Icons.person_rounded, color: Colors.cyanAccent, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat Datang,',
                            style: TextStyle(color: Colors.slate[400], fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'Pengguna',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Placeholder for CRUD ronda schedule
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 100,
                      color: Colors.cyanAccent.withOpacity(0.3),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Fase 2 Berhasil!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Autentikasi Firebase telah terhubung sepenuhnya.\nFitur CRUD Jadwal Ronda malam akan dibangun pada Fase 3.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.slate[400],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
