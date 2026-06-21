import 'package:cloud_firestore/cloud_firestore.dart';

class JadwalRonda {
  final String id;
  final String hari;
  final DateTime tanggal;
  final String area;
  final List<String> petugas;

  JadwalRonda({
    required this.id,
    required this.hari,
    required this.tanggal,
    required this.area,
    required this.petugas,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'hari': hari,
      'tanggal': Timestamp.fromDate(tanggal),
      'area': area,
      'petugas': petugas,
    };
  }

  // Create instance from Firestore DocumentSnapshot
  factory JadwalRonda.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // Safety check for casting dynamic list to List<String>
    List<String> petugasList = [];
    if (data['petugas'] != null) {
      petugasList = List<String>.from(data['petugas']);
    }

    // Safety check for DateTime from Timestamp
    DateTime dateVal = DateTime.now();
    if (data['tanggal'] != null) {
      if (data['tanggal'] is Timestamp) {
        dateVal = (data['tanggal'] as Timestamp).toDate();
      } else if (data['tanggal'] is String) {
        dateVal = DateTime.parse(data['tanggal']);
      }
    }

    return JadwalRonda(
      id: doc.id,
      hari: data['hari'] ?? '',
      tanggal: dateVal,
      area: data['area'] ?? '',
      petugas: petugasList,
    );
  }
}
