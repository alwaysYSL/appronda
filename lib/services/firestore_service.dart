import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:appronda/models/jadwal_ronda.dart';

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
}
