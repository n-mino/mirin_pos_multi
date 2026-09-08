-- 既存プロジェクトへ shifts.frozen_wage 列を追加する差分SQL。
-- 内容はschema.sqlに恒久的に反映済み。
-- 支払い済み(paid_date)にした時点の時給(時給+ランク別時給アップ額)を固定保存する列。
-- 以降、従業員マスタの時給・ランク別時給アップ額を変更しても、この列に値がある
-- 支払い済みレコードの金額計算には影響しない(未固定はnull)。
alter table public.shifts add column if not exists frozen_wage numeric;
