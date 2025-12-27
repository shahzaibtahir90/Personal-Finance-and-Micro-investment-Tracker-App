class Investment {
  final int id; // bigint from database
  final String userId; // UUID from database
  final String investmentType;
  final double amount;
  final double rate;
  final String period;
  final double profit;
  final DateTime createdAt;

  Investment({
    required this.id,
    required this.userId,
    required this.investmentType,
    required this.amount,
    required this.rate,
    required this.period,
    required this.profit,
    required this.createdAt,
  });

  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      investmentType: map['investment_type'] as String,
      amount: (map['amount'] as num).toDouble(),
      rate: (map['rate'] as num).toDouble(),
      period: map['period'] as String,
      profit: (map['profit'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'investment_type': investmentType,
    'amount': amount,
    'rate': rate,
    'period': period,
    'profit': profit,
  };

  @override
  String toString() =>
      'Investment(id: $id, userId: $userId, type: $investmentType, amount: $amount, rate: $rate, period: $period, profit: $profit)';
}
