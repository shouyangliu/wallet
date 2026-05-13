-- 在 Supabase SQL Editor 中执行此脚本创建数据库表

-- 账户表
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  emoji TEXT DEFAULT '🏦',
  balance DOUBLE PRECISION DEFAULT 0,
  color INTEGER DEFAULT 0xFF667eea,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 交易记录表
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount DOUBLE PRECISION NOT NULL,
  category TEXT NOT NULL,
  emoji TEXT DEFAULT '',
  note TEXT DEFAULT '',
  date TIMESTAMPTZ NOT NULL,
  is_expense BOOLEAN NOT NULL DEFAULT TRUE,
  account_id TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 分类表
CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  emoji TEXT DEFAULT '',
  is_expense BOOLEAN NOT NULL DEFAULT TRUE,
  color INTEGER DEFAULT 0xFF667eea,
  UNIQUE(user_id, name, is_expense)
);

-- 预算表
CREATE TABLE budgets (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  total_limit DOUBLE PRECISION NOT NULL,
  emoji TEXT DEFAULT '💰',
  color INTEGER DEFAULT 0xFF667eea,
  UNIQUE(user_id)
);

-- 开启行级安全
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;

-- 用户只能访问自己的数据
CREATE POLICY "users_own_accounts" ON accounts
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "users_own_transactions" ON transactions
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "users_own_categories" ON categories
  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "users_own_budgets" ON budgets
  FOR ALL USING (auth.uid() = user_id);
