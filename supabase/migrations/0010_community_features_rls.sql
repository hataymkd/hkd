begin;

grant select, insert, update, delete on table public.community_events to authenticated;
grant select, insert, update, delete on table public.community_event_rsvps to authenticated;
grant select, insert, update, delete on table public.support_tickets to authenticated;
grant select, insert on table public.support_ticket_messages to authenticated;
grant select, insert, update on table public.safety_incidents to authenticated;
grant select on table public.payment_reconciliation_logs to authenticated;
grant insert on table public.payment_reconciliation_logs to service_role;

alter table public.community_events enable row level security;
alter table public.community_event_rsvps enable row level security;
alter table public.support_tickets enable row level security;
alter table public.support_ticket_messages enable row level security;
alter table public.safety_incidents enable row level security;
alter table public.payment_reconciliation_logs enable row level security;

drop policy if exists community_events_select_active on public.community_events;
create policy community_events_select_active
on public.community_events
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    status = 'published'
    or public.can_manage_event(id, auth.uid())
  )
);

drop policy if exists community_events_manage_admin_or_president_active on public.community_events;
create policy community_events_manage_admin_or_president_active
on public.community_events
for all
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
)
with check (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
  and created_by = auth.uid()
);

drop policy if exists community_event_rsvps_select_active on public.community_event_rsvps;
create policy community_event_rsvps_select_active
on public.community_event_rsvps
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    user_id = auth.uid()
    or public.can_manage_event(event_id, auth.uid())
  )
);

drop policy if exists community_event_rsvps_insert_own_active on public.community_event_rsvps;
create policy community_event_rsvps_insert_own_active
on public.community_event_rsvps
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and user_id = auth.uid()
  and exists (
    select 1
    from public.community_events ce
    where ce.id = event_id
      and ce.status = 'published'
  )
);

drop policy if exists community_event_rsvps_update_own_active on public.community_event_rsvps;
create policy community_event_rsvps_update_own_active
on public.community_event_rsvps
for update
to authenticated
using (
  public.is_user_active(auth.uid())
  and user_id = auth.uid()
)
with check (
  public.is_user_active(auth.uid())
  and user_id = auth.uid()
);

drop policy if exists community_event_rsvps_delete_own_active on public.community_event_rsvps;
create policy community_event_rsvps_delete_own_active
on public.community_event_rsvps
for delete
to authenticated
using (
  public.is_user_active(auth.uid())
  and user_id = auth.uid()
);

drop policy if exists support_tickets_select_active on public.support_tickets;
create policy support_tickets_select_active
on public.support_tickets
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.can_view_support_ticket(id, auth.uid())
);

drop policy if exists support_tickets_insert_own_active on public.support_tickets;
create policy support_tickets_insert_own_active
on public.support_tickets
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and user_id = auth.uid()
  and (
    org_id is null
    or public.has_org_role(
      org_id,
      auth.uid(),
      array['owner', 'manager', 'staff']::text[]
    )
  )
  and status = 'open'
);

drop policy if exists support_tickets_update_manager_active on public.support_tickets;
create policy support_tickets_update_manager_active
on public.support_tickets
for update
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.can_manage_support_ticket(id, auth.uid())
)
with check (
  public.is_user_active(auth.uid())
  and public.can_manage_support_ticket(id, auth.uid())
);

drop policy if exists support_tickets_delete_admin_or_president_active on public.support_tickets;
create policy support_tickets_delete_admin_or_president_active
on public.support_tickets
for delete
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists support_ticket_messages_select_active on public.support_ticket_messages;
create policy support_ticket_messages_select_active
on public.support_ticket_messages
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and exists (
    select 1
    from public.support_tickets st
    where st.id = ticket_id
      and public.can_view_support_ticket(st.id, auth.uid())
      and (
        is_internal = false
        or public.can_manage_support_ticket(st.id, auth.uid())
      )
  )
);

drop policy if exists support_ticket_messages_insert_active on public.support_ticket_messages;
create policy support_ticket_messages_insert_active
on public.support_ticket_messages
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and sender_id = auth.uid()
  and exists (
    select 1
    from public.support_tickets st
    where st.id = ticket_id
      and public.can_view_support_ticket(st.id, auth.uid())
      and (
        is_internal = false
        or public.can_manage_support_ticket(st.id, auth.uid())
      )
  )
);

drop policy if exists safety_incidents_select_active on public.safety_incidents;
create policy safety_incidents_select_active
on public.safety_incidents
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    reporter_id = auth.uid()
    or public.is_admin_or_president(auth.uid())
    or (
      org_id is not null
      and public.has_org_role(
        org_id,
        auth.uid(),
        array['owner', 'manager']::text[]
      )
    )
  )
);

drop policy if exists safety_incidents_insert_own_active on public.safety_incidents;
create policy safety_incidents_insert_own_active
on public.safety_incidents
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and reporter_id = auth.uid()
  and (
    org_id is null
    or public.has_org_role(
      org_id,
      auth.uid(),
      array['owner', 'manager', 'staff']::text[]
    )
  )
);

drop policy if exists safety_incidents_update_admin_or_president_active on public.safety_incidents;
create policy safety_incidents_update_admin_or_president_active
on public.safety_incidents
for update
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
)
with check (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists payment_reconciliation_logs_select_admin_or_president_active on public.payment_reconciliation_logs;
create policy payment_reconciliation_logs_select_admin_or_president_active
on public.payment_reconciliation_logs
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists payment_reconciliation_logs_insert_service_role on public.payment_reconciliation_logs;
create policy payment_reconciliation_logs_insert_service_role
on public.payment_reconciliation_logs
for insert
to service_role
with check (true);

drop policy if exists payment_reconciliation_logs_insert_block_clients on public.payment_reconciliation_logs;
create policy payment_reconciliation_logs_insert_block_clients
on public.payment_reconciliation_logs
for insert
to anon, authenticated
with check (false);

commit;
