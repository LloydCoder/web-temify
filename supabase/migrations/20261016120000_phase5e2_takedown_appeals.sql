-- Phase 5E2: explicit listing suppression and creator appeals.
-- Takedown actions are audited and atomic; an appeal does not automatically restore a listing.
alter table public.listing_moderation_case_events
  drop constraint listing_moderation_case_events_event_type_check;
alter table public.listing_moderation_case_events
  add constraint listing_moderation_case_events_event_type_check
  check (event_type in ('reported', 'triaged', 'action_required', 'dismissed', 'closed', 'appeal_received', 'takedown_applied', 'appeal_decided'));

create table public.listing_moderation_enforcements (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null unique references public.listing_moderation_cases(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  original_status text not null check (original_status = 'published'),
  reason_code text not null check (reason_code in ('listing_review_required', 'rights_review_required', 'security_review_required')),
  status text not null default 'active' check (status in ('active', 'reversed')),
  applied_by uuid not null references auth.users(id) on delete restrict,
  applied_at timestamptz not null default now(),
  request_id uuid not null,
  reversed_by uuid references auth.users(id) on delete restrict,
  reversed_at timestamptz,
  reversal_note text check (reversal_note is null or char_length(reversal_note) between 10 and 2000),
  publication_restored boolean not null default false,
  constraint listing_moderation_enforcement_reversal_consistency check (
    (status = 'active' and reversed_by is null and reversed_at is null and reversal_note is null and publication_restored = false)
    or (status = 'reversed' and reversed_by is not null and reversed_at is not null and reversal_note is not null)
  )
);
create index listing_moderation_active_enforcements_idx
  on public.listing_moderation_enforcements (product_id, applied_at desc)
  where status = 'active';

create table public.listing_moderation_appeal_policy (
  singleton boolean primary key default true check (singleton),
  response_target_hours integer not null default 336 check (response_target_hours between 24 and 720),
  policy_version text not null default 'unapproved-v1' check (char_length(policy_version) between 1 and 80),
  is_approved boolean not null default false,
  approved_by uuid references auth.users(id) on delete restrict,
  approved_at timestamptz,
  approval_note text check (approval_note is null or char_length(approval_note) between 10 and 2000),
  legal_review_reference text check (legal_review_reference is null or char_length(legal_review_reference) between 5 and 2048),
  updated_at timestamptz not null default now(),
  constraint listing_moderation_appeal_policy_approval_consistency check (
    (is_approved and approved_by is not null and approved_at is not null and approval_note is not null and legal_review_reference is not null)
    or (not is_approved and approved_by is null and approved_at is null and approval_note is null and legal_review_reference is null)
  )
);
insert into public.listing_moderation_appeal_policy (singleton) values (true)
on conflict (singleton) do nothing;

create table public.listing_moderation_appeals (
  id uuid primary key default gen_random_uuid(),
  enforcement_id uuid not null unique references public.listing_moderation_enforcements(id) on delete restrict,
  case_id uuid not null references public.listing_moderation_cases(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  creator_id uuid not null references auth.users(id) on delete restrict,
  statement text not null check (char_length(btrim(statement)) between 20 and 4000),
  evidence_reference text check (evidence_reference is null or char_length(evidence_reference) <= 2048),
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 200),
  status text not null default 'submitted' check (status in ('submitted', 'under_review', 'upheld', 'reversed', 'rejected')),
  response_due_at timestamptz,
  deadline_policy_version text,
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  decided_by uuid references auth.users(id) on delete restrict,
  decided_at timestamptz,
  decision_note text check (decision_note is null or char_length(decision_note) between 10 and 2000),
  request_id uuid not null,
  unique (creator_id, idempotency_key),
  constraint listing_moderation_appeal_decision_consistency check (
    (status in ('submitted', 'under_review') and decided_by is null and decided_at is null and decision_note is null)
    or (status in ('upheld', 'reversed', 'rejected') and decided_by is not null and decided_at is not null and decision_note is not null)
  ),
  constraint listing_moderation_appeal_deadline_consistency check (
    (response_due_at is null and deadline_policy_version is null)
    or (response_due_at is not null and deadline_policy_version is not null)
  )
);
create index listing_moderation_appeals_queue_idx
  on public.listing_moderation_appeals (status, submitted_at, id);
create index listing_moderation_appeals_creator_idx
  on public.listing_moderation_appeals (creator_id, submitted_at desc);

alter table public.listing_moderation_enforcements enable row level security;
alter table public.listing_moderation_appeal_policy enable row level security;
alter table public.listing_moderation_appeals enable row level security;
revoke all on public.listing_moderation_enforcements, public.listing_moderation_appeal_policy, public.listing_moderation_appeals from public, anon, authenticated, service_role;
grant select on public.listing_moderation_enforcements, public.listing_moderation_appeal_policy, public.listing_moderation_appeals to service_role;

create function public.reject_listing_moderation_appeal_mutation()
returns trigger language plpgsql set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'moderation appeal events are append-only';
end;
$function$;
revoke all on function public.reject_listing_moderation_appeal_mutation() from public, anon, authenticated, service_role;

create table public.listing_moderation_appeal_events (
  id bigint generated always as identity primary key,
  appeal_id uuid not null references public.listing_moderation_appeals(id) on delete restrict,
  actor_id uuid not null references auth.users(id) on delete restrict,
  event_type text not null check (event_type in ('submitted', 'triaged', 'upheld', 'reversed', 'rejected')),
  from_status text check (from_status is null or from_status in ('submitted', 'under_review', 'upheld', 'reversed', 'rejected')),
  to_status text not null check (to_status in ('submitted', 'under_review', 'upheld', 'reversed', 'rejected')),
  note text check (note is null or char_length(note) <= 2000),
  request_id uuid not null,
  created_at timestamptz not null default now()
);
alter table public.listing_moderation_appeal_events enable row level security;
revoke all on public.listing_moderation_appeal_events from public, anon, authenticated, service_role;
grant select on public.listing_moderation_appeal_events to service_role;
create index listing_moderation_appeal_events_appeal_idx
  on public.listing_moderation_appeal_events (appeal_id, created_at, id);
create trigger listing_moderation_appeal_events_immutable
before update or delete on public.listing_moderation_appeal_events
for each row execute function public.reject_listing_moderation_appeal_mutation();

create function public.admin_apply_listing_takedown(
  p_case_id uuid,
  p_actor_id uuid,
  p_note text,
  p_request_id uuid
)
returns public.listing_moderation_enforcements
language plpgsql security definer set search_path = ''
as $function$
declare
  target_case public.listing_moderation_cases%rowtype;
  target_product public.products%rowtype;
  enforcement public.listing_moderation_enforcements%rowtype;
begin
  if p_case_id is null or p_actor_id is null or p_request_id is null
    or p_note is null or char_length(btrim(p_note)) not between 10 and 2000
  then
    raise exception using errcode = '22023', message = 'takedown request failed validation';
  end if;
  if not exists (select 1 from public.user_roles ur where ur.user_id = p_actor_id and ur.role = 'admin'::public.app_role) then
    raise exception using errcode = '42501', message = 'administrator role required';
  end if;

  select * into target_case from public.listing_moderation_cases where id = p_case_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'moderation case not found'; end if;
  if target_case.status <> 'action_required'
    or target_case.resolution_code not in ('listing_review_required', 'rights_review_required', 'security_review_required')
  then
    raise exception using errcode = '22023', message = 'case does not have an approved takedown disposition';
  end if;

  select * into target_product from public.products where id = target_case.product_id for update;
  if not found or target_product.status <> 'published' then
    raise exception using errcode = '22023', message = 'listing is not currently published';
  end if;
  if exists (select 1 from public.listing_moderation_enforcements e where e.case_id = p_case_id) then
    raise exception using errcode = '23505', message = 'takedown already recorded for this case';
  end if;

  insert into public.listing_moderation_enforcements
    (case_id, product_id, original_status, reason_code, applied_by, request_id)
  values
    (target_case.id, target_product.id, target_product.status, target_case.resolution_code, p_actor_id, p_request_id)
  returning * into enforcement;

  update public.products set status = 'archived', updated_at = now() where id = target_product.id;
  update public.listing_moderation_cases
    set status = 'closed', decided_by = p_actor_id, decided_at = now(), updated_at = now()
    where id = target_case.id;

  insert into public.listing_moderation_case_events
    (case_id, actor_id, event_type, from_status, to_status, reason_code, note, request_id)
  values (target_case.id, p_actor_id, 'takedown_applied', 'action_required', 'closed', target_case.resolution_code, btrim(p_note), p_request_id);

  insert into public.audit_events (actor_id, action, entity_type, entity_id, request_id, metadata)
  values
    (p_actor_id, 'listing.takedown.applied', 'product', target_product.id::text, p_request_id,
      jsonb_build_object('caseId', target_case.id, 'enforcementId', enforcement.id, 'previousStatus', target_product.status, 'newStatus', 'archived', 'reasonCode', target_case.resolution_code)),
    (p_actor_id, 'listing.moderation.closed_by_takedown', 'listing_moderation_case', target_case.id::text, p_request_id,
      jsonb_build_object('enforcementId', enforcement.id, 'productId', target_product.id));
  return enforcement;
end;
$function$;
revoke all on function public.admin_apply_listing_takedown(uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.admin_apply_listing_takedown(uuid, uuid, text, uuid) to service_role;

create function public.create_listing_moderation_appeal(
  p_creator_id uuid,
  p_enforcement_id uuid,
  p_statement text,
  p_evidence_reference text,
  p_idempotency_key text,
  p_request_id uuid
)
returns public.listing_moderation_appeals
language plpgsql security definer set search_path = ''
as $function$
declare
  enforcement public.listing_moderation_enforcements%rowtype;
  existing_appeal public.listing_moderation_appeals%rowtype;
  policy public.listing_moderation_appeal_policy%rowtype;
  new_appeal public.listing_moderation_appeals%rowtype;
begin
  if p_creator_id is null or p_enforcement_id is null or p_request_id is null
    or p_statement is null or char_length(btrim(p_statement)) not between 20 and 4000
    or p_idempotency_key is null or char_length(p_idempotency_key) not between 16 and 200
    or (p_evidence_reference is not null and char_length(p_evidence_reference) > 2048)
  then
    raise exception using errcode = '22023', message = 'appeal request failed validation';
  end if;
  if not exists (select 1 from auth.users u where u.id = p_creator_id) then
    raise exception using errcode = '42501', message = 'appeal creator does not exist';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_creator_id::text || ':' || p_idempotency_key, 0));
  select * into existing_appeal from public.listing_moderation_appeals
    where creator_id = p_creator_id and idempotency_key = p_idempotency_key for update;
  if found then
    if existing_appeal.enforcement_id is distinct from p_enforcement_id
      or existing_appeal.statement is distinct from btrim(p_statement)
      or existing_appeal.evidence_reference is distinct from p_evidence_reference
    then
      raise exception using errcode = '23505', message = 'appeal idempotency key reused with conflicting content';
    end if;
    return existing_appeal;
  end if;

  select * into enforcement from public.listing_moderation_enforcements where id = p_enforcement_id for update;
  if not found or enforcement.status <> 'active' then
    raise exception using errcode = 'P0002', message = 'active takedown not found';
  end if;
  if not exists (
    select 1 from public.products p where p.id = enforcement.product_id and p.creator_id = p_creator_id and p.status = 'archived'
  ) then
    raise exception using errcode = '42501', message = 'only the product creator can appeal this active takedown';
  end if;

  select * into policy from public.listing_moderation_appeal_policy where singleton = true;
  insert into public.listing_moderation_appeals
    (enforcement_id, case_id, product_id, creator_id, statement, evidence_reference, idempotency_key,
     response_due_at, deadline_policy_version, request_id)
  values
    (enforcement.id, enforcement.case_id, enforcement.product_id, p_creator_id, btrim(p_statement), p_evidence_reference,
     p_idempotency_key,
     case when coalesce(policy.is_approved, false) then now() + make_interval(hours => policy.response_target_hours) else null end,
     case when coalesce(policy.is_approved, false) then policy.policy_version else null end,
     p_request_id)
  returning * into new_appeal;

  insert into public.listing_moderation_appeal_events
    (appeal_id, actor_id, event_type, from_status, to_status, note, request_id)
  values (new_appeal.id, p_creator_id, 'submitted', null, 'submitted', 'Creator appeal submitted', p_request_id);

  insert into public.listing_moderation_case_events
    (case_id, actor_id, event_type, from_status, to_status, reason_code, note, request_id)
  values (enforcement.case_id, p_creator_id, 'appeal_received', 'closed', 'closed', 'creator_appeal', 'Creator appeal received', p_request_id);

  insert into public.audit_events (actor_id, action, entity_type, entity_id, request_id, metadata)
  values (p_creator_id, 'listing.moderation.appeal_submitted', 'listing_moderation_appeal', new_appeal.id::text, p_request_id,
    jsonb_build_object('caseId', enforcement.case_id, 'enforcementId', enforcement.id, 'productId', enforcement.product_id,
      'deadlineConfigured', new_appeal.response_due_at is not null));
  return new_appeal;
