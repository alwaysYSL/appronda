import 'package:cloud_firestore/cloud_firestore.dart';

class Presensi {
  final String id;
  final String jadwalId;
  final String userId;
  final String userEmail;
  final DateTime waktu;
  final double latitude;
  final double longitude;
  final String fotoBase64;

  Presensi({
    required this.id,
    required this.jadwalId,
    required this.userId,
    required this.userEmail,
    required this.waktu,
    required this.latitude,
    required this.longitude,
    required this.fotoBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'jadwalId': jadwalId,
      'userId': userId,
      'userEmail': userEmail,
      'waktu': Timestamp.fromDate(waktu),
      'latitude': latitude,
      'longitude': longitude,
      'fotoBase64': fotoBase64,
    };
  }

  factory Presensi.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    DateTime timeVal = DateTime.now();
    if (data['waktu'] != null) {
      if (data['waktu'] is Timestamp) {
        timeVal = (data['waktu'] as Timestamp).toDate();
      } else if (data['waktu'] is String) {
        timeVal = DateTime.parse(data['waktu']);
      }
    }

    return Presensi(
      id: doc.id,
      jadwalId: data['jadwalId'] ?? '',
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      waktu: timeVal,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      fotoBase64: data['fotoBase64'] ?? '',
    );
  }
}
