-- Phase 5I: private provider-dispute state machine driven only by verified webhook evidence.
-- This is a database boundary, not a live provider adapter or evidence-submission client.
create table public.payment_disputes (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('paystack', 'flutterwave', 'stripe', 'sandbox')),
  provider_dispute_id text not null check (char_length(provider_dispute_id) between 1 and 240),
  order_id uuid not null references public.orders(id) on delete restrict,
  payment_attempt_id uuid not null references public.payment_attempts(id) on delete restrict,
  amount_minor bigint not null check (amount_minor > 0),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  status text not null check (status in (
    'open', 'needs_evidence', 'evidence_submitted', 'won', 'lost', 'closed'
  )),
  evidence_due_at timestamptz,
  provider_status text check (provider_status is null or char_length(provider_status) between 1 and 160),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_dispute_id),
  constraint payment_dispute_closed_state check (
    (status = 'closed' and closed_at is not null)
    or (status <> 'closed' and closed_at is null)
  )
);

create index payment_disputes_order_idx
  on public.payment_disputes (order_id, created_at desc);
create index payment_disputes_open_idx
  on public.payment_disputes (status, evidence_due_at)
  where status in ('open', 'needs_evidence', 'evidence_submitted');

create table public.payment_dispute_events (
  id bigint generated always as identity primary key,
  dispute_id uuid not null references public.payment_disputes(id) on delete restrict,
  provider_webhook_event_id uuid not null unique references public.payment_webhook_events(id) on delete restrict,
  event_action text not null check (event_action in (
    'opened', 'needs_evidence', 'evidence_submitted', 'won', 'lost', 'closed'
  )),
  provider_event_type text not null check (char_length(provider_event_type) between 1 and 160),
  from_status text check (from_status is null or from_status in (
    'open', 'needs_evidence', 'evidence_submitted', 'won', 'lost', 'closed'
  )),
  to_status text not null check (to_status in (
    'open', 'needs_evidence', 'evidence_submitted', 'won', 'lost', 'closed'
  )),
  payload_sha256 text not null check (payload_sha256 ~ '^[a-f0-9]{64}$'),
  request_id uuid not null,
  created_at timestamptz not null default now()
);

create index payment_dispute_events_dispute_idx
  on public.payment_dispute_events (dispute_id, created_at, id);

alter table public.payment_disputes enable row level security;
alter table public.payment_dispute_events enable row level security;
revoke all on public.payment_disputes from public, anon, authenticated, service_role;
revoke all on public.payment_dispute_events from public, anon, authenticated, service_role;
grant select on public.payment_disputes to service_role;
grant select on public.payment_dispute_events to service_role;

create function public.reject_payment_dispute_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception using errcode = '55000', message = 'payment dispute event history is append-only';
end;
$function$;
revoke all on function public.reject_payment_dispute_event_mutation() from public, anon, authenticated, service_role;
create trigger payment_dispute_events_immutable
before update or delete on public.payment_dispute_events
for each row execute function public.reject_payment_dispute_event_mutation();

create function public.guard_payment_dispute_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '55000', message = 'payment disputes cannot be deleted';
  end if;
  if new.id is distinct from old.id
    or new.provider is distinct from old.provider
    or new.provider_dispute_id is distinct from old.provider_dispute_id
    or new.order_id is distinct from old.order_id
    or new.payment_attempt_id is distinct from old.payment_attempt_id
    or new.amount_minor is distinct from old.amount_minor
    or new.currency is distinct from old.currency
    or new.opened_at is distinct from old.opened_at
    or new.created_at is distinct from old.created_at
    or old.status in ('won', 'lost', 'closed')
  then
    raise exception using errcode = '55000', message = 'payment dispute identity is immutable or already terminal';
  end if;
  return new;
end;
$function$;
revoke all on function public.guard_payment_dispute_mutation() from public, anon, authenticated, service_role;
create trigger payment_disputes_guard
before update or delete on public.payment_disputes
for each row execute function public.guard_payment_dispute_mutation();

create function public.apply_verified_payment_dispute_event(
  p_provider text,
  p_provider_event_id text,
  p_provider_dispute_id text,
  p_event_type text,
  p_event_action text,
  p_order_id uuid,
  p_payment_attempt_id uuid,
  p_amount_minor bigint,
  p_currency text,
  p_evidence_due_at timestamptz,
  p_provider_status text,
  p_request_id uuid
)
returns table (dispute_id uuid, status text, duplicate boolean)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  webhook_event public.payment_webhook_events%rowtype;
  payment public.payment_attempts%rowtype;
  dispute public.payment_disputes%rowtype;
  prior_event public.payment_dispute_events%rowtype;
  next_status text;
  previous_status text;
  existing_dispute_id uuid;
