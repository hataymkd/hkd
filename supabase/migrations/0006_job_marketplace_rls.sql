begin;

grant select, insert, update, delete on table public.job_posts to authenticated;
grant select, insert, update, delete on table public.job_applications to authenticated;
grant select, insert, update, delete on table public.courier_profiles to authenticated;

create or replace function public.can_manage_job_post(p_job_id uuid, p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_job_id is null or p_uid is null then false
    else exists (
      select 1
      from public.job_posts jp
      where jp.id = p_job_id
        and (
          public.is_admin_or_president(p_uid)
          or jp.created_by = p_uid
          or (
            jp.org_id is not null
            and public.has_org_role(
              jp.org_id,
              p_uid,
              array['owner', 'manager']::text[]
            )
          )
        )
    )
  end;
$$;

grant execute on function public.can_manage_job_post(uuid, uuid) to authenticated;

alter table public.job_posts enable row level security;
alter table public.job_applications enable row level security;
alter table public.courier_profiles enable row level security;

drop policy if exists job_posts_select_open_or_manage_active on public.job_posts;
create policy job_posts_select_open_or_manage_active
on public.job_posts
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    status = 'open'
    or public.can_manage_job_post(id, auth.uid())
  )
);

drop policy if exists job_posts_insert_owner_manager_or_admin_active on public.job_posts;
create policy job_posts_insert_owner_manager_or_admin_active
on public.job_posts
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and created_by = auth.uid()
  and (
    public.is_admin_or_president(auth.uid())
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

drop policy if exists job_posts_update_owner_manager_or_admin_active on public.job_posts;
create policy job_posts_update_owner_manager_or_admin_active
on public.job_posts
for update
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.can_manage_job_post(id, auth.uid())
)
with check (
  public.is_user_active(auth.uid())
  and (
    public.is_admin_or_president(auth.uid())
    or created_by = auth.uid()
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

drop policy if exists job_posts_delete_owner_manager_or_admin_active on public.job_posts;
create policy job_posts_delete_owner_manager_or_admin_active
on public.job_posts
for delete
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.can_manage_job_post(id, auth.uid())
);

drop policy if exists job_applications_select_applicant_or_manager_active on public.job_applications;
create policy job_applications_select_applicant_or_manager_active
on public.job_applications
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    applicant_user_id = auth.uid()
    or public.can_manage_job_post(job_id, auth.uid())
  )
);

drop policy if exists job_applications_insert_applicant_active on public.job_applications;
create policy job_applications_insert_applicant_active
on public.job_applications
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and applicant_user_id = auth.uid()
  and status = 'pending'
  and reviewed_by is null
  and reviewed_at is null
  and exists (
    select 1
    from public.job_posts jp
    where jp.id = job_id
      and jp.status = 'open'
  )
);

drop policy if exists job_applications_update_applicant_withdraw_active on public.job_applications;
create policy job_applications_update_applicant_withdraw_active
on public.job_applications
for update
to authenticated
using (
  public.is_user_active(auth.uid())
  and applicant_user_id = auth.uid()
  and status = 'pending'
)
with check (
  public.is_user_active(auth.uid())
  and applicant_user_id = auth.uid()
  and status = 'withdrawn'
  and reviewed_by is null
  and reviewed_at is null
);

drop policy if exists job_applications_update_manager_review_active on public.job_applications;
create policy job_applications_update_manager_review_active
on public.job_applications
for update
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.can_manage_job_post(job_id, auth.uid())
)
with check (
  public.is_user_active(auth.uid())
  and public.can_manage_job_post(job_id, auth.uid())
  and (
    (status = 'pending' and reviewed_by is null and reviewed_at is null)
    or (
      status in ('shortlisted', 'rejected', 'hired')
      and reviewed_by = auth.uid()
      and reviewed_at is not null
    )
  )
);

drop policy if exists job_applications_delete_manager_or_admin_active on public.job_applications;
create policy job_applications_delete_manager_or_admin_active
on public.job_applications
for delete
to authenticated
using (
  public.is_user_active(auth.uid())
  and public.can_manage_job_post(job_id, auth.uid())
);

drop policy if exists courier_profiles_select_active on public.courier_profiles;
create policy courier_profiles_select_active
on public.courier_profiles
for select
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    user_id = auth.uid()
    or is_available = true
    or public.is_admin_or_president(auth.uid())
    or exists (
      select 1
      from public.organization_members om
      where om.user_id = auth.uid()
        and om.status = 'active'
        and om.org_role = any(array['owner', 'manager']::text[])
    )
  )
);

drop policy if exists courier_profiles_insert_own_active on public.courier_profiles;
create policy courier_profiles_insert_own_active
on public.courier_profiles
for insert
to authenticated
with check (
  public.is_user_active(auth.uid())
  and user_id = auth.uid()
);

drop policy if exists courier_profiles_update_own_or_admin_active on public.courier_profiles;
create policy courier_profiles_update_own_or_admin_active
on public.courier_profiles
for update
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    user_id = auth.uid()
    or public.is_admin_or_president(auth.uid())
  )
)
with check (
  public.is_user_active(auth.uid())
  and (
    user_id = auth.uid()
    or public.is_admin_or_president(auth.uid())
  )
);

drop policy if exists courier_profiles_delete_own_or_admin_active on public.courier_profiles;
create policy courier_profiles_delete_own_or_admin_active
on public.courier_profiles
for delete
to authenticated
using (
  public.is_user_active(auth.uid())
  and (
    user_id = auth.uid()
    or public.is_admin_or_president(auth.uid())
  )
);

commit;
