class Category {
  final String name;
  final String emoji;
  final bool isExpense;
  int color;

  Category({required this.name, this.emoji = '', required this.isExpense, this.color = 0xFF667eea});

  Map<String, dynamic> toJson() => {
        'name': name,
        'emoji': emoji,
        'isExpense': isExpense,
        'color': color,
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        name: json['name'],
        emoji: json['emoji'] ?? '',
        isExpense: json['isExpense'],
        color: json['color'] ?? 0xFF667eea,
      );
}
