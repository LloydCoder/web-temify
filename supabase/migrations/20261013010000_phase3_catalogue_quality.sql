-- Phase 3: catalogue quality metadata and evidence-gated product releases.
-- This migration extends the existing canonical Supabase SQL schema (ADR-0003).
alter table public.products
  add column summary text not null default '' check (char_length(summary) <= 500),
  add column tech_stack text[] not null default '{}',
  add column compatibility jsonb not null default '{}'::jsonb check (jsonb_typeof(compatibility) = 'object'),
  add column license_type text not null default 'standard'
    check (license_type in ('standard', 'commercial', 'extended', 'open_source', 'custom')),
  add column rights_status text not null default 'unverified'
    check (rights_status in ('unverified', 'declared', 'under_review', 'verified', 'rejected')),
  add column rights_statement text check (rights_statement is null or char_length(rights_statement) <= 4000),
  add column rights_verified_at timestamptz,
  add column rights_verified_by uuid references auth.users(id) on delete set null,
  add column release_version text not null default '0.1.0'
    check (release_version ~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'),
  add column artifact_sha256 text check (artifact_sha256 is null or artifact_sha256 ~ '^[a-f0-9]{64}$'),
  add column docs_url text check (docs_url is null or (char_length(docs_url) <= 2048 and docs_url ~ '^https://[^[:space:]]+
  add column demo_url text check (demo_url is null or (char_length(demo_url) <= 2048 and demo_url ~ '^https://[^[:space:]]+
  add column tags text[] not null default '{}',
  add column search_document tsvector generated always as (
    to_tsvector('english', coalesce(name, '') || ' ' || coalesce(summary, '') || ' ' || coalesce(description, ''))
  ) stored;

create index products_search_document_gin on public.products using gin (search_document);
create index products_public_catalogue_idx
  on public.products (name, created_at desc)
  where status = 'published' and rights_status = 'verified' and artifact_sha256 is not null;

-- A creator's statement is evidence to review, not automatic proof of ownership.
-- Only a trusted review path may promote a declaration to verified.
create table public.product_rights_attestations (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  attested_by uuid not null references auth.users(id) on delete restrict,
  rights_basis text not null check (rights_basis in ('original_work', 'authorized_distribution', 'open_source_compliance', 'licensed_assets', 'other')),
  statement text not null check (char_length(statement) between 20 and 4000),
  evidence_reference text check (evidence_reference is null or char_length(evidence_reference) <= 2048),
  review_status text not null default 'declared'
    check (review_status in ('declared', 'under_review', 'verified', 'rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_notes text check (review_notes is null or char_length(review_notes) <= 4000),
  created_at timestamptz not null default now(),
  constraint product_rights_review_consistency check (
    (review_status in ('verified', 'rejected') and reviewed_at is not null and reviewed_by is not null)
    or (review_status in ('declared', 'under_review') and reviewed_at is null)
  )
);
create index product_rights_attestations_product_idx
  on public.product_rights_attestations (product_id, created_at desc);

alter table public.products
  add constraint products_rights_verification_consistency check (
    rights_status <> 'verified'
    or (rights_verified_at is not null and rights_verified_by is not null and rights_verified_by <> creator_id)
  );

alter table public.product_rights_attestations
  add constraint product_rights_attestations_independent_review check (
    review_status not in ('verified', 'rejected') or reviewed_by <> attested_by
  );

-- Release records are immutable from ordinary creator sessions. A creator may submit a
-- draft release record, but only trusted release automation can promote it to released.
create table public.product_versions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  version text not null check (
    version ~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
  ),
  release_state text not null default 'draft' check (release_state in ('draft', 'in_review', 'released', 'withdrawn')),
  release_notes text not null default '' check (char_length(release_notes) <= 10000),
  artifact_sha256 text check (artifact_sha256 is null or artifact_sha256 ~ '^[a-f0-9]{64}$'),
  artifact_storage_path text check (artifact_storage_path is null or char_length(artifact_storage_path) <= 2048),
  manifest jsonb not null default '{}'::jsonb check (jsonb_typeof(manifest) = 'object'),
  compatibility jsonb not null default '{}'::jsonb check (jsonb_typeof(compatibility) = 'object'),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  released_at timestamptz,
  unique (product_id, version),
  constraint product_versions_release_evidence check (
    release_state <> 'released'
    or (artifact_sha256 is not null and artifact_storage_path is not null and released_at is not null)
  )
);
create index product_versions_product_idx on public.product_versions (product_id, created_at desc);

alter table public.product_rights_attestations enable row level security;
alter table public.product_versions enable row level security;

revoke all on public.product_rights_attestations, public.product_versions from anon, authenticated;
grant select, insert on public.product_rights_attestations to authenticated;
grant select, insert on public.product_versions to authenticated;
grant all on public.product_rights_attestations, public.product_versions to service_role;

-- Expose only a boolean release check to anonymous catalogue policy evaluation;
-- never grant public table access to artifact storage paths or release manifests.
create function public.product_has_verified_rights(target_product_id uuid, target_reviewer_id uuid, target_reviewed_at timestamptz)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.product_rights_attestations ra
    where ra.product_id = target_product_id
      and ra.review_status = 'verified'
      and ra.reviewed_by = target_reviewer_id
      and ra.reviewed_at = target_reviewed_at
  );
$function$;
revoke all on function public.product_has_verified_rights(uuid, uuid, timestamptz) from public, anon, authenticated, service_role;
grant execute on function public.product_has_verified_rights(uuid, uuid, timestamptz) to anon, authenticated;

create function public.product_has_verified_release(target_product_id uuid, target_artifact_sha256 text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.product_versions pv
    where pv.product_id = target_product_id
      and pv.release_state = 'released'
      and pv.artifact_sha256 = target_artifact_sha256
      and pv.artifact_storage_path is not null
      and pv.released_at is not null
  );
$function$;
revoke all on function public.product_has_verified_release(uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.product_has_verified_release(uuid, text) to anon, authenticated;

-- Remove table-wide product updates so creators cannot forge lifecycle, rights-review,
-- verifier, or artifact fields. Draft content remains editable by explicit column grant.
revoke update on public.products from authenticated;
grant update (category_id, slug, name, description, product_type, price_minor, currency,
  summary, tech_stack, compatibility, license_type, rights_statement, release_version,
  docs_url, demo_url, tags) on public.products to authenticated;

drop policy products_insert_own_draft on public.products;
create policy products_insert_own_draft on public.products
  for insert to authenticated
  with check (
    creator_id = (select auth.uid())
    and status = 'draft'
    and rights_status = 'unverified'
    and rights_verified_at is null
    and rights_verified_by is null
    and artifact_sha256 is null
  );

drop policy products_update_own_draft on public.products;
create policy products_update_own_draft on public.products
  for update to authenticated
  using (
    creator_id = (select auth.uid())
    and status = 'draft'
    and rights_status = 'unverified'
    and rights_verified_at is null
    and rights_verified_by is null
    and artifact_sha256 is null
  )
  with check (
    creator_id = (select auth.uid())
    and status = 'draft'
    and rights_status = 'unverified'
    and rights_verified_at is null
    and rights_verified_by is null
    and artifact_sha256 is null
  );

create policy rights_attestations_select_own on public.product_rights_attestations
  for select to authenticated
  using (exists (
    select 1 from public.products p
    where p.id = product_id and p.creator_id = (select auth.uid())
  ));
create policy rights_attestations_insert_own_draft on public.product_rights_attestations
  for insert to authenticated
  with check (
    attested_by = (select auth.uid())
    and review_status = 'declared'
    and reviewed_by is null
    and reviewed_at is null
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.creator_id = (select auth.uid()) and p.status = 'draft'
    )
  );

create policy product_versions_select_owner on public.product_versions
  for select to authenticated
  using (exists (
    select 1 from public.products p
    where p.id = product_id and p.creator_id = (select auth.uid())
  ));
create policy product_versions_insert_own_draft on public.product_versions
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and release_state = 'draft'
    and artifact_sha256 is null
    and released_at is null
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.creator_id = (select auth.uid()) and p.status = 'draft'
    )
  );

-- Public catalogue access requires both publication and independently verified rights,
-- plus a content-addressed artifact. Creator-owned drafts remain private to their owner.
drop policy products_select_published_or_owner on public.products;
create policy products_select_published_or_owner on public.products
  for select to anon, authenticated
  using (
    (
      status = 'published'
      and rights_status = 'verified'
      and rights_verified_at is not null
      and rights_verified_by is not null
      and public.product_has_verified_rights(id, rights_verified_by, rights_verified_at)
      and artifact_sha256 is not null
      and public.product_has_verified_release(id, artifact_sha256)
    )
    or creator_id = (select auth.uid())
  );
)),
  add column demo_url text check (demo_url is null or char_length(demo_url) <= 2048),
  add column tags text[] not null default '{}',
  add column search_document tsvector generated always as (
    to_tsvector('english', coalesce(name, '') || ' ' || coalesce(summary, '') || ' ' || coalesce(description, ''))
  ) stored;

create index products_search_document_gin on public.products using gin (search_document);
create index products_public_catalogue_idx
  on public.products (name, created_at desc)
  where status = 'published' and rights_status = 'verified' and artifact_sha256 is not null;

-- A creator's statement is evidence to review, not automatic proof of ownership.
-- Only a trusted review path may promote a declaration to verified.
create table public.product_rights_attestations (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  attested_by uuid not null references auth.users(id) on delete restrict,
  rights_basis text not null check (rights_basis in ('original_work', 'authorized_distribution', 'open_source_compliance', 'licensed_assets', 'other')),
  statement text not null check (char_length(statement) between 20 and 4000),
  evidence_reference text check (evidence_reference is null or char_length(evidence_reference) <= 2048),
  review_status text not null default 'declared'
    check (review_status in ('declared', 'under_review', 'verified', 'rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_notes text check (review_notes is null or char_length(review_notes) <= 4000),
  created_at timestamptz not null default now(),
  constraint product_rights_review_consistency check (
    (review_status in ('verified', 'rejected') and reviewed_at is not null and reviewed_by is not null)
    or (review_status in ('declared', 'under_review') and reviewed_at is null)
  )
);
create index product_rights_attestations_product_idx
  on public.product_rights_attestations (product_id, created_at desc);

alter table public.products
  add constraint products_rights_verification_consistency check (
    rights_status <> 'verified'
    or (rights_verified_at is not null and rights_verified_by is not null and rights_verified_by <> creator_id)
  );

alter table public.product_rights_attestations
  add constraint product_rights_attestations_independent_review check (
    review_status not in ('verified', 'rejected') or reviewed_by <> attested_by
  );

-- Release records are immutable from ordinary creator sessions. A creator may submit a
-- draft release record, but only trusted release automation can promote it to released.
create table public.product_versions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  version text not null check (
    version ~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
  ),
  release_state text not null default 'draft' check (release_state in ('draft', 'in_review', 'released', 'withdrawn')),
  release_notes text not null default '' check (char_length(release_notes) <= 10000),
  artifact_sha256 text check (artifact_sha256 is null or artifact_sha256 ~ '^[a-f0-9]{64}$'),
  artifact_storage_path text check (artifact_storage_path is null or char_length(artifact_storage_path) <= 2048),
  manifest jsonb not null default '{}'::jsonb check (jsonb_typeof(manifest) = 'object'),
  compatibility jsonb not null default '{}'::jsonb check (jsonb_typeof(compatibility) = 'object'),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  released_at timestamptz,
  unique (product_id, version),
  constraint product_versions_release_evidence check (
    release_state <> 'released'
    or (artifact_sha256 is not null and artifact_storage_path is not null and released_at is not null)
  )
);
create index product_versions_product_idx on public.product_versions (product_id, created_at desc);

alter table public.product_rights_attestations enable row level security;
alter table public.product_versions enable row level security;

revoke all on public.product_rights_attestations, public.product_versions from anon, authenticated;
grant select, insert on public.product_rights_attestations to authenticated;
grant select, insert on public.product_versions to authenticated;
grant all on public.product_rights_attestations, public.product_versions to service_role;

-- Expose only a boolean release check to anonymous catalogue policy evaluation;
-- never grant public table access to artifact storage paths or release manifests.
create function public.product_has_verified_release(target_product_id uuid, target_artifact_sha256 text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.product_versions pv
    where pv.product_id = target_product_id
      and pv.release_state = 'released'
      and pv.artifact_sha256 = target_artifact_sha256
      and pv.artifact_storage_path is not null
      and pv.released_at is not null
  );
$function$;
revoke all on function public.product_has_verified_release(uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.product_has_verified_release(uuid, text) to anon, authenticated;

create policy rights_attestations_select_own on public.product_rights_attestations
  for select to authenticated
  using (exists (
    select 1 from public.products p
    where p.id = product_id and p.creator_id = (select auth.uid())
  ));
create policy rights_attestations_insert_own_draft on public.product_rights_attestations
  for insert to authenticated
  with check (
    attested_by = (select auth.uid())
    and review_status = 'declared'
    and reviewed_by is null
    and reviewed_at is null
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.creator_id = (select auth.uid()) and p.status = 'draft'
    )
  );

create policy product_versions_select_owner on public.product_versions
  for select to authenticated
  using (exists (
    select 1 from public.products p
    where p.id = product_id and p.creator_id = (select auth.uid())
  ));
create policy product_versions_insert_own_draft on public.product_versions
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and release_state = 'draft'
    and artifact_sha256 is null
    and released_at is null
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.creator_id = (select auth.uid()) and p.status = 'draft'
    )
  );

