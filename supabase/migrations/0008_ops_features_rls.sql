begin;

grant select, update on table public.user_notifications to authenticated;
grant insert on table public.user_notifications to service_role;

grant select, insert, update on table public.device_push_tokens to authenticated;

grant select on table public.payment_checkout_sessions to authenticated;
grant insert, update on table public.payment_checkout_sessions to service_role;

alter table public.user_notifications enable row level security;
alter table public.device_push_tokens enable row level security;
alter table public.payment_checkout_sessions enable row level security;

drop policy if exists user_notifications_select_own_active on public.user_notifications;
create policy user_notifications_select_own_active
on public.user_notifications
for select
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists user_notifications_select_admin_or_president_active on public.user_notifications;
create policy user_notifications_select_admin_or_president_active
on public.user_notifications
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists user_notifications_update_own_active on public.user_notifications;
create policy user_notifications_update_own_active
on public.user_notifications
for update
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
)
with check (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists user_notifications_insert_service_role on public.user_notifications;
create policy user_notifications_insert_service_role
on public.user_notifications
for insert
to service_role
with check (true);

drop policy if exists user_notifications_insert_block_clients on public.user_notifications;
create policy user_notifications_insert_block_clients
on public.user_notifications
for insert
to anon, authenticated
with check (false);

drop policy if exists device_push_tokens_select_own_active on public.device_push_tokens;
create policy device_push_tokens_select_own_active
on public.device_push_tokens
for select
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists device_push_tokens_select_admin_or_president_active on public.device_push_tokens;
create policy device_push_tokens_select_admin_or_president_active
on public.device_push_tokens
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists device_push_tokens_insert_own_active on public.device_push_tokens;
create policy device_push_tokens_insert_own_active
on public.device_push_tokens
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists device_push_tokens_update_own_active on public.device_push_tokens;
create policy device_push_tokens_update_own_active
on public.device_push_tokens
for update
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
)
with check (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists payment_checkout_sessions_select_own_active on public.payment_checkout_sessions;
create policy payment_checkout_sessions_select_own_active
on public.payment_checkout_sessions
for select
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists payment_checkout_sessions_select_admin_or_president_active on public.payment_checkout_sessions;
create policy payment_checkout_sessions_select_admin_or_president_active
on public.payment_checkout_sessions
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists payment_checkout_sessions_insert_service_role on public.payment_checkout_sessions;
create policy payment_checkout_sessions_insert_service_role
on public.payment_checkout_sessions
for insert
to service_role
with check (true);

drop policy if exists payment_checkout_sessions_update_service_role on public.payment_checkout_sessions;
create policy payment_checkout_sessions_update_service_role
on public.payment_checkout_sessions
for update
to service_role
using (true)
with check (true);

drop policy if exists payment_checkout_sessions_insert_block_clients on public.payment_checkout_sessions;
create policy payment_checkout_sessions_insert_block_clients
on public.payment_checkout_sessions
for insert
to anon, authenticated
with check (false);

drop policy if exists payment_checkout_sessions_update_block_clients on public.payment_checkout_sessions;
create policy payment_checkout_sessions_update_block_clients
on public.payment_checkout_sessions
for update
to anon, authenticated
using (false)
with check (false);

commit;
