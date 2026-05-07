import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'yl记账',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF667eea)),
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Transaction {
  final String id;
  final double amount;
  final String category;
  final String emoji;
  final String note;
  final DateTime date;
  final bool isExpense;

  Transaction({
    required this.id,
    required this.amount,
    required this.category,
    this.emoji = '',
    this.note = '',
    required this.date,
    required this.isExpense,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'category': category,
    'emoji': emoji,
    'note': note,
    'date': date.toIso8601String(),
    'isExpense': isExpense,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'],
    amount: json['amount'],
    category: json['category'],
    emoji: json['emoji'] ?? '',
    note: json['note'] ?? '',
    date: DateTime.parse(json['date']),
    isExpense: json['isExpense'],
  );
}

class Category {
  final String name;
  final String emoji;
  final bool isExpense;

  Category({required this.name, this.emoji = '', required this.isExpense});

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    'isExpense': isExpense,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    name: json['name'],
    emoji: json['emoji'] ?? '',
    isExpense: json['isExpense'],
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Transaction> _transactions = [];
  List<Category> _expenseCategories = [];
  List<Category> _incomeCategories = [];
  int _currentIndex = 0;
  String _statsType = 'month';
  int _statsYear = DateTime.now().year;
  int _statsMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final txJson = prefs.getString('transactions');
    final catJson = prefs.getString('categories');

    setState(() {
      if (txJson != null) {
        _transactions =
            (jsonDecode(txJson) as List).map((e) => Transaction.fromJson(e)).toList();
      }
      if (catJson != null) {
        final cats =
            (jsonDecode(catJson) as List).map((e) => Category.fromJson(e)).toList();
        _expenseCategories = cats.where((c) => c.isExpense).toList();
        _incomeCategories = cats.where((c) => !c.isExpense).toList();
      } else {
        _expenseCategories = [
          Category(name: '餐饮', emoji: '🍜', isExpense: true),
          Category(name: '交通', emoji: '🚗', isExpense: true),
          Category(name: '购物', emoji: '🛒', isExpense: true),
          Category(name: '娱乐', emoji: '🎮', isExpense: true),
          Category(name: '住房', emoji: '🏠', isExpense: true),
          Category(name: '其他', emoji: '📦', isExpense: true),
        ];
        _incomeCategories = [
          Category(name: '工资', emoji: '💼', isExpense: false),
          Category(name: '兼职', emoji: '💻', isExpense: false),
          Category(name: '投资', emoji: '📈', isExpense: false),
          Category(name: '红包', emoji: '🧧', isExpense: false),
          Category(name: '奖金', emoji: '🎉', isExpense: false),
          Category(name: '其他', emoji: '📦', isExpense: false),
        ];
      }
    });
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'transactions', jsonEncode(_transactions.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final all = [..._expenseCategories, ..._incomeCategories];
    await prefs.setString(
        'categories', jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  void _addTransaction(Transaction tx) {
    setState(() {
      _transactions.insert(0, tx);
    });
    _saveTransactions();
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((t) => t.id == id);
    });
    _saveTransactions();
  }

  double get _balance => _transactions.fold(
      0, (s, t) => s + (t.isExpense ? -t.amount : t.amount));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0 ? _buildHome() : _buildStats(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '统计'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: const Color(0xFF667eea),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHome() {
    final now = DateTime.now();
    final monthIncome = _transactions
        .where((t) =>
            !t.isExpense &&
            t.date.month == now.month &&
            t.date.year == now.year)
        .fold(0.0, (s, t) => s + t.amount);
    final monthExpense = _transactions
        .where((t) =>
            t.isExpense &&
            t.date.month == now.month &&
            t.date.year == now.year)
        .fold(0.0, (s, t) => s + t.amount);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('总资产',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text('¥${_balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('本月收入',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('+¥${monthIncome.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('本月支出',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('-¥${monthExpense.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (_transactions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Text('📝', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('暂无记录\n点击下方＋添加',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }
                final t = _transactions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                          child: Text(t.emoji.isEmpty ? '📦' : t.emoji,
                              style: const TextStyle(fontSize: 20))),
                    ),
                    title: Text(t.category),
                    subtitle: Text(
                        t.note.isEmpty ? DateFormat('yyyy-MM-dd').format(t.date) : t.note),
                    trailing: Text(
                      '${t.isExpense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: t.isExpense ? Colors.red : Colors.green,
                      ),
                    ),
                    onTap: () => _deleteTransaction(t.id),
                  ),
                );
              },
              childCount: _transactions.isEmpty ? 1 : _transactions.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return DefaultTabController(
      length: 2,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Column(
                children: [
                  TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    onTap: (i) =>
                        setState(() => _statsType = i == 0 ? 'month' : 'year'),
                    tabs: const [
                      Tab(text: '📅 按月'),
                      Tab(text: '📆 按年'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('收入', _getIncome(), Colors.green),
                      _buildStatItem('支出', _getExpense(), Colors.red),
                      _buildStatItem('净收入', _getNet(), const Color(0xFF667eea)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              children: [
                _buildChartView('month'),
                _buildChartView('year'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text('¥${value.toStringAsFixed(2)}',
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  double _getIncome() {
    if (_statsType == 'month') {
      return _transactions
          .where((t) =>
              !t.isExpense &&
              t.date.year == _statsYear &&
              t.date.month == _statsMonth)
          .fold(0.0, (s, t) => s + t.amount);
    } else {
      return _transactions
          .where((t) => !t.isExpense && t.date.year == _statsYear)
          .fold(0.0, (s, t) => s + t.amount);
    }
  }

  double _getExpense() {
    if (_statsType == 'month') {
      return _transactions
          .where((t) =>
              t.isExpense &&
              t.date.year == _statsYear &&
              t.date.month == _statsMonth)
          .fold(0.0, (s, t) => s + t.amount);
    } else {
      return _transactions
          .where((t) => t.isExpense && t.date.year == _statsYear)
          .fold(0.0, (s, t) => s + t.amount);
    }
  }

  double _getNet() => _getIncome() - _getExpense();

  Widget _buildChartView(String type) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text('收支趋势',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (type == 'month') {
                          return Text('${value.toInt()}日',
                              style: const TextStyle(fontSize: 10));
                        } else {
                          return Text('${value.toInt()}月',
                              style: const TextStyle(fontSize: 10));
                        }
                      },
                    ),
                  ),
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _createLineData(type, false, Colors.green, '收入'),
                  _createLineData(type, true, Colors.red, '支出'),
                  _createLineData(type, null, const Color(0xFF667eea), '净收入'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('支出分类',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _buildPieChart(true),
          ),
          const SizedBox(height: 20),
          const Text('收入分类',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: _buildPieChart(false),
          ),
        ],
      ),
    );
  }

  LineChartBarData _createLineData(
      String type, bool? isExpense, Color color, String label) {
    final spots = <FlSpot>[];
    if (type == 'month') {
      final days = DateTime(_statsYear, _statsMonth + 1, 0).day;
      for (int i = 1; i <= days; i++) {
        final tx = _transactions.where((t) {
          return t.date.year == _statsYear &&
              t.date.month == _statsMonth &&
              t.date.day == i;
        });
        double value = 0;
        if (isExpense == null) {
          final income =
              tx.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);
          final expense =
              tx.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
          value = income - expense;
        } else {
          value = tx
              .where((t) => t.isExpense == isExpense)
              .fold(0.0, (s, t) => s + t.amount);
        }
        spots.add(FlSpot(i.toDouble(), value));
      }
    } else {
      for (int m = 1; m <= 12; m++) {
        final tx = _transactions.where((t) {
          return t.date.year == _statsYear && t.date.month == m;
        });
        double value = 0;
        if (isExpense == null) {
          final income =
              tx.where((t) => !t.isExpense).fold(0.0, (s, t) => s + t.amount);
          final expense =
              tx.where((t) => t.isExpense).fold(0.0, (s, t) => s + t.amount);
          value = income - expense;
        } else {
          value = tx
              .where((t) => t.isExpense == isExpense)
              .fold(0.0, (s, t) => s + t.amount);
        }
        spots.add(FlSpot(m.toDouble(), value));
      }
    }
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
      dashArray: isExpense == null ? [5, 5] : null,
    );
  }

  Widget _buildPieChart(bool isExpense) {
    final txs =
        _transactions.where((t) => t.isExpense == isExpense).toList();
    final categoryTotals = <String, double>{};
    for (var t in txs) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }
    if (categoryTotals.isEmpty) {
      return const Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey)));
    }
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal
    ];
    int i = 0;
    return PieChart(
      PieChartData(
        sections: categoryTotals.entries.map((e) {
          final color = colors[i++ % colors.length];
          return PieChartSectionData(
            value: e.value,
            title: e.key,
            color: color,
            radius: 60,
            titleStyle: const TextStyle(
                fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
          );
        }).toList(),
      ),
    );
  }

  void _showAddDialog() {
    bool isExpense = true;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    Category? selectedCategory;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final categories = isExpense ? _expenseCategories : _incomeCategories;
          selectedCategory ??= categories.first;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('添加记录',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('💸 支出'),
                        selected: isExpense,
                        onSelected: (_) => setState(() {
                          isExpense = true;
                          selectedCategory = _expenseCategories.first;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('💰 收入'),
                        selected: !isExpense,
                        onSelected: (_) => setState(() {
                          isExpense = false;
                          selectedCategory = _incomeCategories.first;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: categories.map((c) {
                    return GestureDetector(
                      onTap: () => setState(() => selectedCategory = c),
                      child: Container(
                        width: 80,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: selectedCategory == c
                                  ? const Color(0xFF667eea)
                                  : Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                          color: selectedCategory == c
                              ? const Color(0xFF667eea).withOpacity(0.1)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(c.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 4),
                            Text(c.name, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '金额',
                    prefixText: '¥ ',
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount =
                          double.tryParse(amountController.text);
                      if (amount == null ||
                          amount <= 0 ||
                          selectedCategory == null) return;
                      _addTransaction(Transaction(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        amount: amount,
                        category: selectedCategory!.name,
                        emoji: selectedCategory!.emoji,
                        note: noteController.text,
                        date: DateTime.now(),
                        isExpense: isExpense,
                      ));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('保存',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
