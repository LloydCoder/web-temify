-- Phase 5G: maker-checker financial control requests and internal payout holds.
-- This migration does not post journal entries or call a payment provider.
create table public.financial_control_requests (
  id uuid primary key default gen_random_uuid(),
  request_type text not null check (request_type in (
    'manual_adjustment', 'negative_balance_review', 'payout_hold', 'payout_hold_release'
  )),
  status text not null default 'requested' check (status in (
    'requested', 'under_review', 'approved', 'rejected', 'cancelled'
  )),
  seller_id uuid not null references auth.users(id) on delete restrict,
  order_id uuid references public.orders(id) on delete restrict,
  target_hold_id uuid,
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  evidence_sha256 text not null check (evidence_sha256 ~ '^[a-f0-9]{64}$'),
  reason text not null check (char_length(btrim(reason)) between 12 and 1000),
  idempotency_key text not null unique check (char_length(idempotency_key) between 16 and 200),
  requested_by uuid not null references auth.users(id) on delete restrict,
  request_id uuid not null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint financial_control_request_approval_state check (
    (status = 'approved' and approved_at is not null)
    or (status <> 'approved' and approved_at is null)
  ),
  constraint financial_control_request_target_hold check (
    (request_type = 'payout_hold_release' and target_hold_id is not null)
    or (request_type <> 'payout_hold_release' and target_hold_id is null)
  )
);

create table public.financial_control_approvals (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.financial_control_requests(id) on delete restrict,
  approver_id uuid not null references auth.users(id) on delete restrict,
  decision text not null check (decision in ('approve', 'reject')),
  note text not null check (char_length(btrim(note)) between 10 and 1000),
  request_trace_id uuid not null,
  created_at timestamptz not null default now(),
  unique (request_id, approver_id)
);

create table public.financial_control_events (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.financial_control_requests(id) on delete restrict,
  actor_id uuid not null references auth.users(id) on delete restrict,
  event_type text not null check (event_type in (
    'created', 'approved_by_one', 'approved', 'rejected', 'cancelled', 'payout_hold_placed', 'payout_hold_released'
  )),
  from_status text,
  to_status text not null,
  note text not null check (char_length(btrim(note)) between 10 and 1000),
  request_trace_id uuid not null,
  created_at timestamptz not null default now()
);

