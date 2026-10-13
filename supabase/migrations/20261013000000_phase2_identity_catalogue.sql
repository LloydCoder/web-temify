-- Web-Temify Phase 2: identity, catalogue primitives, and row-level security.
-- Supabase SQL migrations are the sole schema authority (ADR-0003).
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 120),
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name text not null check (char_length(name) between 1 and 120),
  description text,
  is_active boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.products (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references auth.users(id) on delete restrict,
  category_id uuid references public.categories(id) on delete restrict,
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name text not null check (char_length(name) between 1 and 180),
  description text not null default '',
  product_type text not null check (product_type in ('template', 'starter_kit', 'script', 'application', 'package', 'other')),
  status text not null default 'draft' check (status in ('draft', 'pending_review', 'published', 'rejected', 'archived')),
  price_minor bigint not null default 0 check (price_minor >= 0),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.audit_events (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null check (char_length(action) between 1 and 120),
  entity_type text not null check (char_length(entity_type) between 1 and 120),
  entity_id text,
  request_id text,
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);
create type public.app_role as enum ('customer', 'creator', 'moderator', 'admin');

create table public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

create function public.current_user_has_role(required_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $role$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.role = required_role
  );
$role$;
revoke all on function public.current_user_has_role(public.app_role) from public, anon, service_role;
grant execute on function public.current_user_has_role(public.app_role) to authenticated;

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
revoke all on function public.set_updated_at() from public, anon, authenticated;

-- Create a minimal profile on signup. User metadata is untrusted and is used only
-- for a bounded display name; it never assigns roles or permissions.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    left(coalesce(new.raw_user_meta_data ->> 'name', new.raw_user_meta_data ->> 'full_name', ''), 120)
  )
  on conflict (id) do nothing;
  insert into public.user_roles (user_id, role)
  values (new.id, 'customer'::public.app_role)
  on conflict (user_id, role) do nothing;
  return new;
end;
$function$;
revoke all on function public.handle_new_user() from public, anon, authenticated, service_role;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger categories_set_updated_at before update on public.categories for each row execute function public.set_updated_at();
create trigger products_set_updated_at before update on public.products for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.audit_events enable row level security;
alter table public.user_roles enable row level security;

revoke all on public.profiles, public.categories, public.products, public.audit_events, public.user_roles from anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select on public.categories to anon, authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select on public.products to anon;

create policy profiles_select_own on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy profiles_insert_own on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy categories_select_active on public.categories for select to anon, authenticated using (is_active);
create policy products_select_published_or_owner on public.products for select to anon, authenticated using (status = 'published' or creator_id = (select auth.uid()));
create policy products_insert_own_draft on public.products for insert to authenticated with check (creator_id = (select auth.uid()) and status = 'draft');
create policy products_update_own_draft on public.products for update to authenticated using (creator_id = (select auth.uid()) and status = 'draft') with check (creator_id = (select auth.uid()) and status = 'draft');
create policy products_delete_own_draft on public.products for delete to authenticated using (creator_id = (select auth.uid()) and status = 'draft');

-- Audit events are written by trusted server-side paths only. No client grants/policies.
revoke all on sequence public.audit_events_id_seq from anon, authenticated;
grant insert on public.audit_events to service_role;
grant select, insert, update, delete on public.user_roles to service_role;
grant usage, select on sequence public.audit_events_id_seq to service_role;
