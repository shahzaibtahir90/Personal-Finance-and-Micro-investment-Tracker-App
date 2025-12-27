import 'package:flutter/material.dart';

// Helper map to convert string icon names from the database into actual Flutter IconData
final Map<String, IconData> _iconMap = {
  'work': Icons.work,
  'shopping_bag': Icons.shopping_bag,
  'payments': Icons.payments,
  'business_center': Icons.business_center,
  'attach_money': Icons.attach_money,
  'fastfood': Icons.fastfood,
  'food_bank': Icons.food_bank, // Added a common icon
  'local_gas_station': Icons.local_gas_station, // Added a common icon
  // Add more icons as needed for your transaction types
};

class Transaction {
  final int id; // bigint in database
  final String userId; // uuid in database
  final String title;
  final double amount; // numeric in database
  final String type; // 'Income' or 'Expense'
  final String? iconName; // icon_name from database
  final IconData icon; // Resolved IconData
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.type,
    this.iconName,
    required this.icon,
    required this.createdAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    final iconName = map['icon_name'] as String?;
    return Transaction(
      id: map['id'] as int,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      iconName: iconName,
      // Safely look up the IconData, defaulting to a generic icon if not found
      icon: _iconMap[iconName] ?? Icons.monetization_on,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert Transaction to a map for database operations
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'title': title,
      'amount': amount,
      'type': type,
      'icon_name': iconName,
    };
  }
}
