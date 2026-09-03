-- schema.sql適用時に不足していたポリシーを追加する(1回限りの差分)。
-- 管理者がマスタ設定画面から直接従業員を追加する際に必要(ログインアカウント未作成の従業員用)。
-- 内容はschema.sqlに恒久的に反映済み。
create policy "employees_admin_insert" on public.employees
  for insert with check (public.is_admin());