-- Public catalogue access requires both publication and independently verified rights,
-- plus a content-addressed artifact. Creator-owned drafts remain private to their owner.
drop policy products_select_published_or_owner on public.products;
create policy products_select_published_or_owner on public.products
  for select to anon, authenticated
  using (
    (
      status = 'published'
      and rights_status = 'verified'
      and rights_verified_at is not null
      and rights_verified_by is not null
      and artifact_sha256 is not null
      and public.product_has_verified_release(id, artifact_sha256)
    )
    or creator_id = (select auth.uid())
  );
)),
  add column tags text[] not null default '{}',
  add column search_document tsvector generated always as (
    to_tsvector('english', coalesce(name, '') || ' ' || coalesce(summary, '') || ' ' || coalesce(description, ''))
  ) stored;

create index products_search_document_gin on public.products using gin (search_document);
create index products_public_catalogue_idx
  on public.products (name, created_at desc)
  where status = 'published' and rights_status = 'verified' and artifact_sha256 is not null;

-- A creator's statement is evidence to review, not automatic proof of ownership.
-- Only a trusted review path may promote a declaration to verified.
create table public.product_rights_attestations (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  attested_by uuid not null references auth.users(id) on delete restrict,
  rights_basis text not null check (rights_basis in ('original_work', 'authorized_distribution', 'open_source_compliance', 'licensed_assets', 'other')),
  statement text not null check (char_length(statement) between 20 and 4000),
  evidence_reference text check (evidence_reference is null or char_length(evidence_reference) <= 2048),
  review_status text not null default 'declared'
    check (review_status in ('declared', 'under_review', 'verified', 'rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_notes text check (review_notes is null or char_length(review_notes) <= 4000),
  created_at timestamptz not null default now(),
  constraint product_rights_review_consistency check (
    (review_status in ('verified', 'rejected') and reviewed_at is not null and reviewed_by is not null)
    or (review_status in ('declared', 'under_review') and reviewed_at is null)
  )
);
create index product_rights_attestations_product_idx
  on public.product_rights_attestations (product_id, created_at desc);

alter table public.products
  add constraint products_rights_verification_consistency check (
    rights_status <> 'verified'
    or (rights_verified_at is not null and rights_verified_by is not null and rights_verified_by <> creator_id)
  );

alter table public.product_rights_attestations
  add constraint product_rights_attestations_independent_review check (
    review_status not in ('verified', 'rejected') or reviewed_by <> attested_by
  );

-- Release records are immutable from ordinary creator sessions. A creator may submit a
-- draft release record, but only trusted release automation can promote it to released.
create table public.product_versions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  version text not null check (
    version ~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
  ),
  release_state text not null default 'draft' check (release_state in ('draft', 'in_review', 'released', 'withdrawn')),
  release_notes text not null default '' check (char_length(release_notes) <= 10000),
  artifact_sha256 text check (artifact_sha256 is null or artifact_sha256 ~ '^[a-f0-9]{64}$'),
  artifact_storage_path text check (artifact_storage_path is null or char_length(artifact_storage_path) <= 2048),
  manifest jsonb not null default '{}'::jsonb check (jsonb_typeof(manifest) = 'object'),
  compatibility jsonb not null default '{}'::jsonb check (jsonb_typeof(compatibility) = 'object'),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  released_at timestamptz,
  unique (product_id, version),
  constraint product_versions_release_evidence check (
    release_state <> 'released'
    or (artifact_sha256 is not null and artifact_storage_path is not null and released_at is not null)
  )
);
create index product_versions_product_idx on public.product_versions (product_id, created_at desc);

alter table public.product_rights_attestations enable row level security;
alter table public.product_versions enable row level security;

revoke all on public.product_rights_attestations, public.product_versions from anon, authenticated;
grant select, insert on public.product_rights_attestations to authenticated;
grant select, insert on public.product_versions to authenticated;
grant all on public.product_rights_attestations, public.product_versions to service_role;

-- Expose only a boolean release check to anonymous catalogue policy evaluation;
-- never grant public table access to artifact storage paths or release manifests.
create function public.product_has_verified_release(target_product_id uuid, target_artifact_sha256 text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.product_versions pv
    where pv.product_id = target_product_id
      and pv.release_state = 'released'
      and pv.artifact_sha256 = target_artifact_sha256
      and pv.artifact_storage_path is not null
      and pv.released_at is not null
  );
$function$;
revoke all on function public.product_has_verified_release(uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.product_has_verified_release(uuid, text) to anon, authenticated;

create policy rights_attestations_select_own on public.product_rights_attestations
  for select to authenticated
  using (exists (
    select 1 from public.products p
    where p.id = product_id and p.creator_id = (select auth.uid())
  ));
create policy rights_attestations_insert_own_draft on public.product_rights_attestations
  for insert to authenticated
  with check (
    attested_by = (select auth.uid())
    and review_status = 'declared'
    and reviewed_by is null
    and reviewed_at is null
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.creator_id = (select auth.uid()) and p.status = 'draft'
    )
  );

create policy product_versions_select_owner on public.product_versions
  for select to authenticated
  using (exists (
    select 1 from public.products p
    where p.id = product_id and p.creator_id = (select auth.uid())
  ));
create policy product_versions_insert_own_draft on public.product_versions
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and release_state = 'draft'
    and artifact_sha256 is null
    and released_at is null
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.creator_id = (select auth.uid()) and p.status = 'draft'
    )
  );

