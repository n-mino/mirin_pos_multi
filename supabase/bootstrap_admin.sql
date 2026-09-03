-- 管理者アカウントのブートストラップ用SQL。
-- ユーザー名部分(下記の 'mirin_adm' の左側)を実際に登録したユーザー名に
-- 合わせて書き換えてから実行してください。
--
-- 新規登録時に不具合でemployees行の作成に失敗していた場合の救済も兼ねており、
-- 行が無ければ作成、既にあれば admin・承認済みに更新する(何度実行しても安全)。

insert into public.employees (id, name, hourly_wage, role, auth_user_id, approved)
select
  'emp_' || floor(extract(epoch from now()))::text || '_' || substr(md5(random()::text), 1, 6),
  'mirin_adm',
  0,
  'admin',
  id,
  true
from auth.users
where email = 'mirin_adm@mirin-pos.internal'
on conflict (auth_user_id) do update set role = 'admin', approved = true;
