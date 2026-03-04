begin;

create or replace function public.has_role(p_uid uuid, p_role_key text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_uid is null then false
    else exists (
      select 1
      from public.user_roles ur
      where ur.user_id = p_uid
        and ur.role_key = p_role_key
    )
  end;
$$;

create or replace function public.is_admin(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_role(p_uid, 'admin');
$$;

create or replace function public.is_president(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_role(p_uid, 'president');
$$;

create or replace function public.is_admin_or_president(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin(p_uid) or public.is_president(p_uid);
$$;

create or replace function public.is_user_active(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_uid is null then false
    else exists (
      select 1
      from public.profiles p
      where p.id = p_uid
        and p.is_active = true
    )
  end;
$$;

create or replace function public.has_org_role(p_org_id uuid, p_uid uuid, p_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_org_id is null or p_uid is null then false
    else exists (
      select 1
      from public.organization_members om
      where om.org_id = p_org_id
        and om.user_id = p_uid
        and om.status = 'active'
        and om.org_role = any(p_roles)
    )
  end;
$$;

create or replace function public.is_org_member(p_org_id uuid, p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_org_role(
    p_org_id,
    p_uid,
    array['owner', 'manager', 'staff']::text[]
  );
$$;

create or replace function public.get_membership_application_status(
  p_application_id uuid
)
returns table (
  id uuid,
  full_name text,
  phone text,
  member_type text,
  org_name text,
  org_phone text,
  org_tax_no text,
  requested_org_role text,
  status text,
  reject_reason text,
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ma.id,
    ma.full_name,
    ma.phone,
    ma.member_type,
    ma.org_name,
    ma.org_phone,
    ma.org_tax_no,
    ma.requested_org_role,
    ma.status,
    ma.reject_reason,
    ma.reviewed_by,
    ma.reviewed_at,
    ma.created_at
  from public.membership_applications ma
  where ma.id = p_application_id
  limit 1;
$$;

grant execute on function public.has_role(uuid, text) to anon, authenticated;
grant execute on function public.is_admin(uuid) to anon, authenticated;
grant execute on function public.is_president(uuid) to anon, authenticated;
grant execute on function public.is_admin_or_president(uuid) to anon, authenticated;
grant execute on function public.is_user_active(uuid) to anon, authenticated;
grant execute on function public.has_org_role(uuid, uuid, text[]) to anon, authenticated;
grant execute on function public.is_org_member(uuid, uuid) to anon, authenticated;
grant execute on function public.get_membership_application_status(uuid) to anon, authenticated;

grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.roles to authenticated;
grant select, insert, update, delete on table public.user_roles to authenticated;
grant select, insert, update, delete on table public.organizations to authenticated;
grant select, insert, update, delete on table public.organization_members to authenticated;
grant select on table public.announcements to anon, authenticated;
grant insert, update, delete on table public.announcements to authenticated;
grant insert on table public.membership_applications to anon, authenticated;
grant select, update on table public.membership_applications to authenticated;
grant select, insert, update, delete on table public.invites to authenticated;
grant select on table public.dues_periods to authenticated;
grant insert, update, delete on table public.dues_periods to authenticated;
grant select on table public.dues_invoices to authenticated;
grant insert, update, delete on table public.dues_invoices to authenticated;
grant select on table public.payments to authenticated;
grant insert, update, delete on table public.payments to authenticated;
grant select on table public.audit_logs to authenticated;
grant insert on table public.audit_logs to service_role;

alter table public.profiles enable row level security;
alter table public.roles enable row level security;
alter table public.user_roles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.announcements enable row level security;
alter table public.membership_applications enable row level security;
alter table public.invites enable row level security;
alter table public.dues_periods enable row level security;
alter table public.dues_invoices enable row level security;
alter table public.payments enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own
on public.profiles
for select
to authenticated
using (id = auth.uid());

drop policy if exists profiles_select_admin_or_president_active on public.profiles;
create policy profiles_select_admin_or_president_active
on public.profiles
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists profiles_select_org_owner_manager_active on public.profiles;
create policy profiles_select_org_owner_manager_active
on public.profiles
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and exists (
    select 1
    from public.organization_members actor
    join public.organization_members member
      on member.org_id = actor.org_id
    where actor.user_id = auth.uid()
      and actor.status = 'active'
      and actor.org_role = any(array['owner', 'manager']::text[])
      and member.user_id = id
      and member.status = any(array['active', 'pending']::text[])
  )
);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (
  id = auth.uid()
  and is_active = (
    select p.is_active
    from public.profiles p
    where p.id = auth.uid()
  )
  and approved_by is not distinct from (
    select p.approved_by
    from public.profiles p
    where p.id = auth.uid()
  )
  and approved_at is not distinct from (
    select p.approved_at
    from public.profiles p
    where p.id = auth.uid()
  )
);

drop policy if exists profiles_update_admin_or_president_active on public.profiles;
create policy profiles_update_admin_or_president_active
on public.profiles
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

drop policy if exists roles_select_active_authenticated on public.roles;
create policy roles_select_active_authenticated
on public.roles
for select
to authenticated
using (public.is_user_active(auth.uid()));

drop policy if exists roles_manage_admin_or_president_active on public.roles;
create policy roles_manage_admin_or_president_active
on public.roles
for all
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
)
with check (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists user_roles_select_own_active on public.user_roles;
create policy user_roles_select_own_active
on public.user_roles
for select
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists user_roles_select_admin_or_president_active on public.user_roles;
create policy user_roles_select_admin_or_president_active
on public.user_roles
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists user_roles_manage_admin_or_president_active on public.user_roles;
create policy user_roles_manage_admin_or_president_active
on public.user_roles
for all
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
)
with check (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists organizations_select_admin_or_president_active on public.organizations;
create policy organizations_select_admin_or_president_active
on public.organizations
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists organizations_select_org_members_active on public.organizations;
create policy organizations_select_org_members_active
on public.organizations
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_org_member(id, auth.uid())
);

drop policy if exists organizations_insert_admin_or_self_active on public.organizations;
create policy organizations_insert_admin_or_self_active
on public.organizations
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and (
    public.is_admin_or_president(auth.uid())
    or created_by = auth.uid()
  )
);

drop policy if exists organizations_update_admin_or_owner_manager_active on public.organizations;
create policy organizations_update_admin_or_owner_manager_active
on public.organizations
for update
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    public.is_admin_or_president(auth.uid())
    or public.has_org_role(id, auth.uid(), array['owner', 'manager']::text[])
  )
)
with check (
  public.is_user_active(auth.uid())
  and (
    public.is_admin_or_president(auth.uid())
    or public.has_org_role(id, auth.uid(), array['owner', 'manager']::text[])
  )
);

drop policy if exists organizations_delete_admin_or_president_active on public.organizations;
create policy organizations_delete_admin_or_president_active
on public.organizations
for delete
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists organization_members_select_own_active on public.organization_members;
create policy organization_members_select_own_active
on public.organization_members
for select
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists organization_members_select_owner_manager_active on public.organization_members;
create policy organization_members_select_owner_manager_active
on public.organization_members
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.has_org_role(org_id, auth.uid(), array['owner', 'manager']::text[])
);

drop policy if exists organization_members_select_admin_or_president_active on public.organization_members;
create policy organization_members_select_admin_or_president_active
on public.organization_members
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists organization_members_manage_owner_manager_or_admin_active on public.organization_members;
create policy organization_members_manage_owner_manager_or_admin_active
on public.organization_members
for all
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    public.is_admin_or_president(auth.uid())
    or public.has_org_role(org_id, auth.uid(), array['owner', 'manager']::text[])
  )
)
with check (
  public.is_user_active(auth.uid())
  and (
    public.is_admin_or_president(auth.uid())
    or public.has_org_role(org_id, auth.uid(), array['owner', 'manager']::text[])
  )
);