begin
  if p_provider is null or p_provider not in ('paystack', 'flutterwave', 'stripe', 'sandbox')
    or p_provider_event_id is null or char_length(p_provider_event_id) not between 1 and 240
    or p_provider_dispute_id is null or char_length(p_provider_dispute_id) not between 1 and 240
    or p_event_type is null or char_length(p_event_type) not between 1 and 160
    or p_event_type !~* '(dispute|chargeback)'
    or p_event_action is null or p_event_action not in (
      'opened', 'needs_evidence', 'evidence_submitted', 'won', 'lost', 'closed'
    )
    or p_order_id is null or p_payment_attempt_id is null
    or p_amount_minor is null or p_amount_minor <= 0
    or p_currency is null or p_currency !~ '^[A-Z]{3}$'
    or p_request_id is null
    or (p_provider_status is not null and char_length(p_provider_status) not between 1 and 160)
  then
    raise exception using errcode = '22023', message = 'payment dispute event metadata failed validation';
  end if;

  select * into webhook_event
  from public.payment_webhook_events e
  where e.provider = p_provider and e.provider_event_id = p_provider_event_id
  for update;
  if not found
    or webhook_event.signature_verified is not true
    or webhook_event.event_type <> p_event_type
    or webhook_event.order_id is distinct from p_order_id
    or webhook_event.payment_attempt_id is distinct from p_payment_attempt_id
    or webhook_event.processing_status in ('ignored', 'failed')
  then
    raise exception using errcode = '42501', message = 'payment dispute requires a matching verified webhook event';
  end if;

  select * into prior_event
  from public.payment_dispute_events
  where provider_webhook_event_id = webhook_event.id;
  if found then
    select * into dispute from public.payment_disputes where id = prior_event.dispute_id;
    if dispute.provider_dispute_id <> p_provider_dispute_id
      or prior_event.event_action <> p_event_action
      or prior_event.provider_event_type <> p_event_type
    then
      raise exception using errcode = '23505', message = 'verified provider event was reused with conflicting dispute data';
    end if;
    return query select dispute.id, dispute.status, true;
    return;
  end if;

  select * into payment
  from public.payment_attempts p
  where p.id = p_payment_attempt_id
  for update;
  if not found
    or payment.provider <> p_provider
    or payment.order_id <> p_order_id
    or payment.currency <> p_currency
    or p_amount_minor > payment.amount_minor
    or payment.status not in ('succeeded', 'partially_refunded', 'refunded')
  then
    raise exception using errcode = '22023', message = 'dispute amount, currency, provider or payment reference does not match';
  end if;

  select d.id into existing_dispute_id
  from public.payment_disputes d
  where d.provider = p_provider and d.provider_dispute_id = p_provider_dispute_id
  for update;

  if existing_dispute_id is null then
    if p_event_action <> 'opened' then
      raise exception using errcode = '22023', message = 'first dispute event must open the dispute';
    end if;
    insert into public.payment_disputes (
      provider, provider_dispute_id, order_id, payment_attempt_id,
      amount_minor, currency, status, evidence_due_at, provider_status
    ) values (
      p_provider, p_provider_dispute_id, p_order_id, p_payment_attempt_id,
      p_amount_minor, p_currency, 'open', p_evidence_due_at, p_provider_status
    ) returning * into dispute;
    previous_status := null;
    next_status := 'open';
  else
    select * into dispute from public.payment_disputes where id = existing_dispute_id;
    if dispute.order_id <> p_order_id
      or dispute.payment_attempt_id <> p_payment_attempt_id
      or dispute.amount_minor <> p_amount_minor
      or dispute.currency <> p_currency
    then
      raise exception using errcode = '23505', message = 'provider dispute identity was reused with conflicting financial details';
    end if;

    previous_status := dispute.status;
    next_status := case p_event_action
      when 'opened' then 'open'
      when 'needs_evidence' then 'needs_evidence'
      when 'evidence_submitted' then 'evidence_submitted'
      when 'won' then 'won'
      when 'lost' then 'lost'
      when 'closed' then 'closed'
    end;

    if previous_status in ('won', 'lost', 'closed')
      or (p_event_action = 'opened' and previous_status <> 'open')
      or (p_event_action = 'needs_evidence' and previous_status not in ('open', 'needs_evidence', 'evidence_submitted'))
      or (p_event_action = 'evidence_submitted' and previous_status not in ('open', 'needs_evidence', 'evidence_submitted'))
      or (p_event_action in ('won', 'lost') and previous_status not in ('open', 'needs_evidence', 'evidence_submitted'))
      or (p_event_action = 'closed' and previous_status not in ('won', 'lost'))
    then
      raise exception using errcode = '55000', message = 'invalid payment dispute state transition';
    end if;

    update public.payment_disputes
    set status = next_status,
        evidence_due_at = coalesce(p_evidence_due_at, evidence_due_at),
        provider_status = coalesce(p_provider_status, provider_status),
        closed_at = case when next_status = 'closed' then now() else null end,
        updated_at = now()
    where id = dispute.id
    returning * into dispute;
  end if;

  insert into public.payment_dispute_events (
    dispute_id, provider_webhook_event_id, event_action, provider_event_type,
    from_status, to_status, payload_sha256, request_id
  ) values (
    dispute.id, webhook_event.id, p_event_action, p_event_type,
    previous_status, next_status, webhook_event.payload_sha256, p_request_id
  );

  insert into public.audit_events (actor_id, action, entity_type, entity_id, request_id, metadata)
  values (
    null, 'payment.dispute.event_applied', 'payment_dispute', dispute.id::text, p_request_id,
    jsonb_build_object(
      'provider', p_provider,
      'provider_event_id', p_provider_event_id,
      'provider_dispute_id', p_provider_dispute_id,
      'event_action', p_event_action,
      'from_status', previous_status,
      'to_status', next_status,
      'payload_sha256', webhook_event.payload_sha256
    )
  );

  return query select dispute.id, dispute.status, false;
end;
$function$;
revoke all on function public.apply_verified_payment_dispute_event(text, text, text, text, text, uuid, uuid, bigint, text, timestamptz, text, uuid) from public, anon, authenticated;
grant execute on function public.apply_verified_payment_dispute_event(text, text, text, text, text, uuid, uuid, bigint, text, timestamptz, text, uuid) to service_role;

comment on table public.payment_disputes is
  'Private provider dispute state machine. Dispute transitions require a matching signature-verified payment webhook event; no provider API calls or evidence uploads are performed by this table.';
comment on table public.payment_dispute_events is
  'Append-only normalized history of verified provider dispute events, linked to the webhook payload digest and request trace.';