create table public.seller_payout_holds (
  id uuid primary key default gen_random_uuid(),
  source_request_id uuid not null unique references public.financial_control_requests(id) on delete restrict,
  seller_id uuid not null references auth.users(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  evidence_sha256 text not null check (evidence_sha256 ~ '^[a-f0-9]{64}$'),
  reason text not null check (char_length(btrim(reason)) between 12 and 1000),
  created_at timestamptz not null default now(),
  released_at timestamptz,
  release_request_id uuid unique references public.financial_control_requests(id) on delete restrict,
  constraint seller_payout_hold_release_state check (
    (released_at is null and release_request_id is null)
    or (released_at is not null and release_request_id is not null)
  )
);

alter table public.financial_control_requests
  add constraint financial_control_target_hold_fk
  foreign key (target_hold_id) references public.seller_payout_holds(id) on delete restrict;

create index financial_control_request_seller_idx
  on public.financial_control_requests (seller_id, status, created_at desc);
create index financial_control_request_type_idx
  on public.financial_control_requests (request_type, status, created_at desc);
create index financial_control_approvals_request_idx
  on public.financial_control_approvals (request_id, decision, created_at);
create index seller_payout_holds_active_idx
  on public.seller_payout_holds (seller_id, currency, created_at)
  where released_at is null;

alter table public.financial_control_requests enable row level security;
alter table public.financial_control_approvals enable row level security;
alter table public.financial_control_events enable row level security;
alter table public.seller_payout_holds enable row level security;
revoke all on public.financial_control_requests from public, anon, authenticated, service_role;
revoke all on public.financial_control_approvals from public, anon, authenticated, service_role;
revoke all on public.financial_control_events from public, anon, authenticated, service_role;
revoke all on public.seller_payout_holds from public, anon, authenticated, service_role;
grant select on public.financial_control_requests to service_role;
grant select on public.financial_control_approvals to service_role;
grant select on public.financial_control_events to service_role;
grant select on public.seller_payout_holds to service_role;

create function public.guard_financial_control_approval()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  control_request public.financial_control_requests%rowtype;
begin
  select * into control_request
  from public.financial_control_requests
  where id = new.request_id
  for update;
  if not found or control_request.status not in ('requested', 'under_review')
    or control_request.requested_by = new.approver_id
    or not exists (
      select 1 from public.user_roles ur
      where ur.user_id = new.approver_id and ur.role = 'admin'::public.app_role
    )
  then
    raise exception using errcode = '42501', message = 'financial control approval requires a distinct admin reviewer';
  end if;
  return new;
end;
$function$;
revoke all on function public.guard_financial_control_approval() from public, anon, authenticated, service_role;
create trigger financial_control_approval_guard
before insert on public.financial_control_approvals
for each row execute function public.guard_financial_control_approval();

create function public.guard_financial_control_request()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '55000', message = 'financial control requests are immutable records';
  end if;
  if new.id is distinct from old.id
    or new.request_type is distinct from old.request_type
    or new.seller_id is distinct from old.seller_id
    or new.order_id is distinct from old.order_id
    or new.target_hold_id is distinct from old.target_hold_id
    or new.amount_minor is distinct from old.amount_minor
    or new.currency is distinct from old.currency
    or new.evidence_sha256 is distinct from old.evidence_sha256
    or new.reason is distinct from old.reason
    or new.idempotency_key is distinct from old.idempotency_key
    or new.requested_by is distinct from old.requested_by
    or new.request_id is distinct from old.request_id
    or new.created_at is distinct from old.created_at
  then
    raise exception using errcode = '55000', message = 'financial control request evidence is immutable';
  end if;
  if not (
    (old.status = 'requested' and new.status in ('under_review', 'rejected', 'cancelled'))
    or (old.status = 'under_review' and new.status in ('approved', 'rejected', 'cancelled'))
  ) then
    raise exception using errcode = '55000', message = 'invalid financial control request transition';
  end if;
  return new;
end;
$function$;
revoke all on function public.guard_financial_control_request() from public, anon, authenticated, service_role;
create trigger financial_control_request_guard
before update or delete on public.financial_control_requests
for each row execute function public.guard_financial_control_request();

create function public.reject_financial_control_history_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'financial control history is append-only';
end;
$function$;
revoke all on function public.reject_financial_control_history_mutation() from public, anon, authenticated, service_role;
create trigger financial_control_approvals_immutable
before update or delete on public.financial_control_approvals
for each row execute function public.reject_financial_control_history_mutation();
create trigger financial_control_events_immutable
before update or delete on public.financial_control_events
for each row execute function public.reject_financial_control_history_mutation();

create function public.guard_seller_payout_hold()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  control_request public.financial_control_requests%rowtype;
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '55000', message = 'payout holds cannot be deleted';
  end if;

  if tg_op = 'INSERT' then
    select * into control_request
    from public.financial_control_requests
    where id = new.source_request_id;
    if not found or control_request.request_type <> 'payout_hold'
      or control_request.status <> 'approved'
      or control_request.seller_id <> new.seller_id
      or control_request.amount_minor <> new.amount_minor
      or control_request.currency <> new.currency
      or control_request.evidence_sha256 <> new.evidence_sha256
      or control_request.reason <> new.reason
      or new.released_at is not null or new.release_request_id is not null
    then
      raise exception using errcode = '55000', message = 'payout hold requires a matching two-person-approved request';
    end if;
    return new;
  end if;

  if new.id is distinct from old.id
    or new.source_request_id is distinct from old.source_request_id
    or new.seller_id is distinct from old.seller_id
    or new.amount_minor is distinct from old.amount_minor
    or new.currency is distinct from old.currency
    or new.evidence_sha256 is distinct from old.evidence_sha256
    or new.reason is distinct from old.reason
    or new.created_at is distinct from old.created_at
    or old.released_at is not null
    or old.release_request_id is not null
    or new.released_at is null
    or new.release_request_id is null
  then
    raise exception using errcode = '55000', message = 'payout hold may only transition once from active to released';
  end if;

  select * into control_request
  from public.financial_control_requests
  where id = new.release_request_id;
  if not found or control_request.request_type <> 'payout_hold_release'
    or control_request.status <> 'approved'
    or control_request.target_hold_id <> old.id
    or control_request.seller_id <> old.seller_id
    or control_request.amount_minor <> old.amount_minor
    or control_request.currency <> old.currency
  then
    raise exception using errcode = '55000', message = 'payout hold release requires a matching two-person-approved request';
  end if;
  return new;
end;
$function$;
revoke all on function public.guard_seller_payout_hold() from public, anon, authenticated, service_role;
create trigger seller_payout_hold_guard
before insert or update or delete on public.seller_payout_holds
for each row execute function public.guard_seller_payout_hold();

create function public.create_financial_control_request(
  p_actor_id uuid,
  p_request_type text,
  p_seller_id uuid,
  p_order_id uuid,
  p_target_hold_id uuid,
  p_amount_minor bigint,
  p_currency text,
  p_evidence_sha256 text,
  p_reason text,
  p_idempotency_key text,
  p_request_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  existing_request public.financial_control_requests%rowtype;
  new_id uuid;
  target_hold public.seller_payout_holds%rowtype;
  seller_net numeric;
begin
  if p_actor_id is null or p_seller_id is null or p_request_id is null
    or p_request_type is null or p_request_type not in ('manual_adjustment', 'negative_balance_review', 'payout_hold', 'payout_hold_release')
    or p_amount_minor is null or p_amount_minor <= 0
    or p_currency is null or p_currency !~ '^[A-Z]{3}$'
    or p_evidence_sha256 is null or p_evidence_sha256 !~ '^[a-f0-9]{64}$'
    or p_reason is null or char_length(btrim(p_reason)) not between 12 and 1000
    or p_idempotency_key is null or char_length(p_idempotency_key) not between 16 and 200
    or (p_request_type = 'payout_hold_release' and p_target_hold_id is null)
    or (p_request_type <> 'payout_hold_release' and p_target_hold_id is not null)
  then
    raise exception using errcode = '22023', message = 'financial control request failed validation';
  end if;
  if not exists (select 1 from public.user_roles ur where ur.user_id = p_actor_id and ur.role = 'admin'::public.app_role) then
    raise exception using errcode = '42501', message = 'financial control request requires an admin';
  end if;
  if not exists (select 1 from auth.users u where u.id = p_seller_id) then
    raise exception using errcode = '42501', message = 'financial control seller does not exist';
  end if;

  if p_order_id is not null and not exists (
    select 1 from public.orders o
    join public.order_items oi on oi.order_id = o.id
    where o.id = p_order_id and oi.seller_id = p_seller_id and o.currency = p_currency
  ) then
    raise exception using errcode = '22023', message = 'financial control order must belong to the seller and currency';
  end if;

  if p_request_type = 'negative_balance_review' then
    select coalesce(sum(case when e.side = 'credit' then e.amount_minor else -e.amount_minor end), 0)
      into seller_net
    from public.financial_journal_entries e
    join public.financial_journal_batches b on b.id = e.batch_id
    where e.account = 'seller_payable'
      and e.seller_id = p_seller_id
      and e.currency = p_currency
      and b.status = 'posted';
    if seller_net >= 0 or abs(seller_net) <> p_amount_minor then
      raise exception using errcode = '22023', message = 'negative-balance review must match the current posted seller-payable deficit';
    end if;
  end if;

  if p_request_type = 'payout_hold_release' then
    select * into target_hold from public.seller_payout_holds where id = p_target_hold_id for update;
    if not found or target_hold.released_at is not null
      or target_hold.seller_id <> p_seller_id
      or target_hold.amount_minor <> p_amount_minor
      or target_hold.currency <> p_currency
    then
      raise exception using errcode = '22023', message = 'payout hold release must match an active hold exactly';
    end if;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_idempotency_key, 0));

  select * into existing_request
  from public.financial_control_requests
  where idempotency_key = p_idempotency_key
  for update;
  if found then
    if existing_request.requested_by is distinct from p_actor_id
      or existing_request.request_type is distinct from p_request_type
      or existing_request.seller_id is distinct from p_seller_id
      or existing_request.order_id is distinct from p_order_id
      or existing_request.target_hold_id is distinct from p_target_hold_id
      or existing_request.amount_minor is distinct from p_amount_minor
      or existing_request.currency is distinct from p_currency
      or existing_request.evidence_sha256 is distinct from p_evidence_sha256
      or existing_request.reason is distinct from btrim(p_reason)
    then
      raise exception using errcode = '23505', message = 'financial control idempotency key reused with conflicting content';
    end if;
    return existing_request.id;
  end if;

  insert into public.financial_control_requests (
    request_type, seller_id, order_id, target_hold_id, amount_minor, currency,
    evidence_sha256, reason, idempotency_key, requested_by, request_id
  ) values (
    p_request_type, p_seller_id, p_order_id, p_target_hold_id, p_amount_minor, p_currency,
    p_evidence_sha256, btrim(p_reason), p_idempotency_key, p_actor_id, p_request_id
  ) returning id into new_id;

  insert into public.financial_control_events
    (request_id, actor_id, event_type, from_status, to_status, note, request_trace_id)
  values (new_id, p_actor_id, 'created', null, 'requested', btrim(p_reason), p_request_id);

  insert into public.audit_events (actor_id, action, entity_type, entity_id, request_id, metadata)
  values (p_actor_id, 'financial_control.requested', 'financial_control_request', new_id::text, p_request_id,
    jsonb_build_object('request_type', p_request_type, 'seller_id', p_seller_id, 'amount_minor', p_amount_minor, 'currency', p_currency));

  return new_id;
