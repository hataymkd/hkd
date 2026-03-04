begin;

create table if not exists public.job_posts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references public.organizations(id) on delete set null,
  created_by uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text not null,
  city text not null,
  district text,
  employment_type text not null default 'full_time',
  vehicle_type text not null default 'motorcycle',
  salary_min numeric(12,2),
  salary_max numeric(12,2),
  currency text not null default 'TRY',
  status text not null default 'open',
  contact_phone text,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_posts_title_not_blank_chk
    check (length(trim(title)) > 0),
  constraint job_posts_description_not_blank_chk
    check (length(trim(description)) > 0),
  constraint job_posts_city_not_blank_chk
    check (length(trim(city)) > 0),
  constraint job_posts_employment_type_allowed_chk
    check (employment_type in ('full_time', 'part_time', 'freelance', 'shift')),
  constraint job_posts_vehicle_type_allowed_chk
    check (vehicle_type in ('motorcycle', 'scooter', 'car', 'van', 'bicycle', 'any')),
  constraint job_posts_currency_format_chk
    check (currency ~ '^[A-Z]{3}$'),
  constraint job_posts_status_allowed_chk
    check (status in ('open', 'paused', 'closed')),
  constraint job_posts_salary_min_positive_chk
    check (salary_min is null or salary_min >= 0),
  constraint job_posts_salary_max_positive_chk
    check (salary_max is null or salary_max >= 0),
  constraint job_posts_salary_range_chk
    check (
      salary_min is null
      or salary_max is null
      or salary_max >= salary_min
    ),
  constraint job_posts_contact_phone_e164_chk
    check (
      contact_phone is null
      or contact_phone ~ '^\+[1-9][0-9]{7,14}$'
    ),
  constraint job_posts_expiry_after_create_chk
    check (expires_at is null or expires_at > created_at)
);

create index if not exists job_posts_status_created_at_idx
  on public.job_posts (status, created_at desc);

create index if not exists job_posts_city_status_idx
  on public.job_posts (city, status, created_at desc);

create index if not exists job_posts_org_id_created_at_idx
  on public.job_posts (org_id, created_at desc);

create index if not exists job_posts_created_by_created_at_idx
  on public.job_posts (created_by, created_at desc);

drop trigger if exists trg_job_posts_set_updated_at on public.job_posts;
create trigger trg_job_posts_set_updated_at
before update on public.job_posts
for each row
execute function public.set_updated_at();

create table if not exists public.job_applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.job_posts(id) on delete cascade,
  applicant_user_id uuid not null references public.profiles(id) on delete cascade,
  note text,
  status text not null default 'pending',
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint job_applications_unique_job_applicant unique (job_id, applicant_user_id),
  constraint job_applications_status_allowed_chk
    check (status in ('pending', 'shortlisted', 'rejected', 'hired', 'withdrawn')),
  constraint job_applications_review_state_chk
    check (
      (status = 'pending' and reviewed_by is null and reviewed_at is null)
      or
      (status = 'withdrawn' and reviewed_by is null and reviewed_at is null)
      or
      (
        status in ('shortlisted', 'rejected', 'hired')
        and reviewed_by is not null
        and reviewed_at is not null
      )
    )
);

create index if not exists job_applications_applicant_created_at_idx
  on public.job_applications (applicant_user_id, created_at desc);

create index if not exists job_applications_job_status_created_at_idx
  on public.job_applications (job_id, status, created_at desc);

create index if not exists job_applications_reviewed_by_idx
  on public.job_applications (reviewed_by);

create table if not exists public.courier_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  headline text,
  bio text,
  city text,
  district text,
  vehicle_type text not null default 'motorcycle',
  years_experience int not null default 0,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint courier_profiles_vehicle_type_allowed_chk
    check (vehicle_type in ('motorcycle', 'scooter', 'car', 'van', 'bicycle', 'any')),
  constraint courier_profiles_experience_non_negative_chk
    check (years_experience >= 0)
);

create index if not exists courier_profiles_available_city_idx
  on public.courier_profiles (is_available, city, updated_at desc);

create index if not exists courier_profiles_vehicle_available_idx
  on public.courier_profiles (vehicle_type, is_available, updated_at desc);

drop trigger if exists trg_courier_profiles_set_updated_at on public.courier_profiles;
create trigger trg_courier_profiles_set_updated_at
before update on public.courier_profiles
for each row
execute function public.set_updated_at();

commit;
