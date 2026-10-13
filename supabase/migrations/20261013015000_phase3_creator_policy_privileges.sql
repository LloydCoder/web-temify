-- Repair Phase 3 creator policies: RLS predicates must not require clients to have
-- table-wide SELECT grants on the private products table. These SECURITY DEFINER
-- helpers expose only boolean ownership checks and execute with a fixed search_path.
create function public.current_user_owns_product(target_product_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.products p
    where p.id = target_product_id
      and p.creator_id = (select auth.uid())
  );
$function$;
revoke all on function public.current_user_owns_product(uuid) from public, anon, service_role;
grant execute on function public.current_user_owns_product(uuid) to authenticated;

create function public.current_user_owns_draft_product(target_product_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.products p
    where p.id = target_product_id
      and p.creator_id = (select auth.uid())
      and p.status = 'draft'
      and p.rights_status = 'unverified'
      and p.rights_verified_at is null
      and p.rights_verified_by is null
      and p.artifact_sha256 is null
  );
$function$;
revoke all on function public.current_user_owns_draft_product(uuid) from public, anon, service_role;
grant execute on function public.current_user_owns_draft_product(uuid) to authenticated;

drop policy rights_attestations_select_own on public.product_rights_attestations;
create policy rights_attestations_select_own on public.product_rights_attestations
  for select to authenticated
  using (public.current_user_owns_product(product_id));

drop policy rights_attestations_insert_own_draft on public.product_rights_attestations;
create policy rights_attestations_insert_own_draft on public.product_rights_attestations
  for insert to authenticated
  with check (
    attested_by = (select auth.uid())
    and review_status = 'declared'
    and reviewed_by is null
    and reviewed_at is null
    and review_notes is null
    and public.current_user_owns_draft_product(product_id)
  );

drop policy product_versions_select_owner on public.product_versions;
create policy product_versions_select_owner on public.product_versions
  for select to authenticated
  using (public.current_user_owns_product(product_id));

drop policy product_versions_insert_own_draft on public.product_versions;
create policy product_versions_insert_own_draft on public.product_versions
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and release_state = 'draft'
    and artifact_sha256 is null
    and released_at is null
    and public.current_user_owns_draft_product(product_id)
  );
