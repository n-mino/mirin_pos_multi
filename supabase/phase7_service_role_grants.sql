-- service_role(Edge Functionが使う管理者権限のキー)にも、通常のanon/authenticated
-- と同様にテーブル権限が自動付与されていなかった(プロジェクト作成時の
-- 「Automatically expose new tables」OFF設定の影響とみられる)。
-- service_roleはRLSを無視できる権限だが、GRANT自体は別途必要なため明示的に付与する。

grant usage on schema public to service_role;
grant select, insert, update, delete on public.employees to service_role;
grant select, insert, update, delete on public.seats to service_role;
grant select, insert, update, delete on public.shifts to service_role;
grant select, insert, update, delete on public.products to service_role;
grant select, insert, update, delete on public.shop_settings to service_role;
