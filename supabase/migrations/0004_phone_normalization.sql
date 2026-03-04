begin;

create or replace function public.normalize_e164_phone(raw_phone text)
returns text
language plpgsql
immutable
as $$
declare
  v_clean text;
begin
  if raw_phone is null then
    return null;
  end if;

  v_clean := regexp_replace(trim(raw_phone), '[^0-9+]', '', 'g');
  if v_clean = '' then
    return null;
  end if;

  if v_clean ~ '^\+[1-9][0-9]{7,14}$' then
    return v_clean;
  end if;

  if v_clean ~ '^0[0-9]{10}$' then
    return '+90' || substring(v_clean from 2);
  end if;

  if v_clean ~ '^90[0-9]{10}$' then
    return '+' || v_clean;
  end if;

  if v_clean ~ '^[1-9][0-9]{7,14}$' then
    return '+' || v_clean;
  end if;

  return null;
end;
$$;

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
    public.normalize_e164_phone(new.phone),
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

update public.profiles
set phone = public.normalize_e164_phone(phone)
where phone is not null
  and phone !~ '^\+[1-9][0-9]{7,14}$';

alter table public.profiles
  drop constraint if exists profiles_phone_e164_chk;

alter table public.profiles
  add constraint profiles_phone_e164_chk
  check (phone is null or phone ~ '^\+[1-9][0-9]{7,14}$');

commit;
