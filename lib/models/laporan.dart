import 'package:cloud_firestore/cloud_firestore.dart';

class Laporan {
  final String id;
  final String userId;
  final String userEmail;
  final String deskripsi;
  final String fotoBase64;
  final DateTime timestamp;

  Laporan({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.deskripsi,
    required this.fotoBase64,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'deskripsi': deskripsi,
      'fotoBase64': fotoBase64,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory Laporan.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime timeVal = DateTime.now();
    if (data['timestamp'] != null) {
      if (data['timestamp'] is Timestamp) {
        timeVal = (data['timestamp'] as Timestamp).toDate();
      } else if (data['timestamp'] is String) {
        timeVal = DateTime.parse(data['timestamp']);
      }
    }

    return Laporan(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      deskripsi: data['deskripsi'] ?? '',
      fotoBase64: data['fotoBase64'] ?? '',
      timestamp: timeVal,
    );
  }
}
