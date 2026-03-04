begin;

create or replace function public.claim_initial_president()
returns table (
  ok boolean,
  message text,
  user_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_existing_president uuid;
begin
  if v_uid is null then
    raise exception 'Authenticated user required.';
  end if;

  select ur.user_id
  into v_existing_president
  from public.user_roles ur
  where ur.role_key = 'president'
  limit 1;

  if v_existing_president is not null then
    return query
    select false, 'Baskan rolu zaten atanmis.', v_existing_president;
    return;
  end if;

  update public.profiles p
  set
    is_active = true,
    approved_by = v_uid,
    approved_at = now()
  where p.id = v_uid;

  if not found then
    raise exception 'Profile record not found.';
  end if;

  insert into public.user_roles (user_id, role_key)
  values (v_uid, 'president')
  on conflict (user_id, role_key) do nothing;

  insert into public.user_roles (user_id, role_key)
  values (v_uid, 'member')
  on conflict (user_id, role_key) do nothing;

  begin
    insert into public.audit_logs (
      actor_id,
      action,
      entity,
      entity_id,
      meta
    )
    values (
      v_uid,
      'claim_initial_president',
      'profiles',
      v_uid,
      jsonb_build_object('source', 'app_bootstrap')
    );
  exception
    when others then
      null;
  end;

  return query
  select true, 'Baskan rolu basariyla atandi.', v_uid;

exception
  when unique_violation then
    select ur.user_id
    into v_existing_president
    from public.user_roles ur
    where ur.role_key = 'president'
    limit 1;

    return query
    select false, 'Baskan rolu zaten atanmis.', coalesce(v_existing_president, v_uid);
end;
$$;

revoke all on function public.claim_initial_president() from public;
grant execute on function public.claim_initial_president() to authenticated;

commit;
