begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  is_active boolean not null default false,
  approved_by uuid references public.profiles(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_phone_e164_chk
    check (phone is null or phone ~ '^\+[1-9][0-9]{7,14}$'),
  constraint profiles_approval_pair_chk
    check (
      (approved_by is null and approved_at is null)
      or
      (approved_by is not null and approved_at is not null)
    )
);

create unique index if not exists profiles_phone_unique_idx
  on public.profiles (phone)
  where phone is not null;

create index if not exists profiles_is_active_idx
  on public.profiles (is_active);

create index if not exists profiles_approved_by_idx
  on public.profiles (approved_by);

create table if not exists public.roles (
  key text primary key,
  title text not null,
  constraint roles_key_allowed_chk
    check (key in ('president', 'admin', 'member'))
);

create table if not exists public.user_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  role_key text not null references public.roles(key),
  created_at timestamptz not null default now(),
  primary key (user_id, role_key)
);

create index if not exists user_roles_role_key_idx
  on public.user_roles (role_key);

create unique index if not exists user_roles_single_president_idx
  on public.user_roles (role_key)
  where role_key = 'president';

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  name text not null,
  phone text,
  tax_no text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint organizations_type_allowed_chk
    check (type in ('business', 'courier_company')),
  constraint organizations_phone_e164_chk
    check (phone is null or phone ~ '^\+[1-9][0-9]{7,14}$')
);

create index if not exists organizations_type_created_at_idx
  on public.organizations (type, created_at desc);

create index if not exists organizations_created_by_idx
  on public.organizations (created_by);

create table if not exists public.organization_members (
  org_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  org_role text not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  primary key (org_id, user_id),
  constraint organization_members_org_role_allowed_chk
    check (org_role in ('owner', 'manager', 'staff')),
  constraint organization_members_status_allowed_chk
    check (status in ('pending', 'active'))
);

create unique index if not exists organization_members_single_owner_idx
  on public.organization_members (org_id)
  where org_role = 'owner';

create index if not exists organization_members_user_id_idx
  on public.organization_members (user_id);

create index if not exists organization_members_org_role_idx
  on public.organization_members (org_id, org_role);

create index if not exists organization_members_status_idx
  on public.organization_members (status, created_at desc);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text not null,
  status text not null default 'published',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint announcements_status_allowed_chk
    check (status in ('draft', 'published', 'archived'))
);

create index if not exists announcements_created_by_idx
  on public.announcements (created_by);

create index if not exists announcements_status_created_at_idx
  on public.announcements (status, created_at desc);

create table if not exists public.membership_applications (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text not null,
  member_type text not null default 'courier',
  org_name text,
  org_phone text,
  org_tax_no text,
  requested_org_role text default 'owner',
  meta jsonb not null default '{}'::jsonb,
  status text not null default 'pending',
  reject_reason text,
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint membership_applications_phone_e164_chk
    check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  constraint membership_applications_member_type_allowed_chk
    check (member_type in ('courier', 'courier_company', 'business')),
  constraint membership_applications_org_phone_e164_chk
    check (org_phone is null or org_phone ~ '^\+[1-9][0-9]{7,14}$'),
  constraint membership_applications_requested_org_role_allowed_chk
    check (
      requested_org_role is null
      or requested_org_role in ('owner', 'manager', 'staff')
    ),
  constraint membership_applications_meta_object_chk
    check (jsonb_typeof(meta) = 'object'),
  constraint membership_applications_org_fields_by_member_type_chk
    check (
      member_type = 'courier'
      or (
        member_type in ('courier_company', 'business')
        and org_name is not null
        and org_phone is not null
      )
    ),
  constraint membership_applications_status_allowed_chk
    check (status in ('pending', 'approved', 'rejected')),
  constraint membership_applications_review_state_chk
    check (
      (status = 'pending' and reviewed_by is null and reviewed_at is null and reject_reason is null)
      or
      (status = 'approved' and reviewed_by is not null and reviewed_at is not null and reject_reason is null)
      or
      (status = 'rejected' and reviewed_by is not null and reviewed_at is not null and reject_reason is not null)
    )
);

create index if not exists membership_applications_status_created_at_idx
  on public.membership_applications (status, created_at desc);

create index if not exists membership_applications_member_type_status_idx
  on public.membership_applications (member_type, status, created_at desc);

create index if not exists membership_applications_reviewed_by_idx
  on public.membership_applications (reviewed_by);

