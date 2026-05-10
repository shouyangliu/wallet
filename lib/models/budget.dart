class Budget {
  double totalLimit;
  String emoji;
  int color;

  Budget({required this.totalLimit, this.emoji = '💰', this.color = 0xFF667eea});

  Map<String, dynamic> toJson() => {
        'totalLimit': totalLimit,
        'emoji': emoji,
        'color': color,
      };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        totalLimit: (json['totalLimit'] as num).toDouble(),
        emoji: json['emoji'] ?? '💰',
        color: json['color'] ?? 0xFF667eea,
      );
}
