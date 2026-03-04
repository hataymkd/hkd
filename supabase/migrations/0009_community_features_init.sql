begin;

create table if not exists public.community_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  location text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  status text not null default 'published',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_events_title_not_blank_chk
    check (length(trim(title)) > 0),
  constraint community_events_description_not_blank_chk
    check (length(trim(description)) > 0),
  constraint community_events_status_allowed_chk
    check (status in ('draft', 'published', 'cancelled', 'completed')),
  constraint community_events_end_after_start_chk
    check (ends_at is null or ends_at > starts_at)
);

create index if not exists community_events_status_starts_at_idx
  on public.community_events (status, starts_at asc);

create index if not exists community_events_created_by_created_at_idx
  on public.community_events (created_by, created_at desc);

drop trigger if exists trg_community_events_set_updated_at on public.community_events;
create trigger trg_community_events_set_updated_at
before update on public.community_events
for each row
execute function public.set_updated_at();

create table if not exists public.community_event_rsvps (
  event_id uuid not null references public.community_events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'going',
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id),
  constraint community_event_rsvps_status_allowed_chk
    check (status in ('going', 'interested', 'not_going'))
);

create index if not exists community_event_rsvps_user_status_idx
  on public.community_event_rsvps (user_id, status, updated_at desc);

drop trigger if exists trg_community_event_rsvps_set_updated_at on public.community_event_rsvps;
create trigger trg_community_event_rsvps_set_updated_at
before update on public.community_event_rsvps
for each row
execute function public.set_updated_at();

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid references public.organizations(id) on delete set null,
  title text not null,
  description text not null,
  category text not null default 'general',
  priority text not null default 'normal',
  status text not null default 'open',
  assigned_to uuid references public.profiles(id) on delete set null,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint support_tickets_title_not_blank_chk
    check (length(trim(title)) > 0),
  constraint support_tickets_description_not_blank_chk
    check (length(trim(description)) > 0),
  constraint support_tickets_category_allowed_chk
    check (category in ('general', 'membership', 'payment', 'job', 'technical', 'other')),
  constraint support_tickets_priority_allowed_chk
    check (priority in ('low', 'normal', 'high', 'urgent')),
  constraint support_tickets_status_allowed_chk
    check (status in ('open', 'in_progress', 'resolved', 'closed'))
);

create index if not exists support_tickets_user_status_created_idx
  on public.support_tickets (user_id, status, created_at desc);

create index if not exists support_tickets_assigned_status_idx
  on public.support_tickets (assigned_to, status, updated_at desc);

create index if not exists support_tickets_org_status_idx
  on public.support_tickets (org_id, status, created_at desc);

drop trigger if exists trg_support_tickets_set_updated_at on public.support_tickets;
create trigger trg_support_tickets_set_updated_at
before update on public.support_tickets
for each row
execute function public.set_updated_at();

create table if not exists public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  body text not null,
  is_internal boolean not null default false,
  created_at timestamptz not null default now(),
  constraint support_ticket_messages_body_not_blank_chk
    check (length(trim(body)) > 0)
);

create index if not exists support_ticket_messages_ticket_created_idx
  on public.support_ticket_messages (ticket_id, created_at asc);

create index if not exists support_ticket_messages_sender_created_idx
  on public.support_ticket_messages (sender_id, created_at desc);

create table if not exists public.safety_incidents (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  org_id uuid references public.organizations(id) on delete set null,
  title text not null,
  details text not null,
  severity text not null default 'high',
  status text not null default 'open',
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  contact_phone text,
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint safety_incidents_title_not_blank_chk
    check (length(trim(title)) > 0),
  constraint safety_incidents_details_not_blank_chk
    check (length(trim(details)) > 0),
  constraint safety_incidents_severity_allowed_chk
    check (severity in ('low', 'medium', 'high', 'critical')),
  constraint safety_incidents_status_allowed_chk
    check (status in ('open', 'acknowledged', 'closed')),
  constraint safety_incidents_latitude_range_chk
    check (latitude is null or (latitude >= -90 and latitude <= 90)),
  constraint safety_incidents_longitude_range_chk
    check (longitude is null or (longitude >= -180 and longitude <= 180)),
  constraint safety_incidents_contact_phone_e164_chk
    check (contact_phone is null or contact_phone ~ '^\+[1-9][0-9]{7,14}$'),
  constraint safety_incidents_resolution_pair_chk
    check (
      (status in ('open', 'acknowledged') and resolved_by is null and resolved_at is null)
      or
      (status = 'closed' and resolved_by is not null and resolved_at is not null)
    )
);

create index if not exists safety_incidents_status_created_idx
  on public.safety_incidents (status, created_at desc);

create index if not exists safety_incidents_reporter_created_idx
  on public.safety_incidents (reporter_id, created_at desc);

create index if not exists safety_incidents_org_status_idx
  on public.safety_incidents (org_id, status, created_at desc);

drop trigger if exists trg_safety_incidents_set_updated_at on public.safety_incidents;
create trigger trg_safety_incidents_set_updated_at
before update on public.safety_incidents
for each row
execute function public.set_updated_at();

create table if not exists public.payment_reconciliation_logs (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid references public.payments(id) on delete set null,
  invoice_id uuid references public.dues_invoices(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  previous_status text,
  next_status text not null,
  reason text,
  provider_ref text,
  created_at timestamptz not null default now(),
  constraint payment_reconciliation_logs_status_allowed_chk
    check (
      (previous_status is null or previous_status in ('created', 'succeeded', 'failed', 'refunded'))
      and next_status in ('created', 'succeeded', 'failed', 'refunded')
    )
);

create index if not exists payment_reconciliation_logs_payment_created_idx
  on public.payment_reconciliation_logs (payment_id, created_at desc);

create index if not exists payment_reconciliation_logs_invoice_created_idx
  on public.payment_reconciliation_logs (invoice_id, created_at desc);

create index if not exists payment_reconciliation_logs_actor_created_idx
  on public.payment_reconciliation_logs (actor_id, created_at desc);

create or replace function public.can_manage_event(p_event_id uuid, p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_event_id is null or p_uid is null then false
    else exists (
      select 1
      from public.community_events ce
      where ce.id = p_event_id
        and (
          public.is_admin_or_president(p_uid)
          or ce.created_by = p_uid
        )
    )
  end;
$$;

create or replace function public.can_view_support_ticket(p_ticket_id uuid, p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_ticket_id is null or p_uid is null then false
    else exists (
      select 1
      from public.support_tickets st
      where st.id = p_ticket_id
        and (
          public.is_admin_or_president(p_uid)
          or st.user_id = p_uid
          or st.assigned_to = p_uid
          or (
            st.org_id is not null
            and public.has_org_role(
              st.org_id,
              p_uid,
              array['owner', 'manager']::text[]
            )
          )
        )
    )
  end;
$$;

create or replace function public.can_manage_support_ticket(p_ticket_id uuid, p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_ticket_id is null or p_uid is null then false
    else exists (
      select 1
      from public.support_tickets st
      where st.id = p_ticket_id
        and (
          public.is_admin_or_president(p_uid)
          or st.assigned_to = p_uid
          or (
            st.org_id is not null
            and public.has_org_role(
              st.org_id,
              p_uid,
              array['owner', 'manager']::text[]
            )
          )
        )
    )
  end;
$$;

grant execute on function public.can_manage_event(uuid, uuid) to authenticated;
grant execute on function public.can_view_support_ticket(uuid, uuid) to authenticated;
grant execute on function public.can_manage_support_ticket(uuid, uuid) to authenticated;

commit;
