-- フェーズ2実装後、これを実行してフェーズ1検証用の一時ポリシーを削除する。
drop policy if exists "TEMP_phase1_anon_seats_select" on public.seats;
drop policy if exists "TEMP_phase1_anon_seats_write" on public.seats;
drop policy if exists "TEMP_phase1_anon_seats_update" on public.seats;
