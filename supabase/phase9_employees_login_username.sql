-- 既存プロジェクトへ employees.login_username 列を追加する差分SQL。
-- 内容はschema.sqlに恒久的に反映済み。
-- 自己登録(新規登録画面)時に入力した「ユーザー名(ログイン用)」の平文を保存する列。
-- 内部的にはtoSyntheticEmail()でダミーメール化してSupabase Authに渡しているため、
-- auth.usersからは平文のユーザー名を(anon/authenticatedロールでは)取得できない。
-- 従業員マスタ一覧に表示名の横でログイン用ユーザー名を出すため、平文をここに複製保存する。
-- 管理者が直接追加した従業員(ログインアカウント未作成)はnullのまま。
alter table public.employees add column if not exists login_username text;
