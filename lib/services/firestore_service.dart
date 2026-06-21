import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appronda/models/jadwal_ronda.dart';
import 'package:appronda/models/presensi.dart';
import 'package:appronda/models/laporan.dart';
import 'package:appronda/models/swap_request.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- USER PROFILE & ROLE OPERATIONS ---
  
  // Create user profile in Firestore
  Future<void> createUserProfile(String uid, String email, String role) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Gagal membuat profil pengguna: $e';
    }
  }

  // Get user role by UID
  Future<String> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        return data['role'] ?? 'warga';
      }
      return 'warga';
    } catch (e) {
      return 'warga'; // fallback to default role
    }
  }

  // --- JADWAL RONDA CRUD OPERATIONS ---

  // Stream schedules sorted by date ascending
  Stream<List<JadwalRonda>> getJadwalStream() {
    return _db
        .collection('jadwal')
        .orderBy('tanggal', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => JadwalRonda.fromDocument(doc)).toList();
        });
  }

  // Create a new schedule
  Future<void> addJadwal(String hari, DateTime tanggal, String area, List<String> petugas) async {
    try {
      await _db.collection('jadwal').add({
        'hari': hari,
        'tanggal': Timestamp.fromDate(tanggal),
        'area': area,
        'petugas': petugas,
      });
    } catch (e) {
      throw 'Gagal menambahkan jadwal ronda: $e';
    }
  }

  // Update an existing schedule
  Future<void> updateJadwal(String id, String hari, DateTime tanggal, String area, List<String> petugas) async {
    try {
      await _db.collection('jadwal').doc(id).update({
        'hari': hari,
        'tanggal': Timestamp.fromDate(tanggal),
        'area': area,
        'petugas': petugas,
      });
    } catch (e) {
      throw 'Gagal memperbarui jadwal ronda: $e';
    }
  }

  // Delete a schedule
  Future<void> deleteJadwal(String id) async {
    try {
      await _db.collection('jadwal').doc(id).delete();
    } catch (e) {
      throw 'Gagal menghapus jadwal ronda: $e';
    }
  }

  // --- ABSENSI / PRESENSY RONDA (CHECK-IN) ---

  // Save presence check-in record
  Future<void> checkIn(String jadwalId, String userId, String userEmail, double latitude, double longitude, String fotoBase64) async {
    try {
      await _db.collection('presensi').add({
        'jadwalId': jadwalId,
        'userId': userId,
        'userEmail': userEmail,
        'waktu': FieldValue.serverTimestamp(),
        'latitude': latitude,
        'longitude': longitude,
        'fotoBase64': fotoBase64,
      });
    } catch (e) {
      throw 'Gagal melakukan check-in absensi: $e';
    }
  }

  // Stream presence check-ins for a specific schedule
  Stream<List<Presensi>> getPresensiStream(String jadwalId) {
    return _db
        .collection('presensi')
        .where('jadwalId', isEqualTo: jadwalId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => Presensi.fromDocument(doc)).toList();
          // Sort locally since Compound Queries without Index in Firestore throws error.
          list.sort((a, b) => b.waktu.compareTo(a.waktu));
          return list;
        });
  }

  // --- LAPORAN KEJADIAN / PATROL LOG ---

  // Submit a patrol incident report
  Future<void> addLaporan(String userId, String userEmail, String deskripsi, String fotoBase64) async {
    try {
      await _db.collection('laporan').add({
        'userId': userId,
        'userEmail': userEmail,
        'deskripsi': deskripsi,
        'fotoBase64': fotoBase64,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'Gagal mengirim laporan kejadian: $e';
    }
  }

  // Stream patrol log reports, ordered by latest first
  Stream<List<Laporan>> getLaporanStream() {
    return _db
        .collection('laporan')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Laporan.fromDocument(doc)).toList();
        });
  }

  // --- TUKAR JADWAL (SCHEDULE SWAP) ---

  // Create a schedule swap request
  Future<void> createSwapRequest(String jadwalId, String hari, DateTime tanggal, String area, String requesterId, String requesterEmail) async {
    try {
      // Check if a request already exists for this schedule and is still pending
      final existing = await _db
          .collection('swap_requests')
          .where('jadwalId', isEqualTo: jadwalId)
          .where('status', isEqualTo: 'pending')
          .get();
          
      if (existing.docs.isNotEmpty) {
        throw 'Pertukaran jadwal untuk slot ini sudah diajukan.';
      }

      await _db.collection('swap_requests').add({
        'jadwalId': jadwalId,
        'hari': hari,
        'tanggal': Timestamp.fromDate(tanggal),
        'area': area,
        'requesterId': requesterId,
        'requesterEmail': requesterEmail,
        'status': 'pending',
        'helperId': '',
        'helperEmail': '',
      });
    } catch (e) {
      throw e.toString();
    }
  }

  // Stream all pending schedule swap requests
  Stream<List<SwapRequest>> getSwapRequestsStream() {
    return _db
        .collection('swap_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('tanggal', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => SwapRequest.fromDocument(doc)).toList();
        });
  }

  // Help a citizen swap schedule (accept the request)
  Future<void> bantuRonda(String requestId, String helperId, String helperEmail) async {
    try {
      // 1. Get swap request details
      DocumentSnapshot requestDoc = await _db.collection('swap_requests').doc(requestId).get();
      if (!requestDoc.exists) throw 'Pengajuan pertukaran tidak ditemukan.';
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      String jadwalId = requestData['jadwalId'];
      String requesterEmail = requestData['requesterEmail'];

      // 2. Update status of swap request
      await _db.collection('swap_requests').doc(requestId).update({
        'status': 'accepted',
        'helperId': helperId,
        'helperEmail': helperEmail,
      });

      // 3. Find and update the original schedule petugas
      DocumentSnapshot jadwalDoc = await _db.collection('jadwal').doc(jadwalId).get();
      if (jadwalDoc.exists) {
        final jadwalData = jadwalDoc.data() as Map<String, dynamic>;
        List<String> petugas = List<String>.from(jadwalData['petugas'] ?? []);
        
        // Find requester and replace with helper
        int reqIndex = petugas.indexOf(requesterEmail);
        if (reqIndex != -1) {
          petugas[reqIndex] = helperEmail;
        } else {
          // If exact match not found, try containing/fuzzy match
          int fuzzyIndex = petugas.indexWhere((p) => p.toLowerCase().contains(requesterEmail.split('@')[0].toLowerCase()));
          if (fuzzyIndex != -1) {
            petugas[fuzzyIndex] = helperEmail;
          } else {
            // Fallback: append helper
            petugas.add(helperEmail);
          }
        }

        // Update database
        await _db.collection('jadwal').doc(jadwalId).update({
          'petugas': petugas,
        });
      }
    } catch (e) {
      throw 'Gagal mengambil alih jadwal ronda: $e';
    }
  }

  // --- PANIC BUTTON / EMERGENCY ALERTS ---

  // Trigger emergency alarm
  Future<String> triggerPanicAlert(String userId, String userEmail) async {
    try {
      DocumentReference docRef = await _db.collection('alerts').add({
        'userId': userId,
        'userEmail': userEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      return docRef.id;
    } catch (e) {
      throw 'Gagal memicu alarm darurat: $e';
    }
  }

  // Stream active panic alerts
  Stream<List<Map<String, dynamic>>> getActiveAlertStream() {
    return _db
        .collection('alerts')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => {
            'id': doc.id,
            'userId': doc.get('userId') ?? '',
            'userEmail': doc.get('userEmail') ?? '',
            'status': doc.get('status') ?? '',
          }).toList();
        });
  }

  // Resolve emergency alarm
  Future<void> resolvePanicAlert(String alertId) async {
    try {
      await _db.collection('alerts').doc(alertId).update({
        'status': 'resolved',
      });
    } catch (e) {
      throw 'Gagal menonaktifkan alarm: $e';
    }
  }

  // Get list of all registered user emails
  Future<List<String>> getAllUserEmails() async {
    try {
      QuerySnapshot snapshot = await _db.collection('users').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        return data['email'] as String? ?? '';
      }).where((email) => email.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }
}
