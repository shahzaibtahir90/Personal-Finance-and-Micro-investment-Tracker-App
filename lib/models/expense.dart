class Expense {
  final int id; // bigint from database
  final String userId; // UUID from database
  final String category;
  final double amount; // numeric in database
  final DateTime date;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.userId,
    required this.category,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'category': category,
    'amount': amount,
    'date': date.toString().split(' ')[0], // Format: YYYY-MM-DD
  };

  @override
  String toString() =>
      'Expense(id: $id, userId: $userId, category: $category, amount: $amount, date: $date)';
}