end;
$function$;
revoke all on function public.create_financial_control_request(uuid, text, uuid, uuid, uuid, bigint, text, text, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.create_financial_control_request(uuid, text, uuid, uuid, uuid, bigint, text, text, text, text, uuid) to service_role;

create function public.review_financial_control_request(
  p_request_id uuid,
  p_actor_id uuid,
  p_decision text,
  p_note text,
  p_request_trace_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  control_request public.financial_control_requests%rowtype;
  approval_count integer;
  prior_status text;
  next_status text;
  hold_id uuid;
  seller_net numeric;
begin
  if p_request_id is null or p_actor_id is null or p_request_trace_id is null
    or p_decision is null or p_decision not in ('approve', 'reject')
    or p_note is null or char_length(btrim(p_note)) not between 10 and 1000
  then
    raise exception using errcode = '22023', message = 'financial control review failed validation';
  end if;
  if not exists (select 1 from public.user_roles ur where ur.user_id = p_actor_id and ur.role = 'admin'::public.app_role) then
    raise exception using errcode = '42501', message = 'financial control review requires an admin';
  end if;

  select * into control_request from public.financial_control_requests
  where id = p_request_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'financial control request not found';
  end if;
  if control_request.requested_by = p_actor_id then
    raise exception using errcode = '42501', message = 'requester cannot approve their own financial control request';
  end if;
  if control_request.status not in ('requested', 'under_review') then
    raise exception using errcode = '22023', message = 'financial control request is not reviewable';
  end if;

  if p_decision = 'approve' and control_request.request_type = 'negative_balance_review' then
    select coalesce(sum(case when e.side = 'credit' then e.amount_minor else -e.amount_minor end), 0)
      into seller_net
    from public.financial_journal_entries e
    join public.financial_journal_batches b on b.id = e.batch_id
    where e.account = 'seller_payable'
      and e.seller_id = control_request.seller_id
      and e.currency = control_request.currency
      and b.status = 'posted';
    if seller_net >= 0 or abs(seller_net) <> control_request.amount_minor then
      raise exception using errcode = '22023', message = 'negative seller-payable deficit changed since request creation';
    end if;
  end if;

  insert into public.financial_control_approvals
    (request_id, approver_id, decision, note, request_trace_id)
  values (p_request_id, p_actor_id, p_decision, btrim(p_note), p_request_trace_id);

  prior_status := control_request.status;
  if p_decision = 'reject' then
    next_status := 'rejected';
  else
    select count(*)::integer into approval_count
    from public.financial_control_approvals
    where request_id = p_request_id and decision = 'approve';
    next_status := case when approval_count >= 2 then 'approved' else 'under_review' end;
  end if;

  update public.financial_control_requests
  set status = next_status,
      approved_at = case when next_status = 'approved' then now() else null end,
      updated_at = now()
  where id = p_request_id;

  insert into public.financial_control_events
    (request_id, actor_id, event_type, from_status, to_status, note, request_trace_id)
  values (
    p_request_id, p_actor_id,
    case
      when next_status = 'rejected' then 'rejected'
      when next_status = 'approved' then 'approved'
      else 'approved_by_one'
    end,
    prior_status, next_status, btrim(p_note), p_request_trace_id
  );

  insert into public.audit_events (actor_id, action, entity_type, entity_id, request_id, metadata)
  values (p_actor_id, 'financial_control.' || p_decision, 'financial_control_request', p_request_id::text, p_request_trace_id,
    jsonb_build_object('request_type', control_request.request_type, 'status', next_status, 'approval_count', case when p_decision = 'approve' then approval_count else 0 end));

  if next_status = 'approved' and control_request.request_type = 'payout_hold' then
    insert into public.seller_payout_holds
      (source_request_id, seller_id, amount_minor, currency, evidence_sha256, reason)
    values
      (control_request.id, control_request.seller_id, control_request.amount_minor,
       control_request.currency, control_request.evidence_sha256, control_request.reason)
    returning id into hold_id;

    insert into public.financial_control_events
      (request_id, actor_id, event_type, from_status, to_status, note, request_trace_id)
    values
      (p_request_id, p_actor_id, 'payout_hold_placed', 'approved', 'approved',
       'Two-person approval placed the internal payout hold.', p_request_trace_id);
  elsif next_status = 'approved' and control_request.request_type = 'payout_hold_release' then
    update public.seller_payout_holds
    set released_at = now(), release_request_id = control_request.id
    where id = control_request.target_hold_id and released_at is null;

    if not found then
      raise exception using errcode = '55000', message = 'payout hold is no longer active';
    end if;

    insert into public.financial_control_events
      (request_id, actor_id, event_type, from_status, to_status, note, request_trace_id)
    values
      (p_request_id, p_actor_id, 'payout_hold_released', 'approved', 'approved',
       'Two-person approval released the internal payout hold.', p_request_trace_id);
  end if;

  return next_status;
end;
$function$;
revoke all on function public.review_financial_control_request(uuid, uuid, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.review_financial_control_request(uuid, uuid, text, text, uuid) to service_role;


create function public.cancel_financial_control_request(
  p_request_id uuid,
  p_actor_id uuid,
  p_note text,
  p_request_trace_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
declare
  control_request public.financial_control_requests%rowtype;
begin
  if p_request_id is null or p_actor_id is null or p_request_trace_id is null
    or p_note is null or char_length(btrim(p_note)) not between 10 and 1000
  then
    raise exception using errcode = '22023', message = 'financial control cancellation failed validation';
  end if;

  select * into control_request from public.financial_control_requests
  where id = p_request_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'financial control request not found';
  end if;
  if control_request.requested_by <> p_actor_id
    or control_request.status <> 'requested'
    or exists (select 1 from public.financial_control_approvals a where a.request_id = p_request_id)
  then
    raise exception using errcode = '42501', message = 'only the maker can cancel a request before review begins';
  end if;

  update public.financial_control_requests
  set status = 'cancelled', updated_at = now()
  where id = p_request_id;

  insert into public.financial_control_events
    (request_id, actor_id, event_type, from_status, to_status, note, request_trace_id)
  values (p_request_id, p_actor_id, 'cancelled', control_request.status, 'cancelled', btrim(p_note), p_request_trace_id);

  insert into public.audit_events (actor_id, action, entity_type, entity_id, request_id, metadata)
  values (p_actor_id, 'financial_control.cancelled', 'financial_control_request', p_request_id::text, p_request_trace_id,
    jsonb_build_object('request_type', control_request.request_type, 'status', 'cancelled'));

  return 'cancelled';
end;
$function$;
revoke all on function public.cancel_financial_control_request(uuid, uuid, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.cancel_financial_control_request(uuid, uuid, text, uuid) to service_role;

comment on table public.financial_control_requests is
  'Internal maker-checker workflow for manual adjustments, negative-balance reviews, and payout holds. Approval alone never posts journal entries or moves provider funds.';
comment on table public.seller_payout_holds is
  'Internal hold ledger. Holds are created only after two distinct admin approvals and released only after two distinct admin approvals; payout execution is not implemented here.';
