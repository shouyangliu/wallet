import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';

final ValueNotifier<int> themeColorNotifier = ValueNotifier(0xFF667eea);
final ValueNotifier<bool> darkModeNotifier = ValueNotifier(false);
final ValueNotifier<double> saturationNotifier = ValueNotifier(1.0);

Color adjustSaturation(Color base, double factor) {
  final hsl = HSLColor.fromColor(base);
  final s = (hsl.saturation * factor).clamp(0.0, 1.0);
  return hsl.withSaturation(s).toColor();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getInt('themeColor');
  if (saved != null) themeColorNotifier.value = saved;
  final dark = prefs.getBool('darkMode');
  if (dark != null) darkModeNotifier.value = dark;
  final sat = prefs.getDouble('themeSaturation');
  if (sat != null) saturationNotifier.value = sat;
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    themeColorNotifier.addListener(_onChanged);
    darkModeNotifier.addListener(_onChanged);
    saturationNotifier.addListener(_onChanged);
  }

  @override
  void dispose() {
    themeColorNotifier.removeListener(_onChanged);
    darkModeNotifier.removeListener(_onChanged);
    saturationNotifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  ColorScheme _buildScheme(Color seed, Brightness brightness) {
    final onPrimary =
        ThemeData.estimateBrightnessForColor(seed) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(primary: seed, onPrimary: onPrimary);
  }

  @override
  Widget build(BuildContext context) {
    final seed = adjustSaturation(
        Color(themeColorNotifier.value), saturationNotifier.value);
    return MaterialApp(
      title: 'yl记账',
      theme: ThemeData(
        colorScheme: _buildScheme(seed, Brightness.light),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: _buildScheme(seed, Brightness.dark),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: darkModeNotifier.value ? ThemeMode.dark : ThemeMode.light,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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

class Budget {
  String category;
  double limit;
  String emoji;

  Budget({required this.category, required this.limit, this.emoji = ''});

  Map<String, dynamic> toJson() => {
    'category': category,
    'limit': limit,
    'emoji': emoji,
  };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    category: json['category'],
    limit: (json['limit'] as num).toDouble(),
    emoji: json['emoji'] ?? '',
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
  int _accountGridColumns = 3;
  int _currentIndex = 0;
  String _statsType = 'month';
  int _statsYear = DateTime.now().year;
  int _statsMonth = DateTime.now().month;
  String _searchQuery = '';
  String? _filterCategory;

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

  List<Transaction> get _filteredTransactions {
    var list = _transactions;
    if (_filterCategory != null) {
      list = list.where((t) => t.category == _filterCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) =>
        t.category.toLowerCase().contains(q) ||
        t.note.toLowerCase().contains(q) ||
        t.amount.toString().contains(q)
      ).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : _currentIndex == 2
              ? FloatingActionButton(
                  onPressed: _showAddAccountDialog,
                  backgroundColor: Theme.of(context).colorScheme.primary,
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha:0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
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
                            color: Colors.white.withValues(alpha: 0.2),
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
                            color: Colors.white.withValues(alpha:0.2),
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
        SliverToBoxAdapter(
          child: Padding(
             padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
             child: Column(
               children: [
                 const SizedBox(height: 8),
                 SizedBox(
                   height: 36,
                   child: ListView(
                     scrollDirection: Axis.horizontal,
                     children: [
                       ..._expenseCategories.take(6).map((c) => Padding(
                         padding: const EdgeInsets.only(right: 8),
                         child: ActionChip(
                           avatar: Text(c.emoji, style: const TextStyle(fontSize: 14)),
                           label: Text(c.name, style: const TextStyle(fontSize: 12)),
                           onPressed: () => setState(() => _filterCategory = c.name),
                         ),
                       )),
                     ],
                   ),
                 ),
               ],
             ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final filtered = _filteredTransactions;
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          const Text('📝', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('暂无记录\n点击下方＋添加',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  );
                }
                final grouped = <String, List<Transaction>>{};
                for (final t in filtered) {
                  final key = DateFormat('yyyy-MM-dd').format(t.date);
                  (grouped[key] ??= []).add(t);
                }
                final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
                final flatItems = <Widget>[];
                for (final key in sortedKeys) {
                  final date = DateTime.parse(key);
                  flatItems.add(Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(_dateLabel(date),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ));
                  for (final t in grouped[key]!) {
                    flatItems.add(_buildTransactionCard(t));
                  }
                }
                return flatItems[index];
              },
              childCount: _filteredTransactions.isEmpty
                  ? 1
                  : (() {
                      final grouped = <String, List<Transaction>>{};
                      for (final t in _filteredTransactions) {
                        final key = DateFormat('yyyy-MM-dd').format(t.date);
                        (grouped[key] ??= []).add(t);
                      }
                      int count = 0;
                      for (final txs in grouped.values) {
                        count += 1 + txs.length;
                      }
                      return count;
                    })(),
            ),
          ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    const weekdays = ['', '一', '二', '三', '四', '五', '六', '日'];
    return '${date.month}月${date.day}日 周${weekdays[date.weekday]}';
  }

  Widget _buildTransactionCard(Transaction t) {
    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定删除「${t.category} ${t.isExpense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)}」？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _deleteTransaction(t.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          onTap: () => _showTransactionDetail(t),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return DefaultTabController(
      length: 2,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withValues(alpha:0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
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
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        onPressed: () => setState(() {
                          if (_statsType == 'month') {
                            if (_statsMonth == 1) { _statsMonth = 12; _statsYear--; }
                            else { _statsMonth--; }
                          } else {
                            _statsYear--;
                          }
                        }),
                      ),
                      Text(
                        _statsType == 'month'
                            ? '$_statsYear年$_statsMonth月'
                            : '$_statsYear年',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        onPressed: () => setState(() {
                          if (_statsType == 'month') {
                            if (_statsMonth == 12) { _statsMonth = 1; _statsYear++; }
                            else { _statsMonth++; }
                          } else {
                            _statsYear++;
                          }
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('收入', _getIncome(), Colors.green),
                      _buildStatItem('支出', _getExpense(), Colors.red),
                      _buildStatItem('净收入', _getNet(), Theme.of(context).colorScheme.primary),
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

  Widget _gridColBtn(int n) {
    final active = _accountGridColumns == n;
    return GestureDetector(
      onTap: () => setState(() => _accountGridColumns = n),
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha:0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha:0.4),
          ),
        ),
        child: Text('$n列',
            style: TextStyle(
                color: active ? Colors.white : Colors.white70, fontSize: 12)),
      ),
    );
  }

  Widget _buildAccounts() {
    final totalAssets = _accounts.fold(0.0, (s, a) => s + a.balance);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha:0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
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
                    Row(
                      children: [
                        _gridColBtn(2),
                        _gridColBtn(3),
                        _gridColBtn(4),
                      ],
                    ),
                  ],
                ),
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
          sliver: _accounts.isEmpty
              ? SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          const Text('🏦', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text('暂无账户\n点击下方＋添加',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverGrid(
                  gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _accountGridColumns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final a = _accounts[index];
                      return GestureDetector(
                        onTap: () => _showEditAccountDialog(a),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(a.color),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.shadow.withValues(alpha:0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(a.emoji.isEmpty ? '🏦' : a.emoji,
                                  style: const TextStyle(fontSize: 32)),
                              const SizedBox(height: 8),
                              Text(a.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: ThemeData.estimateBrightnessForColor(Color(a.color)) == Brightness.dark 
                                          ? Colors.white 
                                          : Colors.black)),
                              const SizedBox(height: 4),
                              Text(
                                '¥${a.balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: a.balance >= 0
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _accounts.length,
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
        color: Colors.white.withValues(alpha:0.2),
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

  Widget _buildSummaryCards(String type) {
    final txs = _transactions.where((t) {
      if (type == 'month') {
        return t.date.year == _statsYear && t.date.month == _statsMonth;
      } else {
        return t.date.year == _statsYear;
      }
    }).toList();
    final expenses = txs.where((t) => t.isExpense);
    final incomes = txs.where((t) => !t.isExpense);
    final maxExpense = expenses.isEmpty ? 0.0 : expenses.fold(0.0, (s, t) => t.amount > s ? t.amount : s);
    final maxIncome = incomes.isEmpty ? 0.0 : incomes.fold(0.0, (s, t) => t.amount > s ? t.amount : s);
    final avgExpense = expenses.isEmpty ? 0.0 : expenses.fold(0.0, (s, t) => s + t.amount) / (type == 'month' ? DateTime(_statsYear, _statsMonth + 1, 0).day : 12);
    return Row(
      children: [
        Expanded(child: _buildMiniStat('最高支出', '¥${maxExpense.toStringAsFixed(0)}', Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniStat('最高收入', '¥${maxIncome.toStringAsFixed(0)}', Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniStat('日均支出', '¥${avgExpense.toStringAsFixed(0)}', Colors.orange)),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildChartView(String type) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          _buildSingleChart(type, '收入趋势', false, Colors.green),
          const SizedBox(height: 16),
          _buildSingleChart(type, '支出趋势', true, Colors.red),
          const SizedBox(height: 16),
          _buildSingleChart(type, '净收入趋势', null, Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          _buildSummaryCards(type),
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
                  gridData: const
                      FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: type == 'month' ? 5 : 1,
                        reservedSize: 22,
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
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('');
                          return Text('¥${value.toInt()}',
                              style: const TextStyle(fontSize: 9));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
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
      dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
        return FlDotCirclePainter(radius: 1.5, color: color, strokeWidth: 0);
      }),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha:0.1)),
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
      return Center(
          child: Text('暂无数据', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
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
            title: '${e.key}\n¥${e.value.toStringAsFixed(0)}',
            color: color,
            radius: 60,
            titleStyle: const TextStyle(
                fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNumpad(TextEditingController ctrl, StateSetter setState) {
    void onTap(String v) {
      setState(() {
        if (v == '⌫') {
          if (ctrl.text.isNotEmpty) {
            ctrl.text = ctrl.text.substring(0, ctrl.text.length - 1);
          }
        } else if (v == '.') {
          if (!ctrl.text.contains('.')) {
            ctrl.text = ctrl.text.isEmpty ? '0.' : '${ctrl.text}.';
          }
        } else {
          if (ctrl.text == '0' && v != '.') {
            ctrl.text = v;
          } else {
            ctrl.text += v;
          }
        }
      });
    }

    final keys = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      ['.', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((k) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => onTap(k),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: k == '⌫'
                            ? Theme.of(context).colorScheme.surfaceContainerHigh
                            : Theme.of(context).colorScheme.surfaceContainer,
                        foregroundColor: Theme.of(context).colorScheme.onSurface,
                        elevation: 1,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(k,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  void _showAddDialog([Transaction? edit]) {
    bool isExpense = edit?.isExpense ?? true;
    final amountController = TextEditingController(
        text: edit != null ? edit.amount.toStringAsFixed(2) : '');
    final noteController = TextEditingController(text: edit?.note ?? '');
    final noteFocus = FocusNode();
    Category? selectedCategory;
    if (edit != null) {
      final cats = isExpense ? _expenseCategories : _incomeCategories;
      selectedCategory = cats.where((c) => c.name == edit.category).firstOrNull;
    }
    String selectedAccountId = edit?.accountId ??
        (_accounts.isNotEmpty ? _accounts.first.id : '');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: StatefulBuilder(
          builder: (context, setState) {
            final categories = isExpense ? _expenseCategories : _incomeCategories;
            selectedCategory ??= categories.first;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(edit != null ? '编辑记录' : '添加记录',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(12),
                            color: selectedCategory == c
                                ? Theme.of(context).colorScheme.primary.withValues(alpha:0.1)
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
                    }),
                    GestureDetector(
                      onTap: () => _showAddCategoryDialog(isExpense, setState),
                      child: Container(
                        width: 80,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add, size: 28, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 4),
                            Text('自定义',
                                style: TextStyle(
                                    fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text('¥ ',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(
                        amountController.text.isEmpty
                            ? '0'
                            : amountController.text,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  focusNode: noteFocus,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: () {
                      final amount =
                          double.tryParse(amountController.text);
                      if (amount == null ||
                          amount <= 0 ||
                          selectedCategory == null) {
                        return;
                      }
                      if (edit != null) {
                        setState(() {
                          edit.amount = amount;
                          edit.category = selectedCategory!.name;
                          edit.emoji = selectedCategory!.emoji;
                          edit.note = noteController.text;
                          edit.isExpense = isExpense;
                          edit.accountId = selectedAccountId;
                        });
                        _saveTransactions();
                      } else {
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
                      }
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('保存',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                _buildNumpad(amountController, setState),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
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
        content: StatefulBuilder(
          builder: (ctx, setSt) => SingleChildScrollView(
            child: Column(
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
                    final preview = adjustSaturation(
                        Color(c), saturationNotifier.value);
                    return GestureDetector(
                      onTap: () async {
                        themeColorNotifier.value = c;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('themeColor', c);
                        setSt(() {});
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: preview,
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                      color: preview.withValues(alpha: 0.5),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('饱和度',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${(saturationNotifier.value * 100).round()}%',
                        style: TextStyle(
                            fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
                Slider(
                  value: saturationNotifier.value,
                  min: 0,
                  max: 1.5,
                  divisions: 30,
                  label: '${(saturationNotifier.value * 100).round()}%',
                  onChanged: (v) {
                    saturationNotifier.value = v;
                    setSt(() {});
                  },
                  onChangeEnd: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setDouble('themeSaturation', v);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('深色模式',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Switch(
                      value: darkModeNotifier.value,
                      onChanged: (v) async {
                        darkModeNotifier.value = v;
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('darkMode', v);
                        setSt(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
            Text('请粘贴 CSV 内容（首行为表头）',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  static const _accountEmojis = [
    '🏦', '💰', '💳', '🏧', '💵', '💴',
    '💶', '💷', '🏠', '🚗', '🎓', '💼',
    '📈', '🏪', '🌐', '🎮', '❤️', '⭐',
  ];

  Widget _buildEmojiPicker(TextEditingController ctrl) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _accountEmojis.map((e) {
        return GestureDetector(
          onTap: () => ctrl.text = e,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ctrl.text == e
                  ? Theme.of(context).colorScheme.primary.withValues(alpha:0.15)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: ctrl.text == e
                  ? Border.all(color: Theme.of(context).colorScheme.primary)
                  : null,
            ),
            child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
          ),
        );
        }).toList(),
    );
  }

  Widget _buildColorPicker(ValueChanged<int> onColorSelected) {
    final colors = [
      0xFF667eea, 0xFF764ba2, 0xFFf093fb, 0xFF4facfe,
      0xFF00f2fe, 0xFF43e97b, 0xFF38f9d7, 0xFFffecd2,
      0xFFfcb69f, 0xFFa18cd1, 0xFFfbc2eb, 0xFFff9a9e,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((c) {
        return GestureDetector(
          onTap: () => onColorSelected(c),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAddAccountDialog() {
    final nameController = TextEditingController();
    final emojiController = TextEditingController();
    final balanceController = TextEditingController();
    int selectedColor = 0xFF667eea;

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
            const SizedBox(height: 12),
            Text('选择账户颜色',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            _buildColorPicker((color) => selectedColor = color),
            const SizedBox(height: 12),
            Text('选择 Emoji',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            _buildEmojiPicker(emojiController),
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
                  color: selectedColor,
                ));
                _saveAccounts();
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditAccountDialog(Account account) {
    final nameController = TextEditingController(text: account.name);
    final emojiController = TextEditingController(text: account.emoji);
    final balanceController = TextEditingController(
        text: account.balance.toStringAsFixed(2));
    int selectedColor = account.color;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑账户'),
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
            const SizedBox(height: 12),
            Text('选择账户颜色',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            _buildColorPicker((color) => selectedColor = color),
            const SizedBox(height: 12),
            Text('选择 Emoji',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            _buildEmojiPicker(emojiController),
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
              final balance = double.tryParse(balanceController.text);
              if (name.isEmpty || balance == null) return;
              setState(() {
                account.name = name;
                account.emoji = emoji.isEmpty ? '🏦' : emoji;
                account.balance = balance;
                account.color = selectedColor;
                _saveAccounts();
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetail(Transaction t) {
    final account = _accounts.where((a) => a.id == t.accountId).firstOrNull;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('记录详情',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.emoji.isEmpty ? '📦' : t.emoji,
                    style: const TextStyle(fontSize: 48)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${t.isExpense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: t.isExpense ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            _detailRow('分类', t.category),
            if (t.note.isNotEmpty) _detailRow('备注', t.note),
            _detailRow('日期', DateFormat('yyyy-MM-dd HH:mm').format(t.date)),
            _detailRow('账户', account != null ? '${account.emoji} ${account.name}' : '无'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddDialog(t);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text('删除记录'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteTransaction(t.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
