import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';

final ValueNotifier<int> themeColorNotifier = ValueNotifier(0xFF667eea);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getInt('themeColor');
  if (saved != null) themeColorNotifier.value = saved;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeColorNotifier,
      builder: (context, color, _) {
        return MaterialApp(
          title: 'yl记账',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Color(color)),
            useMaterial3: true,
          ),
          home: const HomePage(),
          debugShowCheckedModeBanner: false,
        );
      },
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
  final String accountId;

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

class Account {
  final String id;
  String name;
  String emoji;
  double balance;

  Account({
    required this.id,
    required this.name,
    this.emoji = '🏦',
    this.balance = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'balance': balance,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'],
    name: json['name'],
    emoji: json['emoji'] ?? '🏦',
    balance: (json['balance'] as num?)?.toDouble() ?? 0,
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
  List<Account> _accounts = [];
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
    final acctJson = prefs.getString('accounts');

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
      if (acctJson != null) {
        _accounts = (jsonDecode(acctJson) as List)
            .map((e) => Account.fromJson(e))
            .toList();
      } else {
        _accounts = [
          Account(id: 'default', name: '默认账户', emoji: '🏦', balance: 0),
        ];
        _saveAccounts();
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

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'accounts', jsonEncode(_accounts.map((e) => e.toJson()).toList()));
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHome(),
          _buildStats(),
          _buildAccounts(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '统计'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: '账户'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: const Color(0xFF667eea),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : _currentIndex == 2
              ? FloatingActionButton(
                  onPressed: _showAddAccountDialog,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('总资产',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white70),
                      onPressed: _showSettingsDialog,
                    ),
                  ],
                ),
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

  Widget _buildAccounts() {
    final totalAssets = _accounts.fold(0.0, (s, a) => s + a.balance);
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
                Text('¥${totalAssets.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (_accounts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Text('🏦', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('暂无账户\n点击下方＋添加',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }
                final a = _accounts[index];
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
                          child: Text(a.emoji.isEmpty ? '🏦' : a.emoji,
                              style: const TextStyle(fontSize: 20))),
                    ),
                    title: Text(a.name),
                    subtitle: const Text('点击编辑余额'),
                    trailing: Text(
                      '¥${a.balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: a.balance >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    onTap: () => _showEditAccountDialog(a),
                  ),
                );
              },
              childCount: _accounts.isEmpty ? 1 : _accounts.length,
            ),
          ),
        ),
      ],
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
          _buildSingleChart(type, '收入趋势', false, Colors.green),
          const SizedBox(height: 16),
          _buildSingleChart(type, '支出趋势', true, Colors.red),
          const SizedBox(height: 16),
          _buildSingleChart(type, '净收入趋势', null, const Color(0xFF667eea)),
          const SizedBox(height: 24),
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

  Widget _buildSingleChart(
      String type, String title, bool? isExpense, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  gridData:
                      FlGridData(show: true, drawVerticalLine: false),
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
                    leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    _createLineData(type, isExpense, color),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _createLineData(
      String type, bool? isExpense, Color color) {
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
    String selectedAccountId = _accounts.isNotEmpty ? _accounts.first.id : '';

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
                  children: [
                    ...categories.map((c) {
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
                    GestureDetector(
                      onTap: () => _showAddCategoryDialog(isExpense, setState),
                      child: Container(
                        width: 80,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey[300]!,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.add, size: 28, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('自定义',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedAccountId.isEmpty && _accounts.isNotEmpty
                      ? _accounts.first.id
                      : selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: '账户',
                    border: OutlineInputBorder(),
                  ),
                  items: _accounts.map((a) {
                    return DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.emoji} ${a.name}'));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedAccountId = v);
                  },
                ),
                const SizedBox(height: 12),
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
                        accountId: selectedAccountId,
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

  void _showSettingsDialog() {
    final presetColors = [
      0xFF667eea,
      0xFFE53935,
      0xFF43A047,
      0xFF1E88E5,
      0xFFFF8F00,
      0xFF8E24AA,
      0xFF00ACC1,
      0xFFF4511E,
      0xFF3949AB,
      0xFF6D4C41,
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('主题配色',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: presetColors.map((c) {
                final selected = themeColorNotifier.value == c;
                return GestureDetector(
                  onTap: () async {
                    themeColorNotifier.value = c;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('themeColor', c);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                  color: Color(c).withOpacity(0.5),
                                  blurRadius: 8)
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('数据管理',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('导出 CSV'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportCsv();
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('导入 CSV'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _importCsv();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  Future<void> _exportCsv() async {
    if (_transactions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无数据可导出')),
      );
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('id,amount,category,emoji,note,date,isExpense,accountId');
    for (final t in _transactions) {
      buffer.writeln([
        _csvEscape(t.id),
        t.amount.toStringAsFixed(2),
        _csvEscape(t.category),
        _csvEscape(t.emoji),
        _csvEscape(t.note),
        _csvEscape(t.date.toIso8601String()),
        t.isExpense.toString(),
        _csvEscape(t.accountId),
      ].join(','));
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/yl_wallet_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导出到: ${file.path}')),
    );
  }

  Future<void> _importCsv() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入 CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请粘贴 CSV 内容（首行为表头）',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    'id,amount,category,emoji,note,date,isExpense,accountId\n...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;

    final lines = result.trim().split('\n');
    if (lines.length < 2) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV 格式错误：缺少数据行')),
      );
      return;
    }
    int imported = 0, skipped = 0;
    final existingIds = _transactions.map((t) => t.id).toSet();
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = _parseCsvLine(line);
      if (cols.length < 7) continue;
      final id = cols[0];
      if (existingIds.contains(id)) {
        skipped++;
        continue;
      }
      final amount = double.tryParse(cols[1]);
      if (amount == null) continue;
      final date = DateTime.tryParse(cols[5]);
      if (date == null) continue;
      _transactions.add(Transaction(
        id: id,
        amount: amount,
        category: cols[2],
        emoji: cols.length > 3 ? cols[3] : '',
        note: cols.length > 4 ? cols[4] : '',
        date: date,
        isExpense: cols[6].toLowerCase() == 'true',
        accountId: cols.length > 7 ? cols[7] : '',
      ));
      imported++;
    }
    setState(() {});
    _saveTransactions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导入完成：新增 $imported 条，跳过 $skipped 条（已存在）')),
    );
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final current = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            current.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          current.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          result.add(current.toString());
          current.clear();
        } else {
          current.write(ch);
        }
      }
    }
    result.add(current.toString());
    return result;
  }

  void _showAddCategoryDialog(bool isExpense, StateSetter setDialogState) {
    final nameController = TextEditingController();
    final emojiController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '分类名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji（如 🍜）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final emoji = emojiController.text.trim();
              if (name.isEmpty || emoji.isEmpty) return;
              final cat = Category(name: name, emoji: emoji, isExpense: isExpense);
              setState(() {
                if (isExpense) {
                  _expenseCategories.add(cat);
                } else {
                  _incomeCategories.add(cat);
                }
                _saveCategories();
              });
              setDialogState(() {});
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showAddAccountDialog() {
    final nameController = TextEditingController();
    final emojiController = TextEditingController();
    final balanceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加账户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '账户名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emojiController,
              decoration: const InputDecoration(
                labelText: 'Emoji（如 🏦）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '余额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final emoji = emojiController.text.trim();
              final balance = double.tryParse(balanceController.text) ?? 0;
              if (name.isEmpty) return;
              setState(() {
                _accounts.add(Account(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                  emoji: emoji.isEmpty ? '🏦' : emoji,
                  balance: balance,
                ));
                _saveAccounts();
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditAccountDialog(Account account) {
    final balanceController = TextEditingController(
        text: account.balance.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${account.emoji} ${account.name}'),
        content: TextField(
          controller: balanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '余额',
            prefixText: '¥ ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final balance = double.tryParse(balanceController.text);
              if (balance == null) return;
              setState(() {
                account.balance = balance;
                _saveAccounts();
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
