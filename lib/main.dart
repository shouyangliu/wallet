import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models/account.dart';
import 'models/transaction.dart';
import 'models/category.dart';
import 'models/budget.dart';
import 'config.dart';
import 'services/database_service.dart';
import 'pages/auth_page.dart';

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
  await DatabaseService.instance.init();
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
        fontFamily: 'Noto Sans SC',
      ),
      darkTheme: ThemeData(
        colorScheme: _buildScheme(seed, Brightness.dark),
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Noto Sans SC',
      ),
      themeMode: darkModeNotifier.value ? ThemeMode.dark : ThemeMode.light,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
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
  Budget? _budget; // 总预算，只有一个
  int _accountGridColumns = 3;
  int _currentIndex = 0;
  String _statsType = 'month';
  int _statsYear = DateTime.now().year;
  int _statsMonth = DateTime.now().month;
  final String _searchQuery = '';
  String? _filterCategory;

  @override
  void initState() {
    super.initState();
    final db = DatabaseService.instance;
    db.addListener(_onDbChanged);
    _loadData();
  }

  @override
  void dispose() {
    DatabaseService.instance.removeListener(_onDbChanged);
    super.dispose();
  }

  void _onDbChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    final db = DatabaseService.instance;
    await db.loadAll();
    setState(() {
      _accounts = db.accounts;
      _transactions = db.transactions;
      _expenseCategories = db.expenseCategories;
      _incomeCategories = db.incomeCategories;
      _budget = db.budget;
    });
  }

  Future<void> _saveTransactions() async {
    await DatabaseService.instance.saveTransactions();
  }

  Future<void> _saveCategories() async {
    await DatabaseService.instance.saveCategories();
  }

  Future<void> _saveAccounts() async {
    await DatabaseService.instance.saveAccounts();
  }

  Future<void> _saveBudgets() async {
    await DatabaseService.instance.saveBudget();
  }

  void _addTransaction(Transaction tx) {
    setState(() {
      _transactions.insert(0, tx);
      // 同步账户余额
      final account = _accounts.firstWhere((a) => a.id == tx.accountId);
      if (tx.isExpense) {
        account.balance -= tx.amount;
      } else {
        account.balance += tx.amount;
      }
    });
    _saveTransactions();
    _saveAccounts();
  }

  void _deleteTransaction(String id) {
    setState(() {
      final tx = _transactions.firstWhere((t) => t.id == id);
      // 删除前先恢复账户余额
      final account = _accounts.firstWhere((a) => a.id == tx.accountId);
      if (tx.isExpense) {
        account.balance += tx.amount; // 支出记录删除，余额增加
      } else {
        account.balance -= tx.amount; // 收入记录删除，余额减少
      }
      _transactions.removeWhere((t) => t.id == id);
    });
    _saveTransactions();
    _saveAccounts();
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
    final scheme = Theme.of(context).colorScheme;
    final topIsPrimary = _currentIndex != 3;
    final topBg = topIsPrimary ? scheme.primary : scheme.surface;
    final overlayStyle = ThemeData.estimateBrightnessForColor(topBg) ==
            Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHome(),
            _buildStats(),
            _buildAccounts(),
            _buildBudgetPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: '统计'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: '账户'),
            NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: '预算'),
          ],
        ),
        floatingActionButton: _currentIndex == 0
            ? FloatingActionButton(
                onPressed: _showAddDialog,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
              )
            : _currentIndex == 2
                ? FloatingActionButton(
                    onPressed: _showAddAccountDialog,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
                  )
                : _currentIndex == 3
                    ? FloatingActionButton(
                        onPressed: _showAddBudgetDialog,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
                      )
                    : null,
      ),
    );
  }

  Color _onColor(int backgroundColor) {
    return ThemeData.estimateBrightnessForColor(Color(backgroundColor)) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  ({double totalSpent, int remainingDays, double dailyAvailable}) _computeBudget() {
    final now = DateTime.now();
    final totalSpent = _transactions
        .where((t) =>
            t.isExpense && t.date.year == now.year && t.date.month == now.month)
        .fold(0.0, (s, t) => s + t.amount);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = daysInMonth - now.day + 1;
    final dailyAvailable = (_budget == null || remainingDays <= 0)
        ? 0.0
        : (_budget!.totalLimit - totalSpent) / remainingDays;
    return (
      totalSpent: totalSpent,
      remainingDays: remainingDays,
      dailyAvailable: dailyAvailable,
    );
  }

  Widget _buildBudgetCard() {
    final stats = _computeBudget();
    final totalSpent = stats.totalSpent;

    return InkWell(
      onTap: () => setState(() => _currentIndex = 3),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('本月预算', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Icon(Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
            if (_budget == null) ...[
              const SizedBox(height: 8),
              Text('点击设置本月总预算',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(_budget!.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    '¥${totalSpent.toStringAsFixed(0)} / ¥${_budget!.totalLimit.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '${((totalSpent / _budget!.totalLimit) * 100).clamp(0, 999).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: totalSpent > _budget!.totalLimit
                            ? Colors.red
                            : Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: (totalSpent / _budget!.totalLimit).clamp(0.0, 1.0),
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainer,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    totalSpent > _budget!.totalLimit
                        ? Colors.red
                        : totalSpent > _budget!.totalLimit * 0.8
                            ? Colors.orange
                            : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddBudgetDialog() {
    final limitController = TextEditingController(
        text: _budget != null ? _budget!.totalLimit.toStringAsFixed(0) : '');
    String selectedEmoji = _budget?.emoji ?? '💰';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_budget == null ? '添加总预算' : '修改总预算'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: limitController,
              decoration: const InputDecoration(
                labelText: '总预算金额',
                hintText: '输入每月总预算',
                prefixText: '¥',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('图标：', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    // 简单emoji选择
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(selectedEmoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final limit = double.tryParse(limitController.text) ?? 0;
              if (limit > 0) {
                setState(() {
                  _budget = Budget(
                    totalLimit: limit,
                    emoji: selectedEmoji,
                  );
                });
                _saveBudgets();
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
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
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('¥${_balance.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold)),
                ),
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
                            color: Colors.white.withValues(alpha: 0.2),
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
         // 预算卡片
         SliverToBoxAdapter(
           child: _buildBudgetCard(),
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
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
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
          color: active ? Colors.white.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
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
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('¥${totalAssets.toStringAsFixed(2)}',
                      maxLines: 1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold)),
                ),
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
                    childAspectRatio: _accountGridColumns == 2 ? 0.9 : (_accountGridColumns == 3 ? 0.9 : 0.85),
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
                                color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(a.emoji.isEmpty ? '🏦' : a.emoji,
                                          style: const TextStyle(fontSize: 48)),
                                    ),
                                  ),
                                ),
                                Text(a.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _onColor(a.color))),
                                const SizedBox(height: 4),
                                Text(
                                   '¥${a.balance.toStringAsFixed(2)}',
                                   textAlign: TextAlign.center,
                                   overflow: TextOverflow.ellipsis,
                                   style: TextStyle(
                                     fontSize: 14,
                                     fontWeight: FontWeight.bold,
                                     color: _onColor(a.color),
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

  Widget _buildBudgetPage() {
    final stats = _computeBudget();
    final totalSpent = stats.totalSpent;
    final remainingDays = stats.remainingDays;
    
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('预算管理'),
          floating: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showAddBudgetDialog,
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 本月概览卡片
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _budget != null 
                        ? [
                            Color(_budget!.color).withValues(alpha: 0.8),
                            Color(_budget!.color),
                          ]
                        : [Colors.blue, Colors.blueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(_budget?.emoji ?? '💰', style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        const Text('本月总预算', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(_budget != null ? '¥${_budget!.totalLimit.toStringAsFixed(2)}' : '未设置',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_budget != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('已花费: ¥${totalSpent.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          Text('剩余: ¥${(_budget!.totalLimit - totalSpent).toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: _budget!.totalLimit - totalSpent >= 0 
                                      ? Colors.white 
                                      : Colors.redAccent, 
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: (totalSpent / _budget!.totalLimit).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          totalSpent > _budget!.totalLimit * 0.8 ? Colors.red : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('日均可用: ¥${remainingDays > 0 ? ((_budget!.totalLimit - totalSpent) / remainingDays).toStringAsFixed(2) : '0.00'}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('剩余天数: $remainingDays天',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 预算设置按钮
              if (_budget == null)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _showAddBudgetDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('设置总预算'),
                  ),
                )
              else ...[
                const Text('预算详情', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildBudgetDetailCard(totalSpent, remainingDays),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetDetailCard(double totalSpent, int remainingDays) {
    if (_budget == null) return const SizedBox.shrink();
    
    final dailyAvailable = remainingDays > 0 
        ? (_budget!.totalLimit - totalSpent) / remainingDays 
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBudgetInfoRow('总预算', '¥${_budget!.totalLimit.toStringAsFixed(2)}', Colors.blue),
          const Divider(height: 16),
          _buildBudgetInfoRow('已花费', '¥${totalSpent.toStringAsFixed(2)}', Colors.red),
          const Divider(height: 16),
          _buildBudgetInfoRow('剩余', '¥${(_budget!.totalLimit - totalSpent).toStringAsFixed(2)}', 
              _budget!.totalLimit - totalSpent >= 0 ? Colors.green : Colors.red),
          const Divider(height: 16),
          _buildBudgetInfoRow('日均可用', '¥${dailyAvailable.toStringAsFixed(2)}', Colors.orange),
          const Divider(height: 16),
          _buildBudgetInfoRow('剩余天数', '$remainingDays天', Colors.purple),
        ],
      ),
    );
  }

  Widget _buildBudgetInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildStatItem(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
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
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
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
                        child: Text('${a.emoji} ${a.name}',
                            overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => selectedAccountId = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    prefix: Text('¥ ',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    hintText: '0',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
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
                if (AppConfig.cloudEnabled) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('云端同步',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      icon: Icon(
                        DatabaseService.instance.isCloud
                            ? Icons.cloud_done
                            : Icons.cloud_outlined,
                      ),
                      label: Text(
                        DatabaseService.instance.isCloud ? '已连接到云端' : '登录云端',
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (DatabaseService.instance.isCloud) {
                          _showCloudSettings();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AuthPage()),
                          );
                        }
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    icon: const Icon(Icons.favorite_outline, color: Colors.redAccent),
                    label: const Text('打赏支持',
                        style: TextStyle(color: Colors.redAccent)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showDonateDialog();
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

  void _showDonateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('打赏支持'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('如果这个应用对你有帮助，欢迎打赏一杯咖啡 ☕', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment),
                label: const Text('支付宝打赏'),
                onPressed: () async {
                  final uri = Uri.parse(
                      'alipays://platformapi/startapp?saId=10000007&userName=15996162784');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('请先安装支付宝')),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showCloudSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('云端设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('上传本地数据'),
              subtitle: const Text('将本地数据同步到云端'),
              onTap: () async {
                await DatabaseService.instance.syncAfterLogin();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('数据已上传到云端')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () async {
                await DatabaseService.instance.signOut();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _loadData();
                }
              },
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
    final buffer = StringBuffer();
    
    // 导出账户信息
    if (_accounts.isNotEmpty) {
      buffer.writeln('#ACCOUNTS');
      buffer.writeln('id,name,emoji,balance,color');
      for (final a in _accounts) {
        buffer.writeln([
          _csvEscape(a.id),
          _csvEscape(a.name),
          _csvEscape(a.emoji),
          a.balance.toStringAsFixed(2),
          a.color.toString(),
        ].join(','));
      }
      buffer.writeln();
    }
    
    // 导出交易记录
    if (_transactions.isNotEmpty) {
      buffer.writeln('#TRANSACTIONS');
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
    }
    
    if (buffer.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无数据可导出')),
      );
      return;
    }
    
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final result = await FilePicker.platform.saveFile(
      dialogTitle: '选择导出位置',
      fileName: 'yl_wallet_$timestamp.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: utf8.encode(buffer.toString()),
    );
    
    if (!mounted) return;
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出到: $result')),
      );
    }
  }

  Future<void> _importCsv() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入 CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_open),
              title: const Text('选择文件'),
              subtitle: const Text('从设备选择 CSV 文件'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.paste),
              title: const Text('粘贴内容'),
              subtitle: const Text('粘贴 CSV 内容'),
              onTap: () => Navigator.pop(ctx, 'paste'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (choice == null) return;
    
    String? csvContent;
    
    if (choice == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      csvContent = utf8.decode(result.files.first.bytes!);
    } else {
      csvContent = await _showPasteDialog();
      if (csvContent == null) return;
    }
    
    int accountsImported = 0;
    int transactionsImported = 0;
    int transactionsSkipped = 0;
    
    final sections = csvContent.split('\n\n');
    final existingAccountIds = _accounts.map((a) => a.id).toSet();
    final existingTransactionIds = _transactions.map((t) => t.id).toSet();
    
    for (final section in sections) {
      final lines = section.trim().split('\n');
      if (lines.isEmpty) continue;
      
      if (lines.first == '#ACCOUNTS') {
        // 导入账户
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          final cols = _parseCsvLine(line);
          if (cols.length < 4) continue;
          final id = cols[0];
          if (existingAccountIds.contains(id)) continue;
          _accounts.add(Account(
            id: id,
            name: cols[1],
            emoji: cols.length > 2 ? cols[2] : '🏦',
            balance: double.tryParse(cols[3]) ?? 0,
            color: cols.length > 4 ? int.tryParse(cols[4]) ?? 0xFF667eea : 0xFF667eea,
          ));
          existingAccountIds.add(id);
          accountsImported++;
        }
      } else if (lines.first == '#TRANSACTIONS') {
        // 导入交易
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          final cols = _parseCsvLine(line);
          if (cols.length < 7) continue;
          final id = cols[0];
          if (existingTransactionIds.contains(id)) {
            transactionsSkipped++;
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
           transactionsImported++;
         }
       }
     }
     setState(() {});
     _saveTransactions();
     _saveAccounts();
     if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text('导入完成：账户 $accountsImported 个，交易 $transactionsImported 条，跳过 $transactionsSkipped 条（已存在）')),
     );
   }

  Future<String?> _showPasteDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴 CSV 内容'),
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
    return result;
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
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
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
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加账户'),
        content: SingleChildScrollView(
          child: Column(
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
              SizedBox(height: bottomInset),
            ],
          ),
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

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑账户'),
        content: SingleChildScrollView(
          child: Column(
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
              SizedBox(height: bottomInset),
            ],
          ),
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
