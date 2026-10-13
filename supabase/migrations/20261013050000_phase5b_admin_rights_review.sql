-- Phase 5B: narrow, audited, transactional product-rights review.
-- The function is invoker-security and callable only by the trusted server role.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;

create or replace function private.admin_review_product_rights(
  p_product_id uuid,
  p_attestation_id uuid,
  p_reviewer_id uuid,
  p_decision text,
  p_review_notes text,
  p_request_id uuid
)
returns jsonb
language plpgsql
set search_path = pg_catalog, public, private
as $function$
declare
  v_attested_by uuid;
  v_current_status text;
  v_reviewed_at timestamptz;
begin
  if p_reviewer_id is null or p_product_id is null or p_attestation_id is null or p_request_id is null then
    raise exception using errcode = '22023', message = 'Required review identifiers are missing.';
  end if;
  if p_decision is null or p_decision not in ('under_review', 'verified', 'rejected') then
    raise exception using errcode = '22023', message = 'Unsupported product-rights review decision.';
  end if;
  if p_review_notes is null or char_length(btrim(p_review_notes)) < 10 or char_length(p_review_notes) > 4000 then
    raise exception using errcode = '22023', message = 'Reviewer notes must contain 10 to 4000 characters.';
  end if;

  select a.attested_by, a.review_status
    into v_attested_by, v_current_status
  from public.products p
  join public.product_rights_attestations a on a.product_id = p.id
  where p.id = p_product_id
    and a.id = p_attestation_id
  for update of p, a;

  if not found then
    raise exception using errcode = 'P0002', message = 'Rights attestation is not reviewable.';
  end if;
  if v_attested_by = p_reviewer_id then
    raise exception using errcode = '42501', message = 'Reviewers cannot review their own rights evidence.';
  end if;
  if v_current_status not in ('declared', 'under_review') then
    raise exception using errcode = 'P0002', message = 'Rights attestation is already resolved.';
  end if;

  v_reviewed_at := case when p_decision in ('verified', 'rejected') then clock_timestamp() else null end;

  update public.product_rights_attestations
  set review_status = p_decision,
      reviewed_by = case when p_decision in ('verified', 'rejected') then p_reviewer_id else null end,
      reviewed_at = v_reviewed_at,
      review_notes = btrim(p_review_notes)
  where id = p_attestation_id and product_id = p_product_id;

  update public.products
  set rights_status = p_decision,
      rights_verified_at = case when p_decision = 'verified' then v_reviewed_at else null end,
      rights_verified_by = case when p_decision = 'verified' then p_reviewer_id else null end
  where id = p_product_id;

  insert into public.audit_events (
    actor_id, action, entity_type, entity_id, request_id, metadata
  ) values (
    p_reviewer_id,
    'admin.product_rights.reviewed',
    'product',
    p_product_id::text,
    p_request_id::text,
    jsonb_build_object(
      'attestation_id', p_attestation_id,
      'decision', p_decision,
      'previous_status', v_current_status
    )
  );

  return jsonb_build_object(
    'productId', p_product_id,
    'attestationId', p_attestation_id,
    'decision', p_decision,
    'reviewedAt', v_reviewed_at
  );
end;
$function$;

revoke all on function private.admin_review_product_rights(uuid, uuid, uuid, text, text, uuid) from public, anon, authenticated;
grant execute on function private.admin_review_product_rights(uuid, uuid, uuid, text, text, uuid) to service_role;
