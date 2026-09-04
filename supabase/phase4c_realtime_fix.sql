-- schema.sql適用時、employees/productsテーブルがRealtime配信対象に
-- 追加されていなかった不具合の修正(既存プロジェクト用の差分SQL)。
-- 内容はschema.sqlに恒久的に反映済み。
alter publication supabase_realtime add table public.employees;
alter publication supabase_realtime add table public.products;
