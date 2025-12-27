class Consultation {
  final int id; // bigint from database
  final String userId; // UUID from database
  final String consultantId; // UUID from database
  final String message;
  final DateTime date;
  final DateTime createdAt;

  Consultation({
    required this.id,
    required this.userId,
    required this.consultantId,
    required this.message,
    required this.date,
    required this.createdAt,
  });

  factory Consultation.fromMap(Map<String, dynamic> map) {
    return Consultation(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      consultantId: map['consultant_id'] as String,
      message: map['message'] as String,
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'consultant_id': consultantId,
    'message': message,
    'date': date.toString().split(' ')[0], // Format: YYYY-MM-DD
  };

  @override
  String toString() =>
      'Consultation(id: $id, userId: $userId, consultantId: $consultantId, message: $message, date: $date)';
}
