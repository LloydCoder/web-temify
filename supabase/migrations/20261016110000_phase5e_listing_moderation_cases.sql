-- Phase 5E1: audited listing-moderation case intake and admin decision workflow.
-- This slice records decisions; public listing suppression is a separate enforced gate and is not implied here.
create table public.listing_moderation_cases (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete restrict,
  reporter_id uuid not null references auth.users(id) on delete restrict,
  reason_code text not null check (reason_code in ('ip_rights', 'fraud_misrepresentation', 'malware_security', 'prohibited_content', 'privacy', 'other')),
  description text not null check (char_length(btrim(description)) between 20 and 4000),
  status text not null default 'open' check (status in ('open', 'under_review', 'action_required', 'dismissed', 'closed')),
  resolution_code text check (resolution_code is null or resolution_code in ('listing_review_required', 'rights_review_required', 'security_review_required', 'no_violation_found', 'duplicate_report', 'insufficient_evidence')),
  resolution_note text check (resolution_note is null or char_length(resolution_note) <= 2000),
  decided_by uuid references auth.users(id) on delete restrict,
  decided_at timestamptz,
  idempotency_key text not null check (char_length(idempotency_key) between 16 and 200),
  request_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint listing_moderation_report_idempotency unique (reporter_id, idempotency_key),
  constraint listing_moderation_decision_consistency check (
    (status in ('action_required', 'dismissed', 'closed') and decided_by is not null and decided_at is not null and resolution_code is not null)
    or (status in ('open', 'under_review') and decided_by is null and decided_at is null and resolution_code is null)
  )
);

create table public.listing_moderation_case_events (
  id bigint generated always as identity primary key,
  case_id uuid not null references public.listing_moderation_cases(id) on delete restrict,
  actor_id uuid not null references auth.users(id) on delete restrict,
  event_type text not null check (event_type in ('reported', 'triaged', 'action_required', 'dismissed', 'closed', 'appeal_received')),
  from_status text check (from_status is null or from_status in ('open', 'under_review', 'action_required', 'dismissed', 'closed')),
  to_status text not null check (to_status in ('open', 'under_review', 'action_required', 'dismissed', 'closed')),
  reason_code text not null,
  note text check (note is null or char_length(note) <= 2000),
  request_id uuid not null,
  created_at timestamptz not null default now()
);

create index listing_moderation_queue_idx on public.listing_moderation_cases (status, created_at, id);
create index listing_moderation_product_idx on public.listing_moderation_cases (product_id, created_at desc);
create index listing_moderation_events_case_idx on public.listing_moderation_case_events (case_id, created_at, id);

alter table public.listing_moderation_cases enable row level security;
alter table public.listing_moderation_case_events enable row level security;
revoke all on public.listing_moderation_cases from public, anon, authenticated, service_role;
revoke all on public.listing_moderation_case_events from public, anon, authenticated, service_role;
grant select on public.listing_moderation_cases to service_role;
grant select on public.listing_moderation_case_events to service_role;

create function public.reject_listing_moderation_event_mutation()
returns trigger language plpgsql set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'moderation case events are append-only';
end;
$function$;
revoke all on function public.reject_listing_moderation_event_mutation() from public, anon, authenticated, service_role;
create trigger listing_moderation_events_immutable
before update or delete on public.listing_moderation_case_events
for each row execute function public.reject_listing_moderation_event_mutation();

create function public.create_listing_moderation_case(
  p_reporter_id uuid,
  p_product_id uuid,
  p_reason_code text,
  p_description text,
  p_idempotency_key text,
  p_request_id uuid
)
returns uuid language plpgsql security definer set search_path = ''
as $function$
declare
  existing_case public.listing_moderation_cases%rowtype;
  new_case_id uuid;