-- Public catalogue access requires both publication and independently verified rights,
-- plus a content-addressed artifact. Creator-owned drafts remain private to their owner.
drop policy products_select_published_or_owner on public.products;
create policy products_select_published_or_owner on public.products
  for select to anon, authenticated
  using (
    (
      status = 'published'
      and rights_status = 'verified'
      and rights_verified_at is not null
      and rights_verified_by is not null
      and artifact_sha256 is not null
      and public.product_has_verified_release(id, artifact_sha256)
    )
    or creator_id = (select auth.uid())
  );
)),
  add column demo_url text check (demo_url is null or char_length(demo_url) <= 2048),
  add column tags text[] not null default '{}',
  add column search_document tsvector generated always as (
    to_tsvector('english', coalesce(name, '') || ' ' || coalesce(summary, '') || ' ' || coalesce(description, ''))
  ) stored;

create index products_search_document_gin on public.products using gin (search_document);
create index products_public_catalogue_idx
  on public.products (name, created_at desc)
  where status = 'published' and rights_status = 'verified' and artifact_sha256 is not null;

-- A creator's statement is evidence to review, not automatic proof of ownership.
-- Only a trusted review path may promote a declaration to verified.
create table public.product_rights_attestations (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  attested_by uuid not null references auth.users(id) on delete restrict,
  rights_basis text not null check (rights_basis in ('original_work', 'authorized_distribution', 'open_source_compliance', 'licensed_assets', 'other')),
  statement text not null check (char_length(statement) between 20 and 4000),
  evidence_reference text check (evidence_reference is null or char_length(evidence_reference) <= 2048),
  review_status text not null default 'declared'
    check (review_status in ('declared', 'under_review', 'verified', 'rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_notes text check (review_notes is null or char_length(review_notes) <= 4000),
  created_at timestamptz not null default now(),
  constraint product_rights_review_consistency check (
    (review_status in ('verified', 'rejected') and reviewed_at is not null and reviewed_by is not null)
    or (review_status in ('declared', 'under_review') and reviewed_at is null)
  )
);
create index product_rights_attestations_product_idx
  on public.product_rights_attestations (product_id, created_at desc);

alter table public.products
  add constraint products_rights_verification_consistency check (
    rights_status <> 'verified'
    or (rights_verified_at is not null and rights_verified_by is not null and rights_verified_by <> creator_id)
  );

alter table public.product_rights_attestations
  add constraint product_rights_attestations_independent_review check (
    review_status not in ('verified', 'rejected') or reviewed_by <> attested_by
  );

-- Release records are immutable from ordinary creator sessions. A creator may submit a
-- draft release record, but only trusted release automation can promote it to released.
create table public.product_versions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  version text not null check (
    version ~ '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
  ),
  release_state text not null default 'draft' check (release_state in ('draft', 'in_review', 'released', 'withdrawn')),
  release_notes text not null default '' check (char_length(release_notes) <= 10000),
  artifact_sha256 text check (artifact_sha256 is null or artifact_sha256 ~ '^[a-f0-9]{64}$'),
  artifact_storage_path text check (artifact_storage_path is null or char_length(artifact_storage_path) <= 2048),
  manifest jsonb not null default '{}'::jsonb check (jsonb_typeof(manifest) = 'object'),
  compatibility jsonb not null default '{}'::jsonb check (jsonb_typeof(compatibility) = 'object'),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  released_at timestamptz,
  unique (product_id, version),
  constraint product_versions_release_evidence check (
    release_state <> 'released'
    or (artifact_sha256 is not null and artifact_storage_path is not null and released_at is not null)
  )
);
create index product_versions_product_idx on public.product_versions (product_id, created_at desc);

alter table public.product_rights_attestations enable row level security;
alter table public.product_versions enable row level security;

revoke all on public.product_rights_attestations, public.product_versions from anon, authenticated;
grant select, insert on public.product_rights_attestations to authenticated;
grant select, insert on public.product_versions to authenticated;
grant all on public.product_rights_attestations, public.product_versions to service_role;

-- Expose only a boolean release check to anonymous catalogue policy evaluation;
-- never grant public table access to artifact storage paths or release manifests.
create function public.product_has_verified_release(target_product_id uuid, target_artifact_sha256 text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.product_versions pv
    where pv.product_id = target_product_id
      and pv.release_state = 'released'
      and pv.artifact_sha256 = target_artifact_sha256
      and pv.artifact_storage_path is not null
      and pv.released_at is not null
  );
$function$;
revoke all on function public.product_has_verified_release(uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.product_has_verified_release(uuid, text) to anon, authenticated;

create policy rights_attestations_select_own on public.product_rights_attestations
  for select to authenticated
  using (exists (
    select 1 from public.products p
    where p.id = product_id and p.creator_id = (select auth.uid())
  ));
create policy rights_attestations_insert_own_draft on public.product_rights_attestations
  for insert to authenticated
  with check (
    attested_by = (select auth.uid())
    and review_status = 'declared'
    and reviewed_by is null
    and reviewed_at is null
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.creator_id = (select auth.uid()) and p.status = 'draft'
    )
  );

create policy product_versions_select_owner on public.product_versions
  for select to authenticated
  using (exists (
    select 1 from public.products p
    where p.id = product_id and p.creator_id = (select auth.uid())
  ));
create policy product_versions_insert_own_draft on public.product_versions
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and release_state = 'draft'
    and artifact_sha256 is null
    and released_at is null
    and exists (
      select 1 from public.products p
      where p.id = product_id and p.creator_id = (select auth.uid()) and p.status = 'draft'
    )
  );

-- Public catalogue access requires both publication and independently verified rights,
-- plus a content-addressed artifact. Creator-owned drafts remain private to their owner.
drop policy products_select_published_or_owner on public.products;
create policy products_select_published_or_owner on public.products
  for select to anon, authenticated
  using (
    (
      status = 'published'
      and rights_status = 'verified'
      and rights_verified_at is not null
      and rights_verified_by is not null
      and artifact_sha256 is not null
      and public.product_has_verified_release(id, artifact_sha256)
    )
    or creator_id = (select auth.uid())
  );