end;
$function$;
revoke all on function public.create_listing_moderation_appeal(uuid, uuid, text, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.create_listing_moderation_appeal(uuid, uuid, text, text, text, uuid) to service_role;

create function public.admin_transition_listing_moderation_appeal(
  p_appeal_id uuid,
  p_actor_id uuid,
  p_action text,
  p_note text,
  p_request_id uuid
)
returns public.listing_moderation_appeals
language plpgsql security definer set search_path = ''
as $function$
declare
  appeal public.listing_moderation_appeals%rowtype;
  enforcement public.listing_moderation_enforcements%rowtype;
  product_row public.products%rowtype;
  next_status text;
  restored boolean := false;
begin
  if p_appeal_id is null or p_actor_id is null or p_request_id is null
    or p_action is null or p_action not in ('triage', 'uphold', 'reverse', 'reject')
    or p_note is null or char_length(btrim(p_note)) not between 10 and 2000
  then
    raise exception using errcode = '22023', message = 'appeal transition failed validation';
  end if;
  if not exists (select 1 from public.user_roles ur where ur.user_id = p_actor_id and ur.role = 'admin'::public.app_role) then
    raise exception using errcode = '42501', message = 'administrator role required';
  end if;

  select * into appeal from public.listing_moderation_appeals where id = p_appeal_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'appeal not found'; end if;
  select * into enforcement from public.listing_moderation_enforcements where id = appeal.enforcement_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'enforcement not found'; end if;

  if p_action = 'triage' and appeal.status = 'submitted' then
    next_status := 'under_review';
  elsif p_action = 'uphold' and appeal.status = 'under_review' then
    next_status := 'upheld';
  elsif p_action = 'reverse' and appeal.status = 'under_review' then
    next_status := 'reversed';
  elsif p_action = 'reject' and appeal.status = 'under_review' then
    next_status := 'rejected';
  else
    raise exception using errcode = '22023', message = 'invalid appeal transition';
  end if;

  if next_status = 'reversed' then
    if enforcement.status <> 'active' then
      raise exception using errcode = '22023', message = 'takedown is no longer active';
    end if;
    select * into product_row from public.products where id = enforcement.product_id for update;
    update public.listing_moderation_enforcements
      set status = 'reversed', reversed_by = p_actor_id, reversed_at = now(),
          reversal_note = btrim(p_note)
      where id = enforcement.id;
    if product_row.status = 'archived'
      and product_row.rights_status = 'verified'
      and product_row.rights_verified_at is not null
      and product_row.rights_verified_by is not null
      and product_row.artifact_sha256 is not null
      and public.product_has_verified_rights(product_row.id, product_row.rights_verified_by, product_row.rights_verified_at)
      and public.product_has_verified_release(product_row.id, product_row.artifact_sha256)
    then
      update public.products set status = 'published', updated_at = now() where id = product_row.id;
      restored := true;
    end if;
    update public.listing_moderation_enforcements set publication_restored = restored where id = enforcement.id;
  end if;

  update public.listing_moderation_appeals
    set status = next_status, updated_at = now(),
        decided_by = case when next_status in ('upheld', 'reversed', 'rejected') then p_actor_id else null end,
        decided_at = case when next_status in ('upheld', 'reversed', 'rejected') then now() else null end,
        decision_note = case when next_status in ('upheld', 'reversed', 'rejected') then btrim(p_note) else null end
    where id = p_appeal_id returning * into appeal;

  insert into public.listing_moderation_appeal_events
    (appeal_id, actor_id, event_type, from_status, to_status, note, request_id)
  values (appeal.id, p_actor_id, case when next_status = 'under_review' then 'triaged' else next_status end, case when next_status = 'under_review' then 'submitted' else 'under_review' end, next_status, btrim(p_note), p_request_id);

  insert into public.listing_moderation_case_events
    (case_id, actor_id, event_type, from_status, to_status, reason_code, note, request_id)
  values (appeal.case_id, p_actor_id, 'appeal_decided', 'closed', 'closed', 'creator_appeal_' || next_status, btrim(p_note), p_request_id);

  insert into public.audit_events (actor_id, action, entity_type, entity_id, request_id, metadata)
  values (p_actor_id, 'listing.moderation.appeal_' || next_status, 'listing_moderation_appeal', appeal.id::text, p_request_id,
    jsonb_build_object('caseId', appeal.case_id, 'enforcementId', enforcement.id, 'productId', appeal.product_id,
      'publicationRestored', restored, 'responseDueAt', appeal.response_due_at));
  return appeal;
end;
$function$;
revoke all on function public.admin_transition_listing_moderation_appeal(uuid, uuid, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.admin_transition_listing_moderation_appeal(uuid, uuid, text, text, uuid) to service_role;

create function public.admin_configure_listing_moderation_appeal_policy(
  p_actor_id uuid,
  p_response_target_hours integer,
  p_policy_version text,
  p_approval_note text,
  p_legal_review_reference text,
  p_request_id uuid
)
returns public.listing_moderation_appeal_policy
language plpgsql security definer set search_path = ''
as $function$
declare
  configured public.listing_moderation_appeal_policy%rowtype;
begin
  if p_actor_id is null or p_request_id is null
    or p_response_target_hours is null or p_response_target_hours not between 24 and 720
    or p_policy_version is null or char_length(btrim(p_policy_version)) not between 1 and 80
    or p_approval_note is null or char_length(btrim(p_approval_note)) not between 10 and 2000
    or p_legal_review_reference is null or char_length(btrim(p_legal_review_reference)) not between 5 and 2048
  then
    raise exception using errcode = '22023', message = 'appeal policy failed validation';
  end if;
  if not exists (select 1 from public.user_roles ur where ur.user_id = p_actor_id and ur.role = 'admin'::public.app_role) then
    raise exception using errcode = '42501', message = 'administrator role required';
  end if;

  insert into public.listing_moderation_appeal_policy
    (singleton, response_target_hours, policy_version, is_approved, approved_by, approved_at, approval_note, legal_review_reference, updated_at)
  values (true, p_response_target_hours, btrim(p_policy_version), true, p_actor_id, now(), btrim(p_approval_note), btrim(p_legal_review_reference), now())
  on conflict (singleton) do update set
    response_target_hours = excluded.response_target_hours,
    policy_version = excluded.policy_version,
    is_approved = true,
    approved_by = excluded.approved_by,
    approved_at = excluded.approved_at,
    approval_note = excluded.approval_note,
    legal_review_reference = excluded.legal_review_reference,
    updated_at = now()
  returning * into configured;

  insert into public.audit_events (actor_id, action, entity_type, entity_id, request_id, metadata)
  values (p_actor_id, 'listing.moderation.appeal_policy_configured', 'listing_moderation_appeal_policy', 'singleton', p_request_id,
    jsonb_build_object('responseTargetHours', p_response_target_hours, 'policyVersion', p_policy_version,
      'legalReviewReference', btrim(p_legal_review_reference)));
  return configured;
end;
$function$;
revoke all on function public.admin_configure_listing_moderation_appeal_policy(uuid, integer, text, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.admin_configure_listing_moderation_appeal_policy(uuid, integer, text, text, text, uuid) to service_role;


-- Phase 5E2: an already-issued grant must not bypass a listing takedown.
-- Preserve Phase 4B's order -> entitlement -> grant lock order so refunds still
-- serialize correctly, then share-lock the product to serialize consumption
-- against a concurrent moderation takedown.
create or replace function public.consume_download_grant(target_grant_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_customer_id uuid := (select auth.uid());
  grant_hint public.download_grants%rowtype;
  grant_row public.download_grants%rowtype;
  entitlement_row public.entitlements%rowtype;
  v_order_id uuid;
  order_row public.orders%rowtype;
  release_row public.product_versions%rowtype;
  product_row public.products%rowtype;
begin
  if v_customer_id is null then return false; end if;

  select * into grant_hint
  from public.download_grants
  where id = target_grant_id and customer_id = v_customer_id;
  if not found then return false; end if;

  select oi.order_id into v_order_id
  from public.entitlements e
  join public.order_items oi on oi.id = e.order_item_id
  where e.id = grant_hint.entitlement_id and e.customer_id = v_customer_id;
  if not found then return false; end if;

  select * into order_row from public.orders where id = v_order_id for update;
  if not found or order_row.customer_id <> v_customer_id
    or order_row.status not in ('paid', 'partially_refunded') then
    return false;
  end if;

  select * into entitlement_row
  from public.entitlements
  where id = grant_hint.entitlement_id
  for update;
  if not found or entitlement_row.customer_id <> v_customer_id
    or entitlement_row.status <> 'active'
    or (entitlement_row.expires_at is not null and entitlement_row.expires_at <= now()) then
    return false;
  end if;

  select * into grant_row
  from public.download_grants
  where id = target_grant_id
  for update;
  if not found or grant_row.customer_id <> v_customer_id
    or grant_row.revoked_at is not null or grant_row.expires_at <= now()
    or grant_row.downloads_used >= grant_row.max_downloads
    or grant_row.entitlement_id <> entitlement_row.id
    or grant_row.product_version_id <> entitlement_row.product_version_id then
    return false;
  end if;

  select * into release_row
  from public.product_versions
  where id = grant_row.product_version_id;
  if not found or release_row.release_state <> 'released'
    or release_row.artifact_sha256 <> grant_row.artifact_sha256
    or release_row.artifact_storage_path is null
    or release_row.released_at is null then
    return false;
  end if;

  select * into product_row
  from public.products
  where id = release_row.product_id
  for share;
  if not found or product_row.status <> 'published'
    or product_row.id <> entitlement_row.product_id then
    return false;
  end if;

  update public.download_grants
  set downloads_used = downloads_used + 1
  where id = grant_row.id;
  return true;
end;
$function$;
revoke all on function public.consume_download_grant(uuid) from public, anon, service_role;
grant execute on function public.consume_download_grant(uuid) to authenticated;
