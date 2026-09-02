-- schema.sql適用時に不足していたGRANTを追加で実行する(1回限りの差分)。
-- 内容は schema.sql に恒久的に反映済み(今後の新規プロジェクトではschema.sqlのみでOK)。
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.employees to anon, authenticated;
grant select, insert, update, delete on public.seats to anon, authenticated;
grant select, insert, update, delete on public.shifts to anon, authenticated;
grant select, insert, update, delete on public.products to anon, authenticated;
