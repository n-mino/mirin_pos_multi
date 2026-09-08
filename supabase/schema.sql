-- ============================================================================
-- mirin_pos_multi — フェーズ0 初期スキーマ
-- Supabaseダッシュボード「SQL Editor」に貼り付けて実行してください。
-- 既存の pos-app-pwa (localStorage版) には一切影響しません。
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- employees: 従業員マスタ + ログインアカウントの紐付け
-- ----------------------------------------------------------------------------
create table if not exists public.employees (
  id text primary key,                                   -- 既存アプリの uid("emp") 形式をそのまま流用
  name text not null,
  hourly_wage numeric not null default 0,
  role text not null default 'staff' check (role in ('admin', 'staff')),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  approved boolean not null default false,
  active boolean not null default true,                  -- false=退職済み(勤怠実績が残るため物理削除せず無効化)
  login_username text,                                    -- 自己登録時のログイン用ユーザー名の平文(管理者直接追加の場合はnull)
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- seats: 座席状態(既存 data.seats[n] を1行1座席のテーブルに分離)
-- ----------------------------------------------------------------------------
create table if not exists public.seats (
  seat_no integer primary key,
  status text not null default 'empty' check (status in ('empty', 'occupied', 'awaiting_checkout')),
  guests integer,
  companion_name text not null default '',
  companion_employee_id text references public.employees(id),
  companion_kind text not null default '',
  start_time timestamptz,
  orders jsonb not null default '[]'::jsonb,
  checkout_draft jsonb,                                   -- サブ端末が提出した会計プレビュー(フェーズ3/4で使用)
  updated_at timestamptz not null default now(),
  updated_by text references public.employees(id)
);

-- ----------------------------------------------------------------------------
-- shifts: 勤怠(既存 data.payroll.shifts[] を1行1勤怠のテーブルに分離)
-- ----------------------------------------------------------------------------
create table if not exists public.shifts (
  id text primary key,                                    -- 既存の uid("shift") 形式
  employee_id text not null references public.employees(id),
  date date not null,
  start_time text not null,
  end_time text not null,
  rank_key text not null default '',
  daily_wage numeric not null default 0,
  option numeric not null default 0,
  option2 numeric not null default 0,
  note text not null default '',
  paid_date date,
  frozen_wage numeric,                                    -- 支払い済みにした時点の固定時給(nullは未固定)
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- products: 商品マスタ(既存 data.products[] とほぼ同じ列構成)
-- ----------------------------------------------------------------------------
create table if not exists public.products (
  id text primary key,
  name text not null,
  price numeric not null default 0,
  category text not null default '',
  sold_out boolean not null default false,
  bottle_back boolean not null default false,
  time_price jsonb
);

-- ----------------------------------------------------------------------------
-- shop_settings: 座席数・座席名・色分け閾値・税/サービス料率・ランク別加算額・
-- 売上バック率(店舗全体で1行のみの設定値。id=1固定)。
-- 売上履歴・入出金・パスワード設定は当面タブレット(管理者端末)のみで完結する
-- 想定のため対象外(将来的に必要になれば追加する)。
-- ----------------------------------------------------------------------------
create table if not exists public.shop_settings (
  id integer primary key default 1,
  seat_count integer not null default 5,
  seat_names jsonb not null default '{}'::jsonb,
  seat_tone_thresholds jsonb not null default '{"warnMinutes":30,"dangerMinutes":60}'::jsonb,
  service_charge_rate numeric not null default 0,
  tax_rate numeric not null default 10,
  rank_bonus_rates jsonb not null default '{"call":100,"companion":200,"other":0}'::jsonb,
  sales_back_rates jsonb not null default '{"over30k":10,"group5over50k":30,"bottle":10,"roundMode":"floor"}'::jsonb,
  updated_at timestamptz not null default now()
);

-- ============================================================================
-- テーブルレベルの権限付与
-- ============================================================================
-- プロジェクト作成時に「Automatically expose new tables」をOFFにしているため、
-- anon/authenticatedロールにはテーブルへの基本的なアクセス権限(GRANT)が
-- 自動付与されない。ここで明示的に付与し、実際の行ごとの制御はRLSポリシー
-- (このファイル後半)に委ねる(Supabase標準の運用パターン)。
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.employees to anon, authenticated;
grant select, insert, update, delete on public.seats to anon, authenticated;
grant select, insert, update, delete on public.shifts to anon, authenticated;
grant select, insert, update, delete on public.products to anon, authenticated;
grant select, insert, update, delete on public.shop_settings to anon, authenticated;

-- service_role(Edge Functionが使う管理者権限のキー)はRLSを無視できるが、
-- GRANT自体は別途必要(「Automatically expose new tables」OFF設定の影響で自動付与されない)。
grant usage on schema public to service_role;
grant select, insert, update, delete on public.employees to service_role;
grant select, insert, update, delete on public.seats to service_role;
grant select, insert, update, delete on public.shifts to service_role;
grant select, insert, update, delete on public.products to service_role;
grant select, insert, update, delete on public.shop_settings to service_role;

-- ============================================================================
-- ヘルパー関数(RLSポリシーから参照)
-- ============================================================================

-- ログイン中ユーザーが承認済み従業員かどうか
create or replace function public.is_approved()
returns boolean
language sql security definer stable
as $$
  select exists (
    select 1 from public.employees
    where auth_user_id = auth.uid() and approved = true and active = true
  );
$$;

-- ログイン中ユーザーが承認済み管理者かどうか
create or replace function public.is_admin()
returns boolean
language sql security definer stable
as $$
  select exists (
    select 1 from public.employees
    where auth_user_id = auth.uid() and approved = true and active = true and role = 'admin'
  );
$$;

-- ログイン中ユーザー自身の employees.id
create or replace function public.current_employee_id()
returns text
language sql security definer stable
as $$
  select id from public.employees where auth_user_id = auth.uid() limit 1;
$$;

-- ============================================================================
-- RLS(行レベルセキュリティ)有効化 + ポリシー
-- ============================================================================

alter table public.employees enable row level security;
alter table public.seats enable row level security;
alter table public.shifts enable row level security;
alter table public.products enable row level security;

-- --- employees --------------------------------------------------------------
-- 承認済み従業員は全員分を閲覧可。未承認ユーザーは自分の行のみ閲覧可(承認待ち状態の確認用)。
create policy "employees_select" on public.employees
  for select using (public.is_approved() or auth_user_id = auth.uid());

-- 新規登録: 自分の auth_user_id で、role='staff' かつ approved=false の行のみ作成可(自己承認・自己昇格を防止)。
create policy "employees_self_register" on public.employees
  for insert with check (
    auth_user_id = auth.uid() and role = 'staff' and approved = false
  );

-- 更新・削除は管理者のみ(承認・役割変更・時給変更など)。
-- 管理者がマスタ設定から直接従業員を追加する場合(ログインアカウント未作成の従業員)用。
create policy "employees_admin_insert" on public.employees
  for insert with check (public.is_admin());

create policy "employees_admin_update" on public.employees
  for update using (public.is_admin());

create policy "employees_admin_delete" on public.employees
  for delete using (public.is_admin());

-- --- seats -------------------------------------------------------------------
-- 承認済み従業員(admin/staff問わず)は座席の閲覧・作成・更新が可能。
-- 「確定は管理者のみ」はアプリ側のUIで担保する(フェーズ3/4で詳細実装)。
create policy "seats_select" on public.seats
  for select using (public.is_approved());

create policy "seats_upsert" on public.seats
  for insert with check (public.is_approved());

create policy "seats_update" on public.seats
  for update using (public.is_approved());

-- 座席の削除(行自体の削除)は管理者のみ。通常運用では status='empty' への更新のみで足りる想定。
create policy "seats_admin_delete" on public.seats
  for delete using (public.is_admin());

-- --- shifts --------------------------------------------------------------
-- 閲覧・作成・更新・削除: 管理者は全件、スタッフは自分の勤怠のみ。
create policy "shifts_select" on public.shifts
  for select using (public.is_admin() or employee_id = public.current_employee_id());

create policy "shifts_insert" on public.shifts
  for insert with check (public.is_admin() or employee_id = public.current_employee_id());

create policy "shifts_update" on public.shifts
  for update using (public.is_admin() or employee_id = public.current_employee_id());

create policy "shifts_delete" on public.shifts
  for delete using (public.is_admin() or employee_id = public.current_employee_id());

-- --- products ------------------------------------------------------------
-- 閲覧: 承認済み従業員全員。作成・更新・削除: 管理者のみ。
create policy "products_select" on public.products
  for select using (public.is_approved());

create policy "products_admin_write" on public.products
  for insert with check (public.is_admin());

create policy "products_admin_update" on public.products
  for update using (public.is_admin());

create policy "products_admin_delete" on public.products
  for delete using (public.is_admin());

-- --- shop_settings ---------------------------------------------------------
-- 閲覧: 承認済み従業員全員。作成・更新: 管理者のみ(1行のみのテーブルのため削除は用意しない)。
alter table public.shop_settings enable row level security;

create policy "shop_settings_select" on public.shop_settings
  for select using (public.is_approved());

create policy "shop_settings_admin_insert" on public.shop_settings
  for insert with check (public.is_admin());

create policy "shop_settings_admin_update" on public.shop_settings
  for update using (public.is_admin());

-- ============================================================================
-- Realtime有効化(各テーブルの変更をリアルタイム配信)
-- ============================================================================
alter publication supabase_realtime add table public.seats;
alter publication supabase_realtime add table public.shifts;
alter publication supabase_realtime add table public.shop_settings;
alter publication supabase_realtime add table public.employees;
alter publication supabase_realtime add table public.products;
