/// Supabase 云端同步配置
///
/// 启用云端同步步骤：
/// 1. 在 https://supabase.com 创建项目
/// 2. 在 SQL Editor 中执行 supabase_setup.sql
/// 3. 将项目 URL 和 anon key 填入下方
/// 4. 将 cloudEnabled 改为 true
class AppConfig {
  static const String supabaseUrl = 'https://your-project.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlvdXItcHJvamVjdCIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjk2MDAwMDAwLCJleHAiOjE2OTE1OTAwMDB9.example';

  /// 设为 true 启用云端同步
  static const bool cloudEnabled = false;
}
