import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:appronda/services/auth_service.dart';
import 'package:appronda/services/firestore_service.dart';
import 'package:appronda/models/jadwal_ronda.dart';
import 'package:appronda/screens/form_jadwal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  
  String _role = 'warga';
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        String role = await _firestoreService.getUserRole(user.uid);
        if (mounted) {
          setState(() {
            _role = role;
            _isLoadingRole = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingRole = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingRole = false;
        });
      }
    }
  }

  void _konfirmasiHapus(BuildContext context, JadwalRonda jadwal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Hapus Jadwal', style: TextStyle(color: Colors.white)),
        content: Text(
          'Apakah Anda yakin ingin menghapus jadwal ronda hari ${jadwal.hari} (${DateFormat('dd MMMM yyyy').format(jadwal.tanggal)})?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.deleteJadwal(jadwal.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Jadwal ronda berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus jadwal: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJadwalList() {
    return StreamBuilder<List<JadwalRonda>>(
      stream: _firestoreService.getJadwalStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Gagal memuat jadwal: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final jadwalList = snapshot.data ?? [];

        if (jadwalList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 80,
                  color: Colors.cyanAccent.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Belum Ada Jadwal Ronda',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    _role == 'admin'
                        ? 'Silakan tekan tombol "+" di bawah untuk membuat jadwal ronda malam.'
                        : 'Hubungi pengurus RT/RW (Admin) untuk menambahkan jadwal ronda baru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey[400]),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: jadwalList.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final jadwal = jadwalList[index];
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueGrey[800]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Hari & Tanggal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.cyanAccent.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            jadwal.hari,
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          DateFormat('dd MMMM yyyy').format(jadwal.tanggal),
                          style: TextStyle(
                            color: Colors.blueGrey[300],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Area / Pos Ronda
                    Row(
                      children: [
                        const Icon(Icons.pin_drop_rounded,
                            color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            jadwal.area,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Petugas Title
                    Text(
                      'Petugas Ronda:',
                      style: TextStyle(
                        color: Colors.blueGrey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Petugas Wrap Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: jadwal.petugas.map((nama) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueGrey[800]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_rounded,
                                  color: Colors.cyanAccent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                nama,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    // Admin Actions (Edit/Delete)
                    if (_role == 'admin') ...[
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF1E293B)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      FormJadwalScreen(jadwal: jadwal),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_rounded,
                                color: Colors.cyanAccent, size: 18),
                            label: const Text(
                              'Edit',
                              style: TextStyle(color: Colors.cyanAccent),
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: () => _konfirmasiHapus(context, jadwal),
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.redAccent, size: 18),
                            label: const Text(
                              'Hapus',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

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
                    style: TextStyle(color: Colors.grey),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      child: const Text('Keluar', style: TextStyle(color: Colors.white)),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _authService.signOut();
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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueGrey[800]!),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.cyanAccent.withValues(alpha: 0.1),
                      child: const Icon(Icons.person_rounded,
                          color: Colors.cyanAccent, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat Datang,',
                            style: TextStyle(
                                color: Colors.blueGrey[400], fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          if (_isLoadingRole)
                            const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.cyanAccent,
                              ),
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user?.email ?? 'Pengguna',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _role == 'admin'
                                        ? Colors.redAccent.withValues(alpha: 0.1)
                                        : Colors.greenAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _role == 'admin'
                                          ? Colors.redAccent
                                          : Colors.greenAccent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _role.toUpperCase(),
                                    style: TextStyle(
                                      color: _role == 'admin'
                                          ? Colors.redAccent
                                          : Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'JADWAL RONDA MALAM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              // Jadwal List
              Expanded(
                child: _isLoadingRole
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.cyanAccent),
                      )
                    : _buildJadwalList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: (!_isLoadingRole && _role == 'admin')
          ? FloatingActionButton(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FormJadwalScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }
}