drop policy if exists announcements_select_published on public.announcements;
create policy announcements_select_published
on public.announcements
for select
to anon, authenticated
using (
  status = 'published'
  and (
    auth.role() = 'anon'
    or public.is_user_active(auth.uid())
  )
);

drop policy if exists announcements_select_admin_or_president_active on public.announcements;
create policy announcements_select_admin_or_president_active
on public.announcements
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists announcements_insert_admin_or_president_active on public.announcements;
create policy announcements_insert_admin_or_president_active
on public.announcements
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
  and created_by = auth.uid()
);

drop policy if exists announcements_update_admin_or_president_active on public.announcements;
create policy announcements_update_admin_or_president_active
on public.announcements
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

drop policy if exists announcements_delete_admin_or_president_active on public.announcements;
create policy announcements_delete_admin_or_president_active
on public.announcements
for delete
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists membership_applications_insert_public on public.membership_applications;
create policy membership_applications_insert_public
on public.membership_applications
for insert
to anon, authenticated
with check (
  status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and reject_reason is null
);

drop policy if exists membership_applications_select_admin_or_president_active on public.membership_applications;
create policy membership_applications_select_admin_or_president_active
on public.membership_applications
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists membership_applications_select_by_tracking_id on public.membership_applications;
create policy membership_applications_select_by_tracking_id
on public.membership_applications
for select
to authenticated
using (
  id::text = coalesce(auth.jwt() ->> 'membership_application_id', '')
);

