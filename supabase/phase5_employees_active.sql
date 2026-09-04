-- 既存プロジェクトへ employees.active 列を追加する差分SQL。
-- 内容はschema.sqlに恒久的に反映済み。
-- active=false は「退職済み」を意味する(勤怠実績が残る場合は物理削除せずここで無効化する)。
alter table public.employees add column if not exists active boolean not null default true;
