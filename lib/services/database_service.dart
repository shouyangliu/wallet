import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/budget.dart';

enum SyncStatus { localOnly, syncing, cloud }

class DatabaseService extends ChangeNotifier {
  static final DatabaseService _instance = DatabaseService._();
  static DatabaseService get instance => _instance;
  DatabaseService._();

  SyncStatus _status = SyncStatus.localOnly;
  SyncStatus get status => _status;
  bool get isCloud => _status == SyncStatus.cloud;
  bool get isLocalOnly => _status == SyncStatus.localOnly;

  User? get user => AppConfig.cloudEnabled ? Supabase.instance.client.auth.currentUser : null;

  List<Account> accounts = [];
  List<Transaction> transactions = [];
  List<Category> expenseCategories = [];
  List<Category> incomeCategories = [];
  Budget? budget;

  Future<void> init() async {
    if (AppConfig.cloudEnabled) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.session != null) {
          _status = SyncStatus.cloud;
        } else {
          _status = SyncStatus.localOnly;
        }
        notifyListeners();
      });
      if (Supabase.instance.client.auth.currentUser != null) {
        _status = SyncStatus.cloud;
      }
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

    if (isCloud) {
      await _syncFromCloud();
    }
  }

  Future<void> _syncFromCloud() async {
    final uid = user!.id;
    try {
      _status = SyncStatus.syncing;
      notifyListeners();

      final acctRes = await Supabase.instance.client
          .from('accounts')
          .select()
          .eq('user_id', uid);
      if (acctRes.isNotEmpty && accounts.isEmpty) {
        accounts =
            acctRes.map((e) => Account.fromJson(e)).toList().cast<Account>();
      }

      final txRes = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('user_id', uid);
      if (txRes.isNotEmpty && transactions.isEmpty) {
        transactions = txRes
            .map((e) => Transaction.fromJson(e))
            .toList()
            .cast<Transaction>();
      }

      final catRes = await Supabase.instance.client
          .from('categories')
          .select()
          .eq('user_id', uid);
      if (catRes.isNotEmpty) {
        final cats =
            catRes.map((e) => Category.fromJson(e)).toList().cast<Category>();
        expenseCategories = cats.where((c) => c.isExpense).toList();
        incomeCategories = cats.where((c) => !c.isExpense).toList();
      }

      _status = SyncStatus.cloud;
      notifyListeners();
    } catch (e) {
      _status = SyncStatus.cloud;
      notifyListeners();
    }
  }

  Future<void> _saveLocal(String key, List<Map<String, dynamic>> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  Future<void> _saveCloud(
      String table, String key, List<Map<String, dynamic>> data) async {
    if (!isCloud) return;
    final uid = user!.id;
    try {
      await Supabase.instance.client.from(table).upsert(
            data.map((e) => {...e, 'user_id': uid}).toList(),
          );
    } catch (_) {}
  }

  Future<void> saveAccounts() async {
    await _saveLocal('accounts', accounts.map((e) => e.toJson()).toList());
    await _saveCloud('accounts', 'accounts', accounts.map((e) => e.toJson()).toList());
  }

  Future<void> saveTransactions() async {
    await _saveLocal(
        'transactions', transactions.map((e) => e.toJson()).toList());
    await _saveCloud('transactions', 'transactions',
        transactions.map((e) => e.toJson()).toList());
  }

  Future<void> saveCategories() async {
    final all = [...expenseCategories, ...incomeCategories];
    final data = all.map((e) => e.toJson()).toList();
    await _saveLocal('categories', data);
    await _saveCloud('categories', 'categories', data);
  }

  Future<void> saveBudget() async {
    final prefs = await SharedPreferences.getInstance();
    if (budget != null) {
      await prefs.setString('budgets', jsonEncode([budget!.toJson()]));
      if (isCloud) {
        try {
          await Supabase.instance.client.from('budgets').upsert({
            ...budget!.toJson(),
            'user_id': user!.id,
          });
        } catch (_) {}
      }
    }
  }

  Future<void> uploadLocalData() async {
    if (!isCloud) return;
    await saveAccounts();
    await saveTransactions();
    await saveCategories();
    await saveBudget();
  }

  Future<AuthResponse> signIn(String email, String password) async {
    final resp = await Supabase.instance.client.auth
        .signInWithPassword(email: email, password: password);
    _status = SyncStatus.cloud;
    notifyListeners();
    return resp;
  }

  Future<AuthResponse> signUp(String email, String password) async {
    final resp = await Supabase.instance.client.auth
        .signUp(email: email, password: password);
    return resp;
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    _status = SyncStatus.localOnly;
    notifyListeners();
  }
}
