begin;

create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  category text not null default 'general',
  is_read boolean not null default false,
  read_at timestamptz,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint user_notifications_title_not_blank_chk
    check (length(trim(title)) > 0),
  constraint user_notifications_body_not_blank_chk
    check (length(trim(body)) > 0),
  constraint user_notifications_category_allowed_chk
    check (category in ('general', 'announcement', 'membership', 'payment', 'job'))
);

create index if not exists user_notifications_user_unread_idx
  on public.user_notifications (user_id, is_read, created_at desc);

create index if not exists user_notifications_category_created_idx
  on public.user_notifications (category, created_at desc);

create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint device_push_tokens_platform_allowed_chk
    check (platform in ('android', 'ios', 'web', 'unknown'))
);

create unique index if not exists device_push_tokens_user_token_uq
  on public.device_push_tokens (user_id, token);

create index if not exists device_push_tokens_active_idx
  on public.device_push_tokens (is_active, updated_at desc);

drop trigger if exists trg_device_push_tokens_set_updated_at on public.device_push_tokens;
create trigger trg_device_push_tokens_set_updated_at
before update on public.device_push_tokens
for each row
execute function public.set_updated_at();

create table if not exists public.payment_checkout_sessions (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid references public.payments(id) on delete set null,
  invoice_id uuid not null references public.dues_invoices(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null default 'manual',
  checkout_ref text,
  checkout_url text,
  status text not null default 'created',
  expires_at timestamptz,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payment_checkout_sessions_status_allowed_chk
    check (status in ('created', 'redirected', 'succeeded', 'failed', 'cancelled', 'expired'))
);

create index if not exists payment_checkout_sessions_user_status_idx
  on public.payment_checkout_sessions (user_id, status, created_at desc);

create index if not exists payment_checkout_sessions_invoice_created_idx
  on public.payment_checkout_sessions (invoice_id, created_at desc);

drop trigger if exists trg_payment_checkout_sessions_set_updated_at on public.payment_checkout_sessions;
create trigger trg_payment_checkout_sessions_set_updated_at
before update on public.payment_checkout_sessions
for each row
execute function public.set_updated_at();

create or replace function public.enqueue_announcement_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_body text;
begin
  if new.status <> 'published' then
    return new;
  end if;

  normalized_body := regexp_replace(coalesce(new.content, ''), '\s+', ' ', 'g');
  if length(normalized_body) > 240 then
    normalized_body := left(normalized_body, 240) || '...';
  end if;

  insert into public.user_notifications (
    user_id,
    title,
    body,
    category,
    meta
  )
  select
    p.id,
    new.title,
    normalized_body,
    'announcement',
    jsonb_build_object(
      'announcement_id', new.id,
      'created_at', new.created_at
    )
  from public.profiles p
  where p.is_active = true
    and p.id <> new.created_by;

  return new;
end;
$$;

drop trigger if exists trg_announcements_enqueue_notifications on public.announcements;
create trigger trg_announcements_enqueue_notifications
after insert on public.announcements
for each row
execute function public.enqueue_announcement_notifications();

create or replace function public.admin_report_snapshot()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  actor uuid := auth.uid();
  v_active_users int := 0;
  v_pending_users int := 0;
  v_total_orgs int := 0;
  v_pending_apps int := 0;
  v_open_jobs int := 0;
  v_pending_invoices int := 0;
  v_overdue_invoices int := 0;
  v_total_due numeric(14,2) := 0;
  v_outstanding numeric(14,2) := 0;
  v_unread_notifications int := 0;
begin
  if actor is null or not public.is_admin_or_president(actor) then
    raise exception 'forbidden';
  end if;

  select count(*) into v_active_users
  from public.profiles
  where is_active = true;

  select count(*) into v_pending_users
  from public.profiles
  where is_active = false;

  select count(*) into v_total_orgs
  from public.organizations;

  select count(*) into v_pending_apps
  from public.membership_applications
  where status = 'pending';

  select count(*) into v_open_jobs
  from public.job_posts
  where status = 'open';

  select count(*) into v_pending_invoices
  from public.dues_invoices
  where status = 'unpaid';

  select count(*) into v_overdue_invoices
  from public.dues_invoices
  where status = 'overdue';

  select coalesce(sum(amount), 0)::numeric(14,2) into v_total_due
  from public.dues_invoices;

  select coalesce(sum(amount), 0)::numeric(14,2) into v_outstanding
  from public.dues_invoices
  where status in ('unpaid', 'overdue');

  select count(*) into v_unread_notifications
  from public.user_notifications
  where is_read = false;

  return jsonb_build_object(
    'generated_at', now(),
    'active_users', v_active_users,
    'pending_users', v_pending_users,
    'total_organizations', v_total_orgs,
    'pending_applications', v_pending_apps,
    'open_jobs', v_open_jobs,
    'pending_invoices', v_pending_invoices,
    'overdue_invoices', v_overdue_invoices,
    'total_due_amount', v_total_due,
    'outstanding_amount', v_outstanding,
    'unread_notifications', v_unread_notifications
  );
end;
$$;

grant execute on function public.admin_report_snapshot() to authenticated;

commit;