create table if not exists public.invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  phone text not null,
  token text not null unique,
  expires_at timestamptz not null,
  status text not null default 'pending',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  accepted_user_id uuid references public.profiles(id) on delete set null,
  accepted_at timestamptz,
  constraint invites_phone_e164_chk
    check (phone ~ '^\+[1-9][0-9]{7,14}$'),
  constraint invites_status_allowed_chk
    check (status in ('pending', 'accepted', 'expired', 'cancelled')),
  constraint invites_accept_state_chk
    check (
      (status = 'accepted' and accepted_user_id is not null and accepted_at is not null)
      or
      (status in ('pending', 'expired', 'cancelled') and accepted_user_id is null and accepted_at is null)
    ),
  constraint invites_expiry_after_create_chk
    check (expires_at > created_at)
);

create index if not exists invites_org_status_created_at_idx
  on public.invites (org_id, status, created_at desc);

create index if not exists invites_phone_status_created_at_idx
  on public.invites (phone, status, created_at desc);

create index if not exists invites_expires_at_idx
  on public.invites (expires_at);

create table if not exists public.dues_periods (
  id uuid primary key default gen_random_uuid(),
  year int not null,
  month int not null,
  period_key text not null unique,
  amount numeric(12,2) not null,
  due_date date not null,
  created_at timestamptz not null default now(),
  constraint dues_periods_year_range_chk
    check (year between 2000 and 2100),
  constraint dues_periods_month_range_chk
    check (month between 1 and 12),
  constraint dues_periods_period_key_format_chk
    check (period_key ~ '^\d{4}-(0[1-9]|1[0-2])$'),
  constraint dues_periods_period_key_match_chk
    check (period_key = (year::text || '-' || lpad(month::text, 2, '0'))),
  constraint dues_periods_amount_positive_chk
    check (amount > 0),
  constraint dues_periods_year_month_unique unique (year, month)
);

create index if not exists dues_periods_due_date_idx
  on public.dues_periods (due_date);

create table if not exists public.dues_invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  period_id uuid not null references public.dues_periods(id) on delete cascade,
  amount numeric(12,2) not null,
  status text not null default 'unpaid',
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, period_id),
  constraint dues_invoices_amount_positive_chk
    check (amount > 0),
  constraint dues_invoices_status_allowed_chk
    check (status in ('unpaid', 'paid', 'overdue')),
  constraint dues_invoices_paid_at_chk
    check (
      (status = 'paid' and paid_at is not null)
      or
      (status in ('unpaid', 'overdue') and paid_at is null)
    )
);

create index if not exists dues_invoices_user_status_idx
  on public.dues_invoices (user_id, status);

create index if not exists dues_invoices_period_status_idx
  on public.dues_invoices (period_id, status);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid references public.dues_invoices(id) on delete set null,
  user_id uuid references public.profiles(id) on delete set null,
  amount numeric(12,2) not null,
  provider text,
  provider_ref text,
  status text not null default 'created',
  created_at timestamptz not null default now(),
  constraint payments_amount_positive_chk
    check (amount > 0),
  constraint payments_status_allowed_chk
    check (status in ('created', 'succeeded', 'failed', 'refunded'))
);

create index if not exists payments_invoice_id_idx
  on public.payments (invoice_id);

create index if not exists payments_user_status_created_at_idx
  on public.payments (user_id, status, created_at desc);

create index if not exists payments_provider_ref_idx
  on public.payments (provider_ref);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity text not null,
  entity_id uuid,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_logs_actor_created_at_idx
  on public.audit_logs (actor_id, created_at desc);

create index if not exists audit_logs_entity_entity_id_idx
  on public.audit_logs (entity, entity_id);

drop trigger if exists trg_profiles_set_updated_at on public.profiles;
create trigger trg_profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists trg_announcements_set_updated_at on public.announcements;
create trigger trg_announcements_set_updated_at
before update on public.announcements
for each row
execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    full_name,
    phone,
    is_active,
    approved_by,
    approved_at
  )
  values (
    new.id,
    nullif(coalesce(new.raw_user_meta_data ->> 'full_name', ''), ''),
    new.phone,
    false,
    null,
    null
  )
  on conflict (id) do update
  set
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    phone = coalesce(excluded.phone, public.profiles.phone),
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

insert into public.roles (key, title)
values
  ('president', 'Baskan'),
  ('admin', 'Yonetici'),
  ('member', 'Uye')
on conflict (key) do update
set title = excluded.title;

commit;
