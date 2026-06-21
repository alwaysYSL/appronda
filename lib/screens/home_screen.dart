import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:appronda/services/auth_service.dart';
import 'package:appronda/services/firestore_service.dart';
import 'package:appronda/models/jadwal_ronda.dart';
import 'package:appronda/models/presensi.dart';
import 'package:appronda/models/laporan.dart';
import 'package:appronda/models/swap_request.dart';
import 'package:appronda/screens/form_jadwal_screen.dart';
import 'package:appronda/screens/buat_laporan_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ImagePicker _picker = ImagePicker();

  int _currentTab = 0;
  String _role = 'warga';
  bool _isLoadingRole = true;

  // State untuk check-in loading
  bool _isCheckingIn = false;

  // Sound URL untuk sirine alarm darurat
  final String _sirenAudioUrl = 'https://www.soundjay.com/buttons/beep-01a.mp3'; 
  bool _isAlarmPlaying = false;
  String? _myActiveAlertId;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    // Konfigurasi audio agar terus berulang saat alarm aktif
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
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

  // --- HELPER METODE LOKASI & TELEPON ---
  
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Layanan lokasi (GPS) dinonaktifkan di perangkat Anda.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Izin akses lokasi ditolak.';
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw 'Izin lokasi ditolak permanen. Silakan aktifkan di pengaturan browser.';
    } 

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Tidak dapat melakukan panggilan ke $phoneNumber';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
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

  // --- ACTIONS: CHECK-IN & PANIC & SWAP ---

  void _lakukanCheckIn(JadwalRonda jadwal, String userId, String userEmail) async {
    setState(() {
      _isCheckingIn = true;
    });

    try {
      // 1. Dapatkan Lokasi GPS
      double latitude = 0.0;
      double longitude = 0.0;
      bool locationSuccess = true;

      try {
        final Position position = await _determinePosition().timeout(const Duration(seconds: 4));
        latitude = position.latitude;
        longitude = position.longitude;
      } catch (e) {
        locationSuccess = false;
        debugPrint("Gagal mendapatkan lokasi GPS: $e");
      }

      // 2. Ambil Foto Kamera
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 20, // kompresi agar base64 muat di Firestore
      );

      if (photo == null) {
        setState(() {
          _isCheckingIn = false;
        });
        return; // Batal ambil foto
      }

      // 3. Konversi Foto ke Base64
      final bytes = await photo.readAsBytes();
      final String base64Image = base64Encode(bytes);

      // 4. Kirim ke Firestore
      await _firestoreService.checkIn(
        jadwal.id,
        userId,
        userEmail,
        latitude,
        longitude,
        base64Image,
      );

      if (mounted) {
        if (locationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Presensi Berhasil! Selamat bertugas.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Presensi Berhasil (tanpa koordinat GPS karena akses lokasi ditolak/timeout)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal Presensi: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  void _ajukanTukarJadwal(JadwalRonda jadwal, String userId, String userEmail) async {
    try {
      await _firestoreService.createSwapRequest(
        jadwal.id,
        jadwal.hari,
        jadwal.tanggal,
        jadwal.area,
        userId,
        userEmail,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permohonan tukar jadwal berhasil diajukan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _pemicuTombolPanik(String userId, String userEmail) async {
    try {
      // 1. Trigger panic alert in Firestore and store the document ID
      String alertId = await _firestoreService.triggerPanicAlert(userId, userEmail);
      _myActiveAlertId = alertId;
      
      setState(() {
        _isAlarmPlaying = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 ALARM DARURAT DIPICU!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }

      // 2. Play Audio siren - wrapped in try-catch so Web MissingPluginException doesn't crash the UI!
      try {
        await _audioPlayer.play(UrlSource(_sirenAudioUrl));
      } catch (audioError) {
        debugPrint("Gagal memutar audio: $audioError");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memicu tombol panik: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _matikanAlarmLokal() async {
    // 1. Stop audio player
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    
    // 2. Resolve alert in Firestore if we have the active ID
    if (_myActiveAlertId != null) {
      try {
        await _firestoreService.resolvePanicAlert(_myActiveAlertId!);
        _myActiveAlertId = null;
      } catch (_) {}
    }
    
    setState(() {
      _isAlarmPlaying = false;
    });
  }

  // --- TABS RENDERING ---

  // Tab 1: Jadwal & Check-in
  Widget _buildJadwalTab(List<JadwalRonda> jadwalList, String userId, String userEmail) {
    // Cari apakah ada jadwal user bertugas hari ini
    JadwalRonda? todayJadwal;
    final DateTime now = DateTime.now();
    for (var j in jadwalList) {
      final bool isSameDay = j.tanggal.year == now.year &&
          j.tanggal.month == now.month &&
          j.tanggal.day == now.day;
      final bool isUserPetugas = j.petugas.any(
          (p) => p.toLowerCase().trim() == userEmail.toLowerCase().trim());
      
      if (isSameDay && isUserPetugas) {
        todayJadwal = j;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tampilkan Check-in Card jika ada tugas hari ini
        if (todayJadwal != null) ...[
          StreamBuilder<List<Presensi>>(
            stream: _firestoreService.getPresensiStream(todayJadwal.id),
            builder: (context, snapshot) {
              final presensiList = snapshot.data ?? [];
              final hasCheckedIn = presensiList.any((p) => p.userId == userId);

              if (hasCheckedIn) {
                final myPresensi = presensiList.firstWhere((p) => p.userId == userId);
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.greenAccent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: Colors.greenAccent, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Anda Sudah Check-in',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Waktu: ${DateFormat('HH:mm').format(myPresensi.waktu)} WIB',
                              style: TextStyle(color: Colors.blueGrey[300]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0369A1), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyanAccent, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.2),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.stars_rounded, color: Colors.cyanAccent, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Tugas Anda Hari Ini!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hari ini Anda dijadwalkan ronda malam di area: ${todayJadwal!.area}. Silakan lakukan presensi kehadiran.',
                      style: TextStyle(color: Colors.blueGrey[100], fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isCheckingIn ? null : () => _lakukanCheckIn(todayJadwal!, userId, userEmail),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isCheckingIn 
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.camera_front_rounded, size: 20),
                      label: Text(
                        _isCheckingIn ? 'MEMPROSES...' : 'MULAI RONDA / CHECK-IN',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],

        const Text(
          'SEMUA JADWAL RONDA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        // List jadwal
        Expanded(
          child: ListView.separated(
            itemCount: jadwalList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final j = jadwalList[index];
              final bool isMyJadwal = j.petugas.any(
                  (p) => p.toLowerCase().trim() == userEmail.toLowerCase().trim());

              return Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMyJadwal ? Colors.cyanAccent.withValues(alpha: 0.5) : Colors.blueGrey[800]!,
                    width: isMyJadwal ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isMyJadwal ? Colors.cyanAccent.withValues(alpha: 0.1) : Colors.blueGrey[900],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isMyJadwal ? Colors.cyanAccent.withValues(alpha: 0.3) : Colors.blueGrey[800]!,
                              ),
                            ),
                            child: Text(
                              j.hari,
                              style: TextStyle(
                                color: isMyJadwal ? Colors.cyanAccent : Colors.blueGrey[300],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('dd MMMM yyyy').format(j.tanggal),
                            style: TextStyle(color: Colors.blueGrey[300], fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.pin_drop_rounded, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              j.area,
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
                      Text(
                        'Petugas Ronda:',
                        style: TextStyle(color: Colors.blueGrey[400], fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: j.petugas.map((nama) {
                          final isMe = nama.toLowerCase().trim() == userEmail.toLowerCase().trim();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.cyanAccent.withValues(alpha: 0.1) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isMe ? Colors.cyanAccent.withValues(alpha: 0.3) : Colors.blueGrey[800]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_rounded, color: isMe ? Colors.cyanAccent : Colors.blueGrey, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  isMe ? 'Anda ($nama)' : nama,
                                  style: TextStyle(
                                    color: isMe ? Colors.cyanAccent : Colors.white,
                                    fontSize: 13,
                                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      
                      // Warga Aksi: Ajukan Tukar Jadwal
                      if (isMyJadwal) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFF1E293B)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _ajukanTukarJadwal(j, userId, userEmail),
                            style: TextButton.styleFrom(foregroundColor: Colors.orangeAccent),
                            icon: const Icon(Icons.swap_horizontal_circle_outlined, size: 18),
                            label: const Text('Ajukan Tukar Jadwal'),
                          ),
                        ),
                      ],

                      // Admin Aksi: Edit & Hapus
                      if (_role == 'admin') ...[
                        const SizedBox(height: 8),
                        const Divider(color: Color(0xFF1E293B)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => FormJadwalScreen(jadwal: j)),
                                );
                              },
                              icon: const Icon(Icons.edit_rounded, color: Colors.cyanAccent, size: 18),
                              label: const Text('Edit', style: TextStyle(color: Colors.cyanAccent)),
                            ),
                            const SizedBox(width: 16),
                            TextButton.icon(
                              onPressed: () => _konfirmasiHapus(context, j),
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                              label: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Tab 2: Laporan Kejadian
  Widget _buildLaporanTab() {
    return StreamBuilder<List<Laporan>>(
      stream: _firestoreService.getLaporanStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Gagal memuat laporan: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final laporanList = snapshot.data ?? [];

        if (laporanList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.report_gmailerrorred_rounded, size: 80, color: Colors.blueGrey[600]),
                const SizedBox(height: 16),
                const Text(
                  'Belum ada laporan kejadian.',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gunakan tombol + di kanan bawah untuk membuat laporan.',
                  style: TextStyle(color: Colors.blueGrey[400], fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: laporanList.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final lap = laporanList[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueGrey[800]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Laporan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          lap.userEmail,
                          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM HH:mm').format(lap.timestamp),
                        style: TextStyle(color: Colors.blueGrey[400], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Deskripsi
                  Text(
                    lap.deskripsi,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  
                  // Image Render from Base64
                  if (lap.fotoBase64.isNotEmpty)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueGrey[900]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(
                          base64Decode(lap.fotoBase64),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Tab 3: Tukar Jadwal
  Widget _buildSwapTab(String userId, String userEmail) {
    return StreamBuilder<List<SwapRequest>>(
      stream: _firestoreService.getSwapRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Gagal memuat swap request: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horizontal_circle_outlined, size: 80, color: Colors.blueGrey[600]),
                const SizedBox(height: 16),
                const Text(
                  'Tidak ada pengajuan tukar jadwal.',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Warga yang bertugas bisa mengajukan tukar lewat Tab Jadwal.',
                  style: TextStyle(color: Colors.blueGrey[400], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: requests.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final req = requests[index];
            final bool isMyRequest = req.requesterId == userId;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueGrey[800]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isMyRequest ? 'Pengajuan Anda' : req.requesterEmail,
                          style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orangeAccent, width: 0.5),
                        ),
                        child: const Text(
                          'PENDING',
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Detail Jadwal yang ingin ditukar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Colors.blueGrey, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${req.hari}, ${DateFormat('dd MMMM yyyy').format(req.tanggal)}',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.pin_drop_rounded, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              req.area,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  if (!isMyRequest) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await _firestoreService.bantuRonda(req.id, userId, userEmail);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Berhasil menyetujui untuk bantu ronda! Jadwal terupdate.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent[400],
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('BANTU GANTIKAN RONDA', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Tab 4: Darurat & Panic Button
  Widget _buildDaruratTab(String userId, String userEmail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Panic Button Area
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blueGrey[800]!),
          ),
          child: Column(
            children: [
              const Text(
                'TOMBOL KEADAAN DARURAT',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Tekan tombol di bawah jika Anda menemui bahaya atau membutuhkan pertolongan segera saat ronda.',
                style: TextStyle(color: Colors.blueGrey[300], fontSize: 12, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Glowing Panic Button
              GestureDetector(
                onTap: _isAlarmPlaying 
                    ? _matikanAlarmLokal 
                    : () => _pemicuTombolPanik(userId, userEmail),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: _isAlarmPlaying ? Colors.amber[700] : Colors.red[600],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _isAlarmPlaying 
                            ? Colors.amberAccent.withValues(alpha: 0.6) 
                            : Colors.redAccent.withValues(alpha: 0.6),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isAlarmPlaying ? Icons.volume_off_rounded : Icons.campaign_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isAlarmPlaying ? 'MATIKAN\nSIRENE' : 'TOMBOL\nPANIK',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'KONTAK DARURAT RT/RW',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),

        // Emergency numbers
        Expanded(
          child: ListView(
            children: [
              _buildContactCard('Ketua RT 01 (Bapak Joko)', '081234567890', Icons.person),
              _buildContactCard('Ketua RW 05 (Bapak Ahmad)', '082345678901', Icons.person),
              _buildContactCard('Polsek Terdekat', '110', Icons.local_police),
              _buildContactCard('Pemadam Kebakaran', '113', Icons.fire_truck),
              _buildContactCard('Ambulans / RS', '118', Icons.medical_services),
              _buildContactCard('Pos Keamanan / Satpam', '083456789012', Icons.security),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(String name, String number, IconData icon) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.cyanAccent.withValues(alpha: 0.1),
          child: Icon(icon, color: Colors.cyanAccent),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(number, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.greenAccent),
          onPressed: () => _launchPhoneCall(number),
        ),
      ),
    );
  }

  // --- OVERLAY NOTIFICATION FOR PANIC ALERTS ---
  
  Widget _buildGlobalAlertOverlay() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getActiveAlertStream(),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];
        if (alerts.isEmpty) return const SizedBox.shrink();

        // Ambil alert pertama
        final activeAlert = alerts.first;
        final String alertId = activeAlert['id'];
        final String reporterEmail = activeAlert['userEmail'];

        return Container(
          width: double.infinity,
          color: Colors.red[900],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PANGGILAN DARURAT!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$reporterEmail membutuhkan bantuan!',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _firestoreService.resolvePanicAlert(alertId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red[900],
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('SELESAI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final String userEmail = user?.email ?? 'Pengguna';
    final String userId = user?.uid ?? '';

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
        child: Column(
          children: [
            // Alarm Overlay bahaya jika ada
            _buildGlobalAlertOverlay(),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0),
                child: _isLoadingRole
                    ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tab 0 & 4: Tampilkan header profile card
                          if (_currentTab == 0 || _currentTab == 3) ...[
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
                                    child: const Icon(Icons.person_rounded, color: Colors.cyanAccent, size: 30),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Selamat Datang,', style: TextStyle(color: Colors.blueGrey[400], fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                userEmail,
                                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _role == 'admin' 
                                                    ? Colors.redAccent.withValues(alpha: 0.1) 
                                                    : Colors.greenAccent.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: _role == 'admin' ? Colors.redAccent : Colors.greenAccent, width: 1),
                                              ),
                                              child: Text(
                                                _role.toUpperCase(),
                                                style: TextStyle(
                                                  color: _role == 'admin' ? Colors.redAccent : Colors.greenAccent,
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
                          ],

                          // Konten utama berdasarkan tab aktif
                          Expanded(
                            child: _currentTab == 0
                                ? StreamBuilder<List<JadwalRonda>>(
                                    stream: _firestoreService.getJadwalStream(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                                      }
                                      if (snapshot.hasError) {
                                        return Center(
                                          child: Text('Gagal memuat jadwal: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                                        );
                                      }
                                      final jList = snapshot.data ?? [];
                                      return _buildJadwalTab(jList, userId, userEmail);
                                    },
                                  )
                                : _currentTab == 1
                                    ? _buildLaporanTab()
                                    : _currentTab == 2
                                        ? _buildSwapTab(userId, userEmail)
                                        : _buildDaruratTab(userId, userEmail),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      
      // Floating Action Button khusus untuk tab Laporan & Admin pada Tab Jadwal
      floatingActionButton: !_isLoadingRole 
          ? (_currentTab == 0 && _role == 'admin')
              ? FloatingActionButton(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FormJadwalScreen()),
                    );
                  },
                  child: const Icon(Icons.add_rounded, size: 28),
                )
              : (_currentTab == 1) // FAB Laporan (+)
                  ? FloatingActionButton(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onPressed: () async {
                        final result = await showDialog(
                          context: context,
                          builder: (context) => const BuatLaporanDialog(),
                        );
                        if (result == true) {
                          // refresh (Firestore reactive, tidak perlu refresh manual)
                        }
                      },
                      child: const Icon(Icons.edit_note_rounded, size: 28),
                    )
                  : null
          : null,
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (index) {
          setState(() {
            _currentTab = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E293B), // Slate 800
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.blueGrey[400],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Jadwal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Laporan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horizontal_circle_outlined),
            label: 'Tukar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            label: 'Darurat',
          ),
        ],
      ),
    );
  }
}
