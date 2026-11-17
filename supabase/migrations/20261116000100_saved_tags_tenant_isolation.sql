create extension if not exists pgcrypto;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now()
);

create table public.organization_memberships (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create index organization_memberships_user_id_idx
  on public.organization_memberships(user_id);

create table public.saved_tags (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete set null,
  tag_uid text not null,
  tag_data jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_user_id, tag_uid)
);

create index saved_tags_organization_id_idx
  on public.saved_tags(organization_id)
  where organization_id is not null;

create or replace function public.set_saved_tag_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger saved_tags_updated_at
before update on public.saved_tags
for each row execute function public.set_saved_tag_updated_at();

alter table public.organizations enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.saved_tags enable row level security;

create policy "Members can view their organizations"
on public.organizations
for select
to authenticated
using (
  exists (
    select 1
    from public.organization_memberships membership
    where membership.organization_id = organizations.id
      and membership.user_id = (select auth.uid())
  )
);

create policy "Users can view their own memberships"
on public.organization_memberships
for select
to authenticated
using (user_id = (select auth.uid()));

create policy "Users can view owned or shared saved tags"
on public.saved_tags
for select
to authenticated
using (
  owner_user_id = (select auth.uid())
  or exists (
    select 1
    from public.organization_memberships membership
    where membership.organization_id = saved_tags.organization_id
      and membership.user_id = (select auth.uid())
  )
);

create policy "Users can create their own private or member-shared tags"
on public.saved_tags
for insert
to authenticated
with check (
  owner_user_id = (select auth.uid())
  and (
    organization_id is null
    or exists (
      select 1
      from public.organization_memberships membership
      where membership.organization_id = saved_tags.organization_id
        and membership.user_id = (select auth.uid())
    )
  )
);

create policy "Owners can update their own saved tags"
on public.saved_tags
for update
to authenticated
using (owner_user_id = (select auth.uid()))
with check (
  owner_user_id = (select auth.uid())
  and (
    organization_id is null
    or exists (
      select 1
      from public.organization_memberships membership
      where membership.organization_id = saved_tags.organization_id
        and membership.user_id = (select auth.uid())
    )
  )
);

create policy "Owners can delete their own saved tags"
on public.saved_tags
for delete
to authenticated
using (owner_user_id = (select auth.uid()));

grant select on public.organizations, public.organization_memberships to authenticated;
grant select, insert, update, delete on public.saved_tags to authenticated;
