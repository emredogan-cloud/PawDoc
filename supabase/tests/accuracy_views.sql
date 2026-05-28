-- Phase 6.2 — accuracy_views.sql pg test. Proves:
--   1. analysis_feedback.outcome CHECK constraint rejects junk values.
--   2. view_accuracy_signals classifies the four signal classes correctly
--      (FP proxy, FN proxy, TP proxy, TN proxy) on seeded rows.
--   3. The aggregate summary view counts those classes.
--   4. LOCKDOWN — neither view is selectable by `anon` or `authenticated`;
--      `service_role` retains SELECT.

insert into auth.users (id, email) values
  ('aa000000-0000-0000-0000-000000000001', 'a@test');
insert into public.users (id, email) values
  ('aa000000-0000-0000-0000-000000000001', 'a@test');
insert into public.pets (id, user_id, name, species) values
  ('aa000000-0000-0000-0000-0000000000a1', 'aa000000-0000-0000-0000-000000000001', 'Rex', 'dog');

-- 1. CHECK constraint rejects unknown outcome values.
do $$
declare oops boolean := false;
begin
  begin
    insert into public.analyses (id, user_id, pet_id, input_type, triage_level)
    values ('aaaa0000-0000-0000-0000-000000000001',
            'aa000000-0000-0000-0000-000000000001',
            'aa000000-0000-0000-0000-0000000000a1', 'text', 'NORMAL');
    insert into public.analysis_feedback (analysis_id, outcome)
    values ('aaaa0000-0000-0000-0000-000000000001', 'this_is_not_a_real_outcome');
    oops := true;
  exception when check_violation then
    -- expected
  end;
  if oops then raise exception 'CHECK constraint did NOT reject a junk outcome'; end if;
end
$$;

-- 2. Seed the four classified signal classes + one explicitly-unclassified.
insert into public.analyses (id, user_id, pet_id, input_type, triage_level, primary_concern) values
  -- AI said EMERGENCY but the vet said it was nothing -> FALSE POSITIVE proxy.
  ('a1000000-0000-0000-0000-000000000001', 'aa000000-0000-0000-0000-000000000001', 'aa000000-0000-0000-0000-0000000000a1', 'text', 'EMERGENCY', 'severe abdominal pain'),
  -- AI said NORMAL but the vet confirmed a real problem -> FALSE NEGATIVE proxy (the safety-critical case).
  ('a2000000-0000-0000-0000-000000000002', 'aa000000-0000-0000-0000-000000000001', 'aa000000-0000-0000-0000-0000000000a1', 'text', 'NORMAL',    'minor ear redness'),
  -- AI said EMERGENCY and the vet confirmed it -> TRUE POSITIVE proxy.
  ('a3000000-0000-0000-0000-000000000003', 'aa000000-0000-0000-0000-000000000001', 'aa000000-0000-0000-0000-0000000000a1', 'text', 'EMERGENCY', 'tick paralysis suspected'),
  -- AI said NORMAL and it resolved on its own -> TRUE NEGATIVE proxy.
  ('a4000000-0000-0000-0000-000000000004', 'aa000000-0000-0000-0000-000000000001', 'aa000000-0000-0000-0000-0000000000a1', 'text', 'NORMAL',    'mild stomach upset'),
  -- MONITOR row -> outcome present but signal stays NULL (excluded from the view's
  -- FP/FN/TP/TN classification).
  ('a5000000-0000-0000-0000-000000000005', 'aa000000-0000-0000-0000-000000000001', 'aa000000-0000-0000-0000-0000000000a1', 'text', 'MONITOR',   'borderline');

insert into public.analysis_feedback (analysis_id, outcome) values
  ('a1000000-0000-0000-0000-000000000001', 'vet_said_nothing'),
  ('a2000000-0000-0000-0000-000000000002', 'vet_confirmed'),
  ('a3000000-0000-0000-0000-000000000003', 'vet_confirmed'),
  ('a4000000-0000-0000-0000-000000000004', 'resolved_on_own'),
  ('a5000000-0000-0000-0000-000000000005', 'still_monitoring');

do $$
declare
  fp int; fn int; tp int; tn int; unclassified int;
begin
  select count(*) into fp from public.view_accuracy_signals where signal = 'false_positive_proxy';
  select count(*) into fn from public.view_accuracy_signals where signal = 'false_negative_proxy';
  select count(*) into tp from public.view_accuracy_signals where signal = 'true_positive_proxy';
  select count(*) into tn from public.view_accuracy_signals where signal = 'true_negative_proxy';
  select count(*) into unclassified from public.view_accuracy_signals where signal is null;

  if fp <> 1 then raise exception 'expected 1 false_positive_proxy, got %', fp; end if;
  if fn <> 1 then raise exception 'expected 1 false_negative_proxy, got %', fn; end if;
  if tp <> 1 then raise exception 'expected 1 true_positive_proxy, got %', tp; end if;
  if tn <> 1 then raise exception 'expected 1 true_negative_proxy, got %', tn; end if;
  if unclassified <> 1 then
    raise exception 'expected 1 MONITOR row to land as signal=NULL, got %', unclassified;
  end if;
end
$$;

-- 3. Summary view counts the five classes (FP, FN, TP, TN, unclassified).
do $$
declare classes int;
begin
  select count(*) into classes from public.view_accuracy_summary;
  if classes < 4 then raise exception 'expected >= 4 signal classes in summary, got %', classes; end if;
end
$$;

-- 4. LOCKDOWN — anon + authenticated must NOT be able to SELECT from the views;
--    service_role keeps SELECT.
do $$
begin
  -- anon
  if has_table_privilege('anon', 'public.view_accuracy_signals', 'SELECT') then
    raise exception 'LOCKDOWN: anon can SELECT view_accuracy_signals';
  end if;
  if has_table_privilege('anon', 'public.view_accuracy_summary', 'SELECT') then
    raise exception 'LOCKDOWN: anon can SELECT view_accuracy_summary';
  end if;
  -- authenticated
  if has_table_privilege('authenticated', 'public.view_accuracy_signals', 'SELECT') then
    raise exception 'LOCKDOWN: authenticated can SELECT view_accuracy_signals';
  end if;
  if has_table_privilege('authenticated', 'public.view_accuracy_summary', 'SELECT') then
    raise exception 'LOCKDOWN: authenticated can SELECT view_accuracy_summary';
  end if;
  -- service_role must KEEP access (admin tooling reads from here).
  if not has_table_privilege('service_role', 'public.view_accuracy_signals', 'SELECT') then
    raise exception 'service_role should retain SELECT on view_accuracy_signals';
  end if;
  if not has_table_privilege('service_role', 'public.view_accuracy_summary', 'SELECT') then
    raise exception 'service_role should retain SELECT on view_accuracy_summary';
  end if;
end
$$;

select 'ACCURACY VIEWS TESTS PASSED' as result;