begin
  if p_reporter_id is null or p_product_id is null or p_request_id is null
    or p_reason_code is null or p_reason_code not in ('ip_rights', 'fraud_misrepresentation', 'malware_security', 'prohibited_content', 'privacy', 'other')
    or p_description is null or char_length(btrim(p_description)) not between 20 and 4000
    or p_idempotency_key is null or char_length(p_idempotency_key) not between 16 and 200
  then
    raise exception using errcode = '22023', message = 'moderation report failed validation';
  end if;
  if not exists (select 1 from auth.users u where u.id = p_reporter_id) then
    raise exception using errcode = '42501', message = 'moderation reporter does not exist';
  end if;
  if not exists (select 1 from public.products p where p.id = p_product_id) then
    raise exception using errcode = 'P0002', message = 'moderation product not found';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_reporter_id::text || ':' || p_idempotency_key, 0));
  select * into existing_case from public.listing_moderation_cases
    where reporter_id = p_reporter_id and idempotency_key = p_idempotency_key for update;
  if found then
    if existing_case.product_id is distinct from p_product_id
      or existing_case.reason_code is distinct from p_reason_code
      or existing_case.description is distinct from btrim(p_description)
    then
      raise exception using errcode = '23505', message = 'moderation idempotency key reused with conflicting content';
    end if;
    return existing_case.id;
  end if;

  insert into public.listing_moderation_cases
    (product_id, reporter_id, reason_code, description, idempotency_key, request_id)
  values (p_product_id, p_reporter_id, p_reason_code, btrim(p_description), p_idempotency_key, p_request_id)
  returning id into new_case_id;

  insert into public.listing_moderation_case_events
    (case_id, actor_id, event_type, from_status, to_status, reason_code, note, request_id)
  values (new_case_id, p_reporter_id, 'reported', null, 'open', p_reason_code, 'Report received', p_request_id);

  insert into public.audit_events (actor_id, action, entity_type, entity_id, request_id, metadata)
  values (p_reporter_id, 'listing.moderation.reported', 'listing_moderation_case', new_case_id::text, p_request_id,
    jsonb_build_object('productId', p_product_id, 'reasonCode', p_reason_code));
  return new_case_id;
end;
$function$;
revoke all on function public.create_listing_moderation_case(uuid, uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.create_listing_moderation_case(uuid, uuid, text, text, text, uuid) to service_role;

create function public.admin_transition_listing_moderation_case(
  p_case_id uuid,
  p_actor_id uuid,
  p_action text,
  p_resolution_code text,
  p_note text,
  p_request_id uuid
)
returns public.listing_moderation_cases language plpgsql security definer set search_path = ''
as $function$
declare
  target public.listing_moderation_cases%rowtype;
  next_status text;
begin
  if p_case_id is null or p_actor_id is null or p_request_id is null
    or p_action is null or p_action not in ('triage', 'require_action', 'dismiss', 'close')
    or p_note is null or char_length(btrim(p_note)) not between 10 and 2000
  then
    raise exception using errcode = '22023', message = 'moderation transition failed validation';
  end if;
  if not exists (select 1 from public.user_roles ur where ur.user_id = p_actor_id and ur.role = 'admin'::public.app_role) then
    raise exception using errcode = '42501', message = 'administrator role required';
  end if;

  select * into target from public.listing_moderation_cases where id = p_case_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'moderation case not found'; end if;

  if p_action = 'triage' and target.status = 'open' then
    next_status := 'under_review';
  elsif p_action = 'require_action' and target.status = 'under_review'
    and p_resolution_code in ('listing_review_required', 'rights_review_required', 'security_review_required') then
    next_status := 'action_required';
  elsif p_action = 'dismiss' and target.status in ('open', 'under_review')
    and p_resolution_code in ('no_violation_found', 'duplicate_report', 'insufficient_evidence') then
    next_status := 'dismissed';
  elsif p_action = 'close' and target.status in ('action_required', 'dismissed')
    and p_resolution_code = target.resolution_code then
    next_status := 'closed';
  else
    raise exception using errcode = '22023', message = 'invalid moderation case transition';
  end if;

  update public.listing_moderation_cases
    set status = next_status,
        resolution_code = case when next_status in ('action_required', 'dismissed', 'closed') then coalesce(p_resolution_code, target.resolution_code) else null end,
        resolution_note = case when next_status in ('action_required', 'dismissed', 'closed') then btrim(p_note) else null end,
        decided_by = case when next_status in ('action_required', 'dismissed', 'closed') then p_actor_id else null end,
        decided_at = case when next_status in ('action_required', 'dismissed', 'closed') then now() else null end,
        updated_at = now()
    where id = p_case_id returning * into target;

  insert into public.listing_moderation_case_events
    (case_id, actor_id, event_type, from_status, to_status, reason_code, note, request_id)
  values (target.id, p_actor_id,
    case next_status when 'under_review' then 'triaged' when 'action_required' then 'action_required' when 'dismissed' then 'dismissed' else 'closed' end,
    case p_action when 'triage' then 'open' else target.status end,
    next_status, coalesce(p_resolution_code, target.reason_code), btrim(p_note), p_request_id);

  insert into public.audit_events (actor_id, action, entity_type, entity_id, request_id, metadata)
  values (p_actor_id, 'listing.moderation.' || p_action, 'listing_moderation_case', target.id::text, p_request_id,
    jsonb_build_object('fromStatus', target.status, 'toStatus', next_status, 'resolutionCode', p_resolution_code));
  return target;
end;
$function$;
revoke all on function public.admin_transition_listing_moderation_case(uuid, uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function public.admin_transition_listing_moderation_case(uuid, uuid, text, text, text, uuid) to service_role;
