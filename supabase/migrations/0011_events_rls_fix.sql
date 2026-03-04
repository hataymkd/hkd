begin;

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
);

commit;
