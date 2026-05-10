class Account {
  final String id;
  String name;
  String emoji;
  double balance;
  int color;

  Account({
    required this.id,
    required this.name,
    this.emoji = '🏦',
    this.balance = 0,
    this.color = 0xFF667eea,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'balance': balance,
        'color': color,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'],
        name: json['name'],
        emoji: json['emoji'] ?? '🏦',
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        color: json['color'] ?? 0xFF667eea,
      );
}
