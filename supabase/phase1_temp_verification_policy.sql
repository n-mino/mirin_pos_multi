-- ============================================================================
-- フェーズ1 検証用の一時的なポリシー
-- ============================================================================
-- schema.sql の本来のRLSポリシーは「承認済み従業員のみ」書き込み可能だが、
-- フェーズ2(ログイン機能)がまだ実装されていないため、動作確認ができない。
-- この一時ポリシーで匿名(anon)キーからの seats テーブルへの
-- select/insert/update を許可し、シャドウ書き込みが実際にSupabaseへ届くかを
-- 確認する。
--
-- ⚠️ フェーズ2実装後、必ず drop_phase1_temp_verification_policy.sql を
--    実行してこのポリシーを削除すること(本番相当のRLSに戻すため)。
-- ============================================================================

create policy "TEMP_phase1_anon_seats_select" on public.seats
  for select using (true);

create policy "TEMP_phase1_anon_seats_write" on public.seats
  for insert with check (true);

create policy "TEMP_phase1_anon_seats_update" on public.seats
  for update using (true);
