-- 退職済み(active=false)アカウントが、UIのログイン画面だけでなくAPI経由でも
-- データにアクセスできてしまわないよう、is_approved()/is_admin()の判定に
-- active=falseの条件を追加する(既存プロジェクト用の差分SQL)。
-- 内容はschema.sqlに恒久的に反映済み。

create or replace function public.is_approved()
returns boolean
language sql security definer stable
as $$
  select exists (
    select 1 from public.employees
    where auth_user_id = auth.uid() and approved = true and active = true
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql security definer stable
as $$
  select exists (
    select 1 from public.employees
    where auth_user_id = auth.uid() and approved = true and active = true and role = 'admin'
  );
$$;
