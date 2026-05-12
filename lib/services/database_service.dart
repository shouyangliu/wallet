import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/budget.dart';

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._();
  static DatabaseService get instance => _instance;
  DatabaseService._();

  static const _baseUrl = 'https://dav.jianguoyun.com/dav/yl_wallet/';

  String? _webdavUser;
  String? _webdavPwd;
  bool _connected = false;

  bool get isConnected => _connected;
  String? get webdavUser => _webdavUser;

  List<Account> accounts = [];
  List<Transaction> transactions = [];
  List<Category> expenseCategories = [];
  List<Category> incomeCategories = [];
  Budget? budget;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _webdavUser = prefs.getString('webdav_user');
    _webdavPwd = prefs.getString('webdav_pwd');
    if (_webdavUser != null && _webdavPwd != null) {
      _connected = await _testConnection();
    }
  }

  Future<bool> _testConnection() async {
    try {
      final res = await http.put(
        Uri.parse(_baseUrl),
        headers: _authHeaders(),
      );
      return res.statusCode == 201 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _authHeaders() {
    final basic = base64Encode(utf8.encode('$_webdavUser:$_webdavPwd'));
    return {
      'Authorization': 'Basic $basic',
      'User-Agent': 'yl_wallet',
    };
  }

  Future<void> configure(String user, String pwd) async {
    _webdavUser = user;
    _webdavPwd = pwd;
    _connected = await _testConnection();
    if (_connected) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('webdav_user', user);
      await prefs.setString('webdav_pwd', pwd);
      await _syncDown();
      await _syncUp();
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _webdavUser = null;
    _webdavPwd = null;
    _connected = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('webdav_user');
    await prefs.remove('webdav_pwd');
    notifyListeners();
  }

  Future<String?> _readFile(String name) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl$name'),
        headers: _authHeaders(),
      );
      if (res.statusCode == 200) return res.body;
    } catch (_) {}
    return null;
  }

  Future<void> _writeFile(String name, String content) async {
    try {
      await http.put(
        Uri.parse('$_baseUrl$name'),
        headers: {
          ..._authHeaders(),
          'Content-Type': 'application/json',
        },
        body: content,
      );
    } catch (_) {}
  }

  Future<void> _syncDown() async {
    if (!_connected) return;

    final txBody = await _readFile('transactions.json');
    if (txBody != null) {
      final list = jsonDecode(txBody) as List;
      if (list.isNotEmpty) {
        transactions =
            list.map((e) => Transaction.fromJson(e)).toList();
      }
    }

    final acctBody = await _readFile('accounts.json');
    if (acctBody != null) {
      final list = jsonDecode(acctBody) as List;
      if (list.isNotEmpty) {
        accounts = list.map((e) => Account.fromJson(e)).toList();
      }
    }

    final catBody = await _readFile('categories.json');
    if (catBody != null) {
      final cats = (jsonDecode(catBody) as List)
          .map((e) => Category.fromJson(e))
          .toList();
      expenseCategories = cats.where((c) => c.isExpense).toList();
      incomeCategories = cats.where((c) => !c.isExpense).toList();
    }

    final budgetBody = await _readFile('budgets.json');
    if (budgetBody != null) {
      final list = jsonDecode(budgetBody) as List;
      if (list.isNotEmpty) {
        budget = Budget.fromJson(list.first);
      }
    }
  }

  Future<void> _syncUp() async {
    if (!_connected) return;
    await _writeFile(
        'transactions.json',
        jsonEncode(transactions.map((e) => e.toJson()).toList()));
    await _writeFile(
        'accounts.json',
        jsonEncode(accounts.map((e) => e.toJson()).toList()));
    final all = [...expenseCategories, ...incomeCategories];
    await _writeFile(
        'categories.json',
        jsonEncode(all.map((e) => e.toJson()).toList()));
    if (budget != null) {
      await _writeFile(
          'budgets.json',
          jsonEncode([budget!.toJson()]));
    }
  }

  Future<void> loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    final txJson = prefs.getString('transactions');
    final catJson = prefs.getString('categories');
    final acctJson = prefs.getString('accounts');
    final budgetJson = prefs.getString('budgets');

    if (budgetJson != null) {
      final list = jsonDecode(budgetJson) as List;
      if (list.isNotEmpty) {
        budget = Budget.fromJson(list.first);
      }
    }
    if (txJson != null) {
      transactions = (jsonDecode(txJson) as List)
          .map((e) => Transaction.fromJson(e))
          .toList();
    }
    if (catJson != null) {
      final cats = (jsonDecode(catJson) as List)
          .map((e) => Category.fromJson(e))
          .toList();
      expenseCategories = cats.where((c) => c.isExpense).toList();
      incomeCategories = cats.where((c) => !c.isExpense).toList();
    } else {
      expenseCategories = [
        Category(name: '餐饮', emoji: '🍜', isExpense: true),
        Category(name: '交通', emoji: '🚗', isExpense: true),
        Category(name: '购物', emoji: '🛒', isExpense: true),
        Category(name: '娱乐', emoji: '🎮', isExpense: true),
        Category(name: '住房', emoji: '🏠', isExpense: true),
        Category(name: '其他', emoji: '📦', isExpense: true),
      ];
      incomeCategories = [
        Category(name: '工资', emoji: '💼', isExpense: false),
        Category(name: '兼职', emoji: '💻', isExpense: false),
        Category(name: '投资', emoji: '📈', isExpense: false),
        Category(name: '红包', emoji: '🧧', isExpense: false),
        Category(name: '奖金', emoji: '🎉', isExpense: false),
        Category(name: '其他', emoji: '📦', isExpense: false),
      ];
    }
    if (acctJson != null) {
      accounts = (jsonDecode(acctJson) as List)
          .map((e) => Account.fromJson(e))
          .toList();
    } else {
      accounts = [
        Account(id: 'default', name: '默认账户', emoji: '🏦', balance: 0),
      ];
      await _saveLocal('accounts', accounts.map((e) => e.toJson()).toList());
    }

    if (_connected) {
      await _syncDown();
      notifyListeners();
    }
  }

  Future<void> _saveLocal(
      String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<void> saveAccounts() async {
    await _saveLocal('accounts', accounts.map((e) => e.toJson()).toList());
    await _syncUp();
  }

  Future<void> saveTransactions() async {
    await _saveLocal(
        'transactions', transactions.map((e) => e.toJson()).toList());
    await _syncUp();
  }

  Future<void> saveCategories() async {
    final all = [...expenseCategories, ...incomeCategories];
    final data = all.map((e) => e.toJson()).toList();
    await _saveLocal('categories', data);
    await _syncUp();
  }

  Future<void> saveBudget() async {
    final prefs = await SharedPreferences.getInstance();
    if (budget != null) {
      await prefs.setString('budgets', jsonEncode([budget!.toJson()]));
    }
    await _syncUp();
  }
}
