class Transaction {
  final String id;
  double amount;
  String category;
  String emoji;
  String note;
  final DateTime date;
  bool isExpense;
  String accountId;

  Transaction({
    required this.id,
    required this.amount,
    required this.category,
    this.emoji = '',
    this.note = '',
    required this.date,
    required this.isExpense,
    this.accountId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category,
        'emoji': emoji,
        'note': note,
        'date': date.toIso8601String(),
        'isExpense': isExpense,
        'accountId': accountId,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'],
        amount: json['amount'],
        category: json['category'],
        emoji: json['emoji'] ?? '',
        note: json['note'] ?? '',
        date: DateTime.parse(json['date']),
        isExpense: json['isExpense'],
        accountId: json['accountId'] ?? '',
      );
}