drop policy if exists membership_applications_update_admin_or_president_active on public.membership_applications;
create policy membership_applications_update_admin_or_president_active
on public.membership_applications
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

drop policy if exists invites_select_owner_manager_or_admin_active on public.invites;
create policy invites_select_owner_manager_or_admin_active
on public.invites
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    public.is_admin_or_president(auth.uid())
    or public.has_org_role(org_id, auth.uid(), array['owner', 'manager']::text[])
  )
);

drop policy if exists invites_insert_owner_manager_or_admin_active on public.invites;
create policy invites_insert_owner_manager_or_admin_active
on public.invites
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and created_by = auth.uid()
  and status = 'pending'
  and accepted_user_id is null
  and accepted_at is null
  and expires_at > now()
  and (
    public.is_admin_or_president(auth.uid())
    or public.has_org_role(org_id, auth.uid(), array['owner', 'manager']::text[])
  )
);

drop policy if exists invites_update_owner_manager_or_admin_active on public.invites;
create policy invites_update_owner_manager_or_admin_active
on public.invites
for update
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    public.is_admin_or_president(auth.uid())
    or public.has_org_role(org_id, auth.uid(), array['owner', 'manager']::text[])
  )
)
with check (
  public.is_user_active(auth.uid())
  and (
    public.is_admin_or_president(auth.uid())
    or public.has_org_role(org_id, auth.uid(), array['owner', 'manager']::text[])
  )
);

drop policy if exists invites_delete_owner_manager_or_admin_active on public.invites;
create policy invites_delete_owner_manager_or_admin_active
on public.invites
for delete
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    public.is_admin_or_president(auth.uid())
    or public.has_org_role(org_id, auth.uid(), array['owner', 'manager']::text[])
  )
);

drop policy if exists dues_periods_select_active_authenticated on public.dues_periods;
create policy dues_periods_select_active_authenticated
on public.dues_periods
for select
to authenticated
using (public.is_user_active(auth.uid()));

drop policy if exists dues_periods_manage_admin_or_president_active on public.dues_periods;
create policy dues_periods_manage_admin_or_president_active
on public.dues_periods
for all
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
)
with check (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists dues_invoices_select_own_active on public.dues_invoices;
create policy dues_invoices_select_own_active
on public.dues_invoices
for select
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists dues_invoices_select_admin_or_president_active on public.dues_invoices;
create policy dues_invoices_select_admin_or_president_active
on public.dues_invoices
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists dues_invoices_manage_admin_or_president_active on public.dues_invoices;
create policy dues_invoices_manage_admin_or_president_active
on public.dues_invoices
for all
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
)
with check (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists payments_select_own_active on public.payments;
create policy payments_select_own_active
on public.payments
for select
to authenticated
using (
  user_id = auth.uid()
  and public.is_user_active(auth.uid())
);

drop policy if exists payments_select_admin_or_president_active on public.payments;
create policy payments_select_admin_or_president_active
on public.payments
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists payments_manage_admin_or_president_active on public.payments;
create policy payments_manage_admin_or_president_active
on public.payments
for all
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
)
with check (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists audit_logs_select_admin_or_president_active on public.audit_logs;
create policy audit_logs_select_admin_or_president_active
on public.audit_logs
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.is_admin_or_president(auth.uid())
);

drop policy if exists audit_logs_insert_service_role on public.audit_logs;
create policy audit_logs_insert_service_role
on public.audit_logs
for insert
to service_role
with check (true);

drop policy if exists audit_logs_insert_block_clients on public.audit_logs;
create policy audit_logs_insert_block_clients
on public.audit_logs
for insert
to anon, authenticated
with check (false);

commit;
