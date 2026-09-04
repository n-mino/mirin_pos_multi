-- 既存プロジェクトへ shop_settings テーブルを追加する差分SQL。
-- 内容はschema.sqlに恒久的に反映済み(新規プロジェクトではschema.sqlのみでOK)。

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

grant select, insert, update, delete on public.shop_settings to anon, authenticated;

alter table public.shop_settings enable row level security;

create policy "shop_settings_select" on public.shop_settings
  for select using (public.is_approved());

create policy "shop_settings_admin_insert" on public.shop_settings
  for insert with check (public.is_admin());

create policy "shop_settings_admin_update" on public.shop_settings
  for update using (public.is_admin());

alter publication supabase_realtime add table public.shop_settings;
