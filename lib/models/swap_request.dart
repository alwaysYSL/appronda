import 'package:cloud_firestore/cloud_firestore.dart';

class SwapRequest {
  final String id;
  final String jadwalId;
  final String hari;
  final DateTime tanggal;
  final String area;
  final String requesterId;
  final String requesterEmail;
  final String status; // 'pending' | 'accepted'
  final String helperId;
  final String helperEmail;

  SwapRequest({
    required this.id,
    required this.jadwalId,
    required this.hari,
    required this.tanggal,
    required this.area,
    required this.requesterId,
    required this.requesterEmail,
    required this.status,
    required this.helperId,
    required this.helperEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'jadwalId': jadwalId,
      'hari': hari,
      'tanggal': Timestamp.fromDate(tanggal),
      'area': area,
      'requesterId': requesterId,
      'requesterEmail': requesterEmail,
      'status': status,
      'helperId': helperId,
      'helperEmail': helperEmail,
    };
  }

  factory SwapRequest.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime dateVal = DateTime.now();
    if (data['tanggal'] != null) {
      if (data['tanggal'] is Timestamp) {
        dateVal = (data['tanggal'] as Timestamp).toDate();
      } else if (data['tanggal'] is String) {
        dateVal = DateTime.parse(data['tanggal']);
      }
    }

    return SwapRequest(
      id: doc.id,
      jadwalId: data['jadwalId'] ?? '',
      hari: data['hari'] ?? '',
      tanggal: dateVal,
      area: data['area'] ?? '',
      requesterId: data['requesterId'] ?? '',
      requesterEmail: data['requesterEmail'] ?? '',
      status: data['status'] ?? 'pending',
      helperId: data['helperId'] ?? '',
      helperEmail: data['helperEmail'] ?? '',
    );
  }
}
